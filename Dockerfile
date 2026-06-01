# Версия Marzban (можно переопределить при сборке: docker build --build-arg MARZBAN_VERSION=v0.8.4)
ARG MARZBAN_VERSION=v0.8.4
FROM gozargah/marzban:${MARZBAN_VERSION}

# Установка необходимых пакетов
USER root
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    gosu \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Пин Xray-core поверх базового образа.
# Базовый gozargah/marzban ставит Xray "latest на момент сборки" и не пинует версию —
# из-за этого нет гарантии поддержки транспорта xhttp (рейнейм splithttp->xhttp был в Xray ~v24.11.30).
# Пинуем явную свежую версию: гарантируем xhttp + актуальные правки Reality/XHTTP против DPI.
# Версию проверяй на https://github.com/XTLS/Xray-core/releases и бампай при необходимости.
ARG XRAY_VERSION=v26.3.27
RUN curl -L https://github.com/Gozargah/Marzban-scripts/raw/master/install_latest_xray.sh | bash -s -- ${XRAY_VERSION} \
    && /usr/local/bin/xray version

# Создание пользователя marzban если не существует
RUN id -u marzban >/dev/null 2>&1 || useradd -r -s /bin/false marzban

# Создание директорий для персистентного хранения
RUN mkdir -p /app/configs \
    && mkdir -p /var/lib/marzban/xray \
    && mkdir -p /var/log/xray \
    && chown -R marzban:marzban /app/configs \
    && chown -R marzban:marzban /var/lib/marzban \
    && chown -R marzban:marzban /var/log/xray

# Копирование скрипта инициализации
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Копирование конфигурации Xray по умолчанию
COPY config.json /app/configs/config.json.template
RUN chown marzban:marzban /app/configs/config.json.template

EXPOSE 8003
# Настройка томов для персистентного хранения.
# /app/configs НАМЕРЕННО не том: шаблон config.json.template должен обновляться из
# образа при каждой сборке. Если сделать его томом — named-volume заполнится из образа
# лишь однажды (пока пуст), и старый шаблон будет затирать новые инбаунды (XHTTP) на redeploy.
VOLUME ["/var/lib/marzban", "/var/log/xray"]

# Использование кастомного entrypoint (остаемся под root для инициализации)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Команда по умолчанию
CMD ["python", "main.py"]
