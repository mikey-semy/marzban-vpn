#!/bin/bash
set -e

# Цвета для логов
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[MARZBAN-VPN]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[MARZBAN-VPN]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[MARZBAN-VPN]${NC} $1"
}

log_error() {
    echo -e "${RED}[MARZBAN-VPN]${NC} $1"
}

# Инициализация конфигурации Xray
init_xray_config() {
    log "Инициализация конфигурации Xray..."

    # Путь к конфигурации Xray
    XRAY_CONFIG_FILE="${XRAY_JSON:-/var/lib/marzban/xray_config.json}"
    XRAY_CONFIG_DIR=$(dirname "$XRAY_CONFIG_FILE")

    # Создание директории если не существует
    mkdir -p "$XRAY_CONFIG_DIR"

    # Копирование шаблона конфигурации если файл не существует
    if [ ! -f "$XRAY_CONFIG_FILE" ]; then
        log "Копирование шаблона конфигурации Xray..."
        cp /app/configs/config.json.template "$XRAY_CONFIG_FILE"
        log_success "Конфигурация Xray инициализирована: $XRAY_CONFIG_FILE"
    else
        log_success "Конфигурация Xray уже существует: $XRAY_CONFIG_FILE"
    fi

    # Проверка валидности JSON
    if ! jq empty "$XRAY_CONFIG_FILE" 2>/dev/null; then
        log_error "Конфигурация Xray содержит невалидный JSON!"
        log "Восстановление из шаблона..."
        cp /app/configs/config.json.template "$XRAY_CONFIG_FILE"
        log_success "Конфигурация восстановлена из шаблона"
    fi
}

# Генерация SSL сертификатов
generate_ssl_certs() {
    # Пропускаем генерацию SSL если отключен внутренний SSL
    if [ "${DISABLE_INTERNAL_SSL:-false}" = "true" ]; then
        log "Пропуск генерации SSL сертификатов (SSL обрабатывается Traefik)"
        return 0
    fi

    log "Проверка SSL сертификатов..."

    CERT_FILE="${UVICORN_SSL_CERTFILE:-/var/lib/marzban/cert.crt}"
    KEY_FILE="${UVICORN_SSL_KEYFILE:-/var/lib/marzban/cert.key}"
    CERT_DAYS="${SSL_CERT_DAYS:-365}"

    # Проверка существования сертификатов и их валидности
    local need_regenerate=false

    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        need_regenerate=true
        log "Сертификаты не найдены, требуется генерация"
    elif ! openssl x509 -checkend 86400 -noout -in "$CERT_FILE" 2>/dev/null; then
        need_regenerate=true
        log_warning "Сертификат истекает в течение 24 часов, требуется обновление"
    fi

    if [ "$need_regenerate" = true ]; then
        log "Генерация самоподписанного SSL сертификата (срок: $CERT_DAYS дней)..."

        # Создаем директорию если не существует
        mkdir -p "$(dirname "$CERT_FILE")"

        if openssl req -x509 -newkey rsa:2048 \
            -keyout "$KEY_FILE" \
            -out "$CERT_FILE" \
            -days "$CERT_DAYS" \
            -nodes \
            -subj "/CN=${DOMAIN:-localhost}" 2>/dev/null; then

            # Устанавливаем права для пользователя marzban
            chown marzban:marzban "$CERT_FILE" "$KEY_FILE" 2>/dev/null || true
            chmod 644 "$CERT_FILE"
            chmod 600 "$KEY_FILE"

            log_success "SSL сертификаты созданы"
        else
            log_error "Ошибка при генерации SSL сертификатов"
            return 1
        fi
    else
        # Проверяем и исправляем права если сертификаты уже существуют
        chown marzban:marzban "$CERT_FILE" "$KEY_FILE" 2>/dev/null || true
        chmod 644 "$CERT_FILE" 2>/dev/null || true
        chmod 600 "$KEY_FILE" 2>/dev/null || true

        # Показываем информацию о сертификате
        local expiry_date=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
        log_success "SSL сертификаты актуальны (истекает: $expiry_date)"
    fi

    # Экспортируем пути для использования в приложении
    export UVICORN_SSL_CERTFILE="$CERT_FILE"
    export UVICORN_SSL_KEYFILE="$KEY_FILE"
}

# Создание директорий для логов
create_log_dirs() {
    log "Создание директорий для логов..."
    mkdir -p /var/log/xray
    mkdir -p /var/lib/marzban/logs
    log_success "Директории для логов созданы"
}

# Проверка подключения к базе данных
check_database() {
    log "Проверка подключения к базе данных..."

    # Ожидание доступности базы данных
    if [ -n "$SQLALCHEMY_DATABASE_URL" ]; then
        # Парсинг URL базы данных для получения хоста и порта
        # Поддерживает форматы: mysql+pymysql://user:pass@host:port/db
        DB_HOST=$(echo "$SQLALCHEMY_DATABASE_URL" | sed -E 's/.*@([^:\/]+)(:[0-9]+)?.*/\1/')
        DB_PORT=$(echo "$SQLALCHEMY_DATABASE_URL" | sed -E 's/.*:([0-9]+)\/.*/\1/')

        # Валидация распарсенных значений
        if [ -z "$DB_PORT" ] || ! [[ "$DB_PORT" =~ ^[0-9]+$ ]]; then
            DB_PORT="3306"
            log_warning "Порт БД не определен, используется по умолчанию: $DB_PORT"
        fi

        if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "$SQLALCHEMY_DATABASE_URL" ]; then
            log "Ожидание доступности базы данных $DB_HOST:$DB_PORT..."

            # Конфигурируемое количество попыток
            local max_retries="${DB_WAIT_RETRIES:-30}"
            local retry_delay=2

            for i in $(seq 1 $max_retries); do
                if timeout 1 bash -c "echo >/dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                    log_success "База данных доступна после $i попыток"
                    return 0
                fi

                if [ $i -eq $max_retries ]; then
                    log_warning "Не удалось подключиться к базе данных после $max_retries попыток"
                    log_warning "Продолжаем запуск, приложение попробует подключиться позже..."
                    return 1
                else
                    log "Попытка $i/$max_retries - ожидание ${retry_delay}с..."
                    sleep $retry_delay
                fi
            done
        else
            log_warning "Не удалось определить хост БД из URL"
        fi
    else
        log_warning "SQLALCHEMY_DATABASE_URL не задан"
    fi
}

# Настройка переменных окружения по умолчанию
setup_defaults() {
    log "Настройка переменных окружения по умолчанию..."

    # Установка значений по умолчанию
    export UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
    export UVICORN_PORT="${UVICORN_PORT:-8003}"
    export XRAY_JSON="${XRAY_JSON:-/var/lib/marzban/xray_config.json}"
    export XRAY_EXECUTABLE_PATH="${XRAY_EXECUTABLE_PATH:-/usr/local/bin/xray}"
    export XRAY_ASSETS_PATH="${XRAY_ASSETS_PATH:-/usr/local/share/xray}"

    # Настройка SSL в зависимости от режима
    if [ "${DISABLE_INTERNAL_SSL:-false}" = "true" ]; then
        log "SSL отключен внутри контейнера (обрабатывается Traefik/Cloudflare)"
        # Полностью удаляем SSL переменные из окружения
        unset UVICORN_SSL_CERTFILE
        unset UVICORN_SSL_KEYFILE  
        unset UVICORN_SSL_CA_TYPE
        # Принудительно слушаем все интерфейсы для работы с reverse proxy
        export UVICORN_HOST="0.0.0.0"
        
        # Дополнительно убеждаемся что переменные пустые
        export UVICORN_SSL_CERTFILE=""
        export UVICORN_SSL_KEYFILE=""
        export UVICORN_SSL_CA_TYPE=""
    elif [ "${USE_LETSENCRYPT_CERTS:-false}" = "true" ]; then
        log "Используются Let's Encrypt сертификаты"
        export UVICORN_SSL_CERTFILE="${LETSENCRYPT_CERT_PATH:-/etc/letsencrypt/live/${DOMAIN}/fullchain.pem}"
        export UVICORN_SSL_KEYFILE="${LETSENCRYPT_KEY_PATH:-/etc/letsencrypt/live/${DOMAIN}/privkey.pem}"
        export UVICORN_SSL_CA_TYPE="public"
    fi

    log_success "Переменные окружения настроены"
}

# Обновление конфигурации WARP в Xray
update_warp_config() {
    local xray_config="$1"

    if [ -n "$WARP_ENABLED" ] && [ "$WARP_ENABLED" = "true" ]; then
        log "Обновление конфигурации WARP..."

        # Обновление адреса WARP прокси
        WARP_HOST="${WARP_HOST:-warp-proxy}"
        WARP_PORT="${WARP_PORT:-1080}"

        # Используем jq для обновления конфигурации
        jq --arg host "$WARP_HOST" --arg port "$WARP_PORT" \
           '.outbounds |= map(if .tag == "warp" then .settings.servers[0].address = $host | .settings.servers[0].port = ($port | tonumber) else . end)' \
           "$xray_config" > "${xray_config}.tmp" && mv "${xray_config}.tmp" "$xray_config"

        log_success "Конфигурация WARP обновлена: $WARP_HOST:$WARP_PORT"
    fi
}

# Обновление Reality ключей в Xray конфигурации
update_reality_config() {
    local xray_config="$1"

    # Проверяем наличие Reality переменных
    if [ -n "$REALITY_PRIVATE_KEY" ] && [ -n "$REALITY_PUBLIC_KEY" ]; then
        log "Обновление Reality ключей..."

        REALITY_DEST="${REALITY_DEST:-ya.ru:443}"
        REALITY_SERVER_NAMES="${REALITY_SERVER_NAMES:-ya.ru,www.ya.ru}"

        # Конвертируем строку server names в JSON массив
        SERVER_NAMES_JSON=$(echo "$REALITY_SERVER_NAMES" | tr ',' '\n' | jq -R . | jq -s .)

        # Обновляем конфигурацию
        jq --arg privKey "$REALITY_PRIVATE_KEY" \
           --arg pubKey "$REALITY_PUBLIC_KEY" \
           --arg dest "$REALITY_DEST" \
           --argjson serverNames "$SERVER_NAMES_JSON" \
           '.inbounds |= map(if .tag == "VLESS Reality" then
               .streamSettings.realitySettings.privateKey = $privKey |
               .streamSettings.realitySettings.publicKey = $pubKey |
               .streamSettings.realitySettings.dest = $dest |
               .streamSettings.realitySettings.serverNames = $serverNames
           else . end)' \
           "$xray_config" > "${xray_config}.tmp" && mv "${xray_config}.tmp" "$xray_config"

        log_success "Reality ключи обновлены"
    else
        log_warning "Reality ключи не заданы, используются значения из шаблона"
        log_warning "Рекомендуется сгенерировать уникальные ключи командой: xray x25519"
    fi
}

# Выполнение миграций базы данных
run_database_migrations() {
    log "Выполнение миграций базы данных..."
    
    # Проверяем доступность alembic
    if command -v alembic >/dev/null 2>&1; then
        # Выполняем миграции
        alembic upgrade head
        if [ $? -eq 0 ]; then
            log_success "Миграции базы данных выполнены успешно"
        else
            log_warning "Ошибка при выполнении миграций, продолжаем..."
        fi
    else
        log_warning "Alembic не найден, пропускаем миграции"
    fi
}

# Переключение на пользователя marzban для запуска приложения
switch_to_marzban() {
log "Настройка прав доступа..."

# Устанавливаем права на директории
chown -R marzban:marzban /var/lib/marzban 2>/dev/null || true
chown -R marzban:marzban /app/configs 2>/dev/null || true
chown -R marzban:marzban /var/log/xray 2>/dev/null || true

log_success "Права установлены для пользователя marzban"
}

# Основная функция инициализации
main() {
log "=== Запуск Marzban VPN с персистентной конфигурацией ==="

    # Выполнение всех этапов инициализации
    setup_defaults
    create_log_dirs
    generate_ssl_certs
    init_xray_config
    update_warp_config "$XRAY_JSON"
    update_reality_config "$XRAY_JSON"
    check_database
    run_database_migrations
    switch_to_marzban
    
    log_success "=== Инициализация завершена, запуск приложения ==="
    
    # Выполнение команды от имени пользователя marzban
    if id -u marzban >/dev/null 2>&1; then
        exec gosu marzban "$@"
    else
        log_warning "Пользователь marzban не найден, запуск от root"
        exec "$@"
    fi
}

# Запуск основной функции
main "$@"
