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
    log "Проверка SSL сертификатов..."

    CERT_FILE="${UVICORN_SSL_CERTFILE:-/tmp/cert.crt}"
    KEY_FILE="${UVICORN_SSL_KEYFILE:-/tmp/cert.key}"

    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        log "Генерация самоподписанного SSL сертификата..."
        openssl req -x509 -newkey rsa:2048 \
            -keyout "$KEY_FILE" \
            -out "$CERT_FILE" \
            -days 365 \
            -nodes \
            -subj "/CN=${DOMAIN:-localhost}"
        log_success "SSL сертификаты созданы"
    else
        log_success "SSL сертификаты уже существуют"
    fi
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
        DB_HOST=$(echo "$SQLALCHEMY_DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
        DB_PORT=$(echo "$SQLALCHEMY_DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

        if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
            log "Ожидание доступности базы данных $DB_HOST:$DB_PORT..."

            # Простая проверка доступности порта
            for i in {1..30}; do
                if timeout 1 bash -c "echo >/dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                    log_success "База данных доступна"
                    break
                fi

                if [ $i -eq 30 ]; then
                    log_warning "Не удалось подключиться к базе данных, продолжаем..."
                else
                    sleep 2
                fi
            done
        fi
    fi
}

# Настройка переменных окружения по умолчанию
setup_defaults() {
    log "Настройка переменных окружения по умолчанию..."

    # Установка значений по умолчанию
    export UVICORN_HOST="${UVICORN_HOST:-0.0.0.0}"
    export UVICORN_PORT="${UVICORN_PORT:-8000}"
    export XRAY_JSON="${XRAY_JSON:-/var/lib/marzban/xray_config.json}"
    export XRAY_EXECUTABLE_PATH="${XRAY_EXECUTABLE_PATH:-/usr/local/bin/xray}"
    export XRAY_ASSETS_PATH="${XRAY_ASSETS_PATH:-/usr/local/share/xray}"

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

# Основная функция инициализации
main() {
    log "=== Запуск Marzban VPN с персистентной конфигурацией ==="

    # Выполнение всех этапов инициализации
    setup_defaults
    create_log_dirs
    generate_ssl_certs
    init_xray_config
    update_warp_config "$XRAY_JSON"
    check_database

    log_success "=== Инициализация завершена, запуск приложения ==="

    # Выполнение команды, переданной в контейнер
    exec "$@"
}

# Запуск основной функции
main "$@"
