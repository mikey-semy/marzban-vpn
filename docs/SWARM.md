# Docker Swarm развертывание

## Преимущества Swarm

- Автоматическое восстановление при сбоях
- Управление секретами
- Rolling updates без простоя
- Ограничение ресурсов
- Масштабирование

## Подготовка

### 1. Инициализация Swarm

```bash
# На первом узле (manager)
docker swarm init --advertise-addr <IP_MANAGER>

# На дополнительных узлах (workers)
docker swarm join --token <TOKEN> <IP_MANAGER>:2377
```

### 2. Создание overlay сети

```bash
docker network create --driver overlay --attachable marzban-network
```

### 3. Создание секретов

```bash
# MySQL пароли
echo "secure_db_password" | docker secret create mysql_password -
echo "secure_root_password" | docker secret create mysql_root_password -

# Marzban админ
echo "secure_admin_password" | docker secret create marzban_admin_password -

# Telegram (опционально)
echo "1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ" | docker secret create telegram_token -
```

### 4. Создание конфигурации Xray

```bash
docker config create xray_config config.json
```

### 5. Сборка образа

```bash
docker build -t marzban-vpn:latest .
```

## Развертывание

### Базовое развертывание

```bash
# Экспорт переменных
export DOMAIN=vpn.yourdomain.com
export MYSQL_PASSWORD=secure_db_password
export SUDO_USERNAME=admin

# Развертывание стека
docker stack deploy -c docker-compose.swarm.yml marzban
```

### С кастомными Reality ключами

```bash
# Генерация ключей
docker run --rm gozargah/marzban:latest xray x25519

# Экспорт
export REALITY_PRIVATE_KEY=your_private_key
export REALITY_PUBLIC_KEY=your_public_key

# Развертывание
docker stack deploy -c docker-compose.swarm.yml marzban
```

## Управление

### Просмотр статуса

```bash
# Список сервисов
docker stack services marzban

# Статус задач
docker stack ps marzban

# Логи сервиса
docker service logs marzban_marzban -f
docker service logs marzban_mysql -f
docker service logs marzban_warp -f
```

### Масштабирование

```bash
# WARP нельзя масштабировать из-за CAP_NET_ADMIN
# Marzban можно, но требует внешнюю БД
docker service scale marzban_marzban=2
```

### Обновление

```bash
# Пересборка образа
docker build -t marzban-vpn:latest .

# Обновление сервиса
docker service update --force marzban_marzban
```

### Откат

```bash
docker service rollback marzban_marzban
```

## Мониторинг

### Встроенные метрики

```bash
# Использование ресурсов
docker stats

# Информация о ноде
docker node ls
docker node inspect <NODE_ID>
```

### Health checks

Все сервисы имеют healthcheck:
- **MySQL**: `mysqladmin ping`
- **Marzban**: `curl http://localhost:8003/api/health`
- **WARP**: проверка SOCKS5 прокси

```bash
# Проверка здоровья
docker inspect --format='{{.State.Health.Status}}' <CONTAINER_ID>
```

## Безопасность

### Секреты

Секреты монтируются в `/run/secrets/` и доступны только внутри контейнера.

```bash
# Список секретов
docker secret ls

# Обновление секрета (требует пересоздания)
docker secret rm mysql_password
echo "new_password" | docker secret create mysql_password -
docker service update --force marzban_mysql
```

### Ограничение ресурсов

В `docker-compose.swarm.yml` настроены лимиты:

| Сервис | CPU limit | Memory limit |
|--------|-----------|--------------|
| MySQL | 1 | 1G |
| Marzban | 2 | 2G |
| WARP | 0.5 | 512M |

## Решение проблем

### Сервис не запускается

```bash
# Проверка причины
docker stack ps marzban --no-trunc

# Логи
docker service logs marzban_marzban
```

### Секреты не читаются

```bash
# Проверка что секрет существует
docker secret ls | grep mysql_password

# Пересоздание сервиса
docker service update --force marzban_mysql
```

### Сеть недоступна

```bash
# Проверка сети
docker network ls | grep marzban

# Пересоздание
docker network rm marzban-network
docker network create --driver overlay --attachable marzban-network
docker stack deploy -c docker-compose.swarm.yml marzban
```

## Удаление стека

```bash
# Удаление стека
docker stack rm marzban

# Удаление volumes (ВНИМАНИЕ: удалит данные!)
docker volume rm marzban_mysql_data marzban_marzban_data marzban_marzban_logs

# Удаление секретов
docker secret rm mysql_password mysql_root_password marzban_admin_password telegram_token

# Удаление конфигурации
docker config rm xray_config
```

## Архитектура Swarm

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Swarm                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │               Manager Node                       │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │   │
│  │  │  MySQL  │  │ Marzban │  │  WARP   │         │   │
│  │  │ replica │  │ replica │  │ replica │         │   │
│  │  └─────────┘  └─────────┘  └─────────┘         │   │
│  │       │            │            │               │   │
│  │       └────────────┼────────────┘               │   │
│  │                    │                            │   │
│  │            marzban-network                      │   │
│  │              (overlay)                          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Secrets   │  │   Configs   │  │   Volumes   │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```
