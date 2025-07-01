FROM gozargah/marzban:latest

# Установка необходимых пакетов
USER root
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    su-exec \
    && rm -rf /var/lib/apt/lists/*

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

# Настройка томов для персистентного хранения
VOLUME ["/var/lib/marzban", "/app/configs", "/var/log/xray"]

# Использование кастомного entrypoint (остаемся под root для инициализации)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Команда по умолчанию
CMD ["python", "main.py"]
