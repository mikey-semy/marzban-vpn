# Marzban VPN — XHTTP+Reality exit для обхода ТСПУ

Самохостовая VPN-панель на базе [Marzban](https://github.com/Gozargah/Marzban) с инбаундами **VLESS Reality** и **VLESS XHTTP+Reality**, заточенная под обход DPI/ТСПУ (включая майскую волну 2026 с поведенческим/JA4-детектом). Деплой — Docker / Dokploy.

## Что внутри

- **Marzban Panel** — веб-интерфейс управления пользователями
- **VLESS XHTTP + Reality** — основной канал: XHTTP бьёт трафик на HTTP-транзакции + padding, ломая поведенческий анализ ТСПУ (то, на чём палится голый TCP+Reality)
- **VLESS Reality (TCP)** — запасной/совместимый инбаунд
- **Xray-core запинен на v26.3.27** — гарантия поддержки `xhttp` и свежий anti-DPI код
- **SQLite** — без отдельного контейнера БД, бэкап = копия одного файла
- **Автогенерация Reality-ключей** при первом старте (пишутся в логи и `/var/lib/marzban/reality_keys.env`)

## Протоколы и порты

| Инбаунд | Порт | Назначение |
|---------|------|-----------|
| Панель управления | 8003 | веб-UI Marzban (`/dashboard/`) |
| VLESS XHTTP + Reality | 2444 | **основной** канал против ТСПУ |
| VLESS Reality (TCP) | 2443 | запасной/совместимость |

## Быстрый старт

```bash
git clone https://github.com/mikey-semy/marzban-vpn.git
cd marzban-vpn

cp .env.example .env
nano .env   # см. минимальный набор ниже

docker network create dokploy-network   # если ещё нет
docker compose -f docker-compose.marzban.yml up -d --build
```

Минимальный `.env` (роль — exit за границей, БД — SQLite):

```env
SUDO_USERNAME=admin
SUDO_PASSWORD=сильный_пароль
UVICORN_PORT=8003
DISABLE_INTERNAL_SSL=false        # Marzban v0.8.4 без SSL слушает только localhost!
# SQLALCHEMY_DATABASE_URL НЕ задаём → SQLite в /var/lib/marzban/db.sqlite3
# Reality-ключи можно не задавать — сгенерируются автоматически (потом скопируй из логов):
# REALITY_PRIVATE_KEY=...
# REALITY_PUBLIC_KEY=...
REALITY_DEST=www.microsoft.com:443
REALITY_SERVER_NAMES=www.microsoft.com
```

Панель: `https://<server-ip>:8003/dashboard/` (самоподписанный сертификат — примите предупреждение).

> ⚠️ **SNI зависит от роли ноды.** Для exit за границей нужен глобальный SNI (`www.microsoft.com`/`github.com`) — Yandex-домены (`ya.ru`) на не-РФ IP дают IP↔SNI mismatch и палятся DPI. `ya.ru` уместен только на bridge внутри РФ.

## Клиенты

XHTTP понимают только свежие клиенты: **Hiddify**, **NekoBox**, **v2rayNG** (актуальные версии). Amnezia XHTTP не поддерживает.

## Архитектура

```
Клиент ──XHTTP+Reality──▶  Marzban exit (Xray 26.3.27)  ──▶ интернет
   (Hiddify/NekoBox)         SQLite, порт 2444 / 2443
```

## Документация

- [Конфигурация](docs/CONFIGURATION.md) — переменные окружения
- [Dokploy](docs/DOKPLOY.md) — развёртывание в Dokploy
- [Решение проблем](docs/TROUBLESHOOTING.md) — диагностика

## Безопасность

- Reality-ключи генерируются автоматически и уникальны на каждый деплой; для строгости после первого старта скопируй их в `.env` и не свети.
- Панель (8003) держи за reverse-proxy или ограничь по IP.
- Не выкладывай рабочий `.env` в git (он в `.gitignore`).

## Опционально: WARP

По умолчанию WARP **отключён** (трафик идёт напрямую с exit-IP). Нужен, только если конкретный сервис блокирует datacenter-IP (напр. OpenAI). Тогда: задеплой `docker-compose.warp.yml`, верни warp-outbound + routing в `config.json`, выставь `WARP_ENABLED=true`. Серверный WARP (выход из Германии) предпочтительнее клиентского (Hiddify-WARP в РФ душат).

## Лицензия

MIT License.
