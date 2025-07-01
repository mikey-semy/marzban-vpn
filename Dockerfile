FROM gozargah/marzban:latest

# Установка необходимых пакетов
USER root
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Создание директорий для персистентного хранения
RUN mkdir -p /app/configs \
    && mkdir -p /var/lib/marzban/xray \
    && mkdir -p /var/log/xray

# Копирование скрипта инициализации
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Копирование конфигурации Xray по умолчанию
COPY config.json /app/configs/config.json.template

# Настройка томов для персистентного хранения
VOLUME ["/var/lib/marzban", "/app/configs", "/var/log/xray"]

# Переключение на пользователя marzban
USER marzban

# Использование кастомного entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Команда по умолчанию
CMD ["python", "main.py"]
