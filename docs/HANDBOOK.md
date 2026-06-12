# HANDBOOK — личный VPN-стек

Сводный документ по всей инфраструктуре. Цель — собрать в одном месте то, что разбросано по трём репозиториям и Cloudflare/Porkbun. Читать как «карту территории», когда что-то пошло не так или нужно вспомнить, что вообще задеплоено.

**Состояние:** VPN-стек **построен полностью**. На МТС-мобиле работает CF Tunnel (TCP). На всех других сетях работают и UDP-каналы (Hysteria2 с port hopping), и TCP-Reality, и CF Tunnel. KZ-нода отложена.

---

## Содержание

1. [Зачем всё это](#1-зачем-всё-это)
2. [Модель угроз](#2-модель-угроз)
3. [Общая архитектура](#3-общая-архитектура)
4. [Каналы и протоколы](#4-каналы-и-протоколы)
5. [Домен и DNS](#5-домен-и-dns)
6. [Серверы и инфраструктура](#6-серверы-и-инфраструктура)
7. [Репозитории](#7-репозитории)
8. [Расходы и складчина](#8-расходы-и-складчина)
9. [Эксплуатация: добавление пользователей и формат ссылок](#9-эксплуатация-добавление-пользователей-и-формат-ссылок)
10. [Клиенты — что ставить друзьям](#10-клиенты--что-ставить-друзьям)
11. [Обслуживание и обновления](#11-обслуживание-и-обновления)
12. [Известные грабли и решение проблем](#12-известные-грабли-и-решение-проблем)
13. [Восстановление после сбоев](#13-восстановление-после-сбоев)
14. [Глоссарий](#14-глоссарий)
15. [Roadmap](#15-roadmap)

---

## 1. Зачем всё это

Личная VPN-инфраструктура для **узкого круга друзей** (~5-15 человек), которая:

- **Пробивает мобильный ТСПУ** в РФ (в т.ч. МТС-овский UDP-блок и whitelist-режимы) — за счёт нескольких независимых каналов.
- **Имеет несколько независимых каналов разных протокольных семейств** — если ТСПУ убьёт один транспорт, другие живут.
- **Полностью под моим контролем** — никаких подписочных сервисов, посредников, отчётности перед третьими лицами.
- **Окупается через прозрачную складчину** — друзья скидываются на сервер, а не покупают услугу.
- **Не является коммерческим VPN-сервисом** — нет публичного приёма платежей, рекламы, оферты, наёмных лиц.

**Что НЕ делается:**
- Не привлекаются незнакомцы.
- Не используются прикрытия вроде «продажа картинок самозанятым».
- Не строится система отслеживания клиентов на досягаемой инфре (см. раздел [Складчина](#8-расходы-и-складчина)).

---

## 2. Модель угроз

Три независимых вектора, которые ТСПУ в РФ реально применяет в 2026:

### Вектор A — IP-blacklist / whitelist режим
**Что:** ТСПУ режет соединения к dst-IP вне белого списка после ~16-20 KB переданных данных (TCP-freeze). Применяется регионально, в основном к мобильным сетям. На МТС с весны 2026 также массово **дропается весь UDP к не-РФ IP**.

**Кого бьёт:** любой канал с прямым подключением к иностранному IP. Reality-TCP, XHTTP-Reality на бараchnom IP. Hysteria2 (UDP) на МТС — режется тотально.

**Что не бьётся:** соединения к whitelisted-IP (Cloudflare, Яндекс-облако, VK-облако). У нас это **CF Tunnel на cf.sethub.org:443** — dst-IP клиент видит cloudflare-овский.

### Вектор B — поведенческая + JA4 детекция
**Что:** ТСПУ собирает статистические признаки TLS-сессии и ML-классификатором отличает Reality-туннели от настоящего HTTPS-трафика. Массово с мая 2026.

**Кого бьёт:** Reality-over-bare-TCP. WireGuard без обфускации, OpenVPN — деградируют за 5-30 минут.

**Что не бьётся:**
- **XHTTP-транспорт** (наш 2444 и CF Tunnel) — HTTP-фреймы + `xPaddingBytes` ломают поведенческий профиль.
- **Hysteria2 с Salamander** — QUIC-пакеты XOR-обфусцированы, ML не за что цепляться. (Но на МТС не пробивает из-за UDP-блока.)
- **AmneziaWG** — обфусцированный WireGuard.

### Вектор C — активное зондирование
**Что:** ТСПУ открывает сомнительный порт «обычным браузером», смотрит, отвечает ли как настоящий сайт.

**Что не бьётся:**
- **Reality** маскирует TLS-хендшейк под легитимный SNI (`www.microsoft.com`).
- **CF Tunnel + cf.sethub.org:443** — для зондира видит валидный CF-сайт.
- **Hysteria2 masquerade** проксирует HTTP-запросы на microsoft.com.

### Принцип защиты
**Несколько независимых каналов разных семейств.** Получилось так:
- TCP-семейство: Reality TCP, XHTTP+Reality, XHTTP+TLS через CF Tunnel.
- UDP-семейство: Hysteria2+Salamander (с port hopping для устойчивости), AmneziaWG.

ТСПУ может убить один-два канала одной волной, но **полная блокада всех 5 независимых путей одновременно** архитектурно дороже, чем удерживать асимметрию false-positives.

---

## 3. Общая архитектура

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Клиент (мобила / десктоп)                           │
│  Hiddify / NekoBox / Streisand (iOS) / NekoRay (Windows) / AmneziaVPN│
└──┬──────────────┬───────────────────┬───────────────────┬──────────┘
   │ Reality TCP  │ XHTTP+Reality     │ XHTTP+TLS         │ Hysteria2+
   │ (2443)       │ (2444)            │ через CF Tunnel   │ Salamander
   │              │                   │ (cf.sethub.org)   │ + port hopping
   │              │                   │ :443              │ (20000-50000/udp)
   │              │                   │                   │
   ▼──────────────▼───────────────────▼───────────────────▼──────────┐
   │      Cloudflare DNS (sethub.org)                                 │
   │  hy.sethub.org → A 45.152.22.222 (grey, DNS only)                │
   │  cf.sethub.org → CNAME tunnel UUID.cfargotunnel.com (CF managed) │
   │  clients.sethub.org → R2 bucket (для зеркала клиентов)           │
   └──────────────────────────────────┬──────────────────────────────┘
                                      ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │      Сервер DE — HOSTKEY, 45.152.22.222, Docker+Dokploy         │
   │                                                                  │
   │   ┌─────────────────────┐    ┌──────────────────────┐            │
   │   │ Marzban (Xray 26.3) │    │ Hysteria2 (apernet)  │            │
   │   │ Панель: 8003        │    │ UDP: 36712           │            │
   │   │ Inbounds:           │    │ Salamander obfs      │            │
   │   │  - VLESS Reality    │    │ Let's Encrypt        │            │
   │   │    (2443/tcp)       │    │ через CF DNS-01      │            │
   │   │  - XHTTP+Reality    │    │                      │            │
   │   │    (2444/tcp)       │    │ iptables NAT:        │            │
   │   │  - XHTTP+TLS+CF     │    │  20000-50000/udp     │            │
   │   │    (8443/tcp,       │    │   → 36712 (host)     │            │
   │   │    только локально) │    │                      │            │
   │   └──────────┬──────────┘    └──────────┬───────────┘            │
   │              │ freedom outbound          │ freedom outbound      │
   │              │                           │                       │
   │   ┌──────────┴───────────┐                                       │
   │   │ cloudflared          │                                       │
   │   │ outbound к CF        │                                       │
   │   │ → cf.sethub.org:443  │                                       │
   │   └──────────┬───────────┘                                       │
   └──────────────┼───────────────────────────┼──────────────────────┘
                  │                           │
                  ▼                           ▼
                          Открытый интернет
```

### Текущее состояние (всё работает ✅)

| Канал | Где работает | Где нет |
|---|---|---|
| **VLESS Reality TCP** (2443) | дом, мягкие сети | не пробьёт жёсткий JA4-DPI |
| **VLESS XHTTP+Reality** (2444) | дом, частично мобильные | агрессивный JA4 у конкретного оператора может ловить |
| **XHTTP+TLS через CF Tunnel** (cf.sethub.org:443) | **МТС, whitelist-режимы**, всё остальное | (универсальный) |
| **Hysteria2 + Salamander + port hopping** | дом, Билайн, Мегафон | **МТС блочит UDP в принципе** — этот канал на МТС не идёт |
| **Self-hosted AmneziaWG** (отдельно) | дом, частично | (резерв, не в этом стеке) |

---

## 4. Каналы и протоколы

| Канал | Порт клиента | Транспорт | A (whitelist) | B (JA4 DPI) | C (зондирование) | МТС-мобильный |
|---|---|---|---|---|---|---|
| **VLESS+Reality TCP** | `45.152.22.222:2443` | bare TCP | ❌ | ⚠ (детект с мая'26) | ✅ Reality | ⚠ через раз |
| **VLESS+XHTTP+Reality** | `45.152.22.222:2444` | TCP, HTTP-фреймы + padding | ❌ | ✅ XHTTP+padding | ✅ Reality | ⚠ режется |
| **VLESS+XHTTP+TLS (CF Tunnel)** | `cf.sethub.org:443` | TCP через CF edge | ✅ dst-IP = CF | ✅ XHTTP | ✅ TLS реальный | **✅ ~207 мс** |
| **Hysteria2+Salamander+hop** | `hy.sethub.org:36712,ports=20000-50000` | UDP/QUIC, Salamander, port hop | ❌ | ✅ Salamander | ✅ masquerade | ❌ UDP блок |
| **AmneziaWG** | (отдельный сервер) | UDP, WG-обфускация | ⚠ | ✅ обфускация | n/a | ⚠ |

### Приоритизация для друзей
1. **На МТС-мобиле** — **CF Tunnel (`cf.sethub.org:443`)** — единственный надёжный канал.
2. **На Билайне/Мегафоне/WiFi/иностранных сетях** — **Hysteria2 (`:36712,20000-50000`)** — самый быстрый (~40 мс).
3. **На десктопе/WiFi** — любой работает; самый «лёгкий» — VLESS Reality TCP 2443.
4. **Резерв** — XHTTP Reality 2444 как fallback.

Hiddify (и другие современные клиенты) поддерживают **несколько профилей** — можно держать все 3-4 и переключаться руками или авто-роутингом.

---

## 5. Домен и DNS

### Регистрация
- **Регистратор:** Porkbun (зарубежный, принимает KZ-карту).
- **DNS:** Cloudflare (зона `sethub.org` на CF NS: `amalia.ns.cloudflare.com`, `morgan.ns.cloudflare.com`).
- **WHOIS Privacy:** включена в Porkbun (бесплатно для .org).

### Поддомены

| Поддомен | Тип | Значение | Proxy | Для чего |
|---|---|---|---|---|
| `hy.sethub.org` | A | `45.152.22.222` | 🔘 grey (DNS only) | Hysteria2 (CF не проксирует UDP — нужен прямой) |
| `cf.sethub.org` | CNAME | `<uuid>.cfargotunnel.com` | (CF managed) | **CF Tunnel** для XHTTP+TLS на 443 |
| `clients.sethub.org` | (R2 managed) | (CF managed) | (CF managed) | Зеркало VPN-клиентов на R2 |
| `vpn.sethub.org` | A | `45.152.22.222` | 🟠 orange | (опц.) Marzban панель через CF |

### Cloudflare Zero Trust (для CF Tunnel)
- Tunnel `marzban` → Public Hostname `cf.sethub.org` → Service `https://marzban:8443`.
- Critical settings:
  - **No TLS Verify: ON**
  - **Origin Server Name: `cf.sethub.org`** (без этого SNI не совпадает с cert на origin)

### Cloudflare R2 (для clients-mirror)
- Bucket `sethub-clients` с Custom Domain `clients.sethub.org`.
- Account API Token с правом Object Read & Write — лежит в GitHub Secrets репо clients-mirror.

### CF API Token (для Hysteria2 ACME)
- Скоп: `Zone — DNS — Edit` на зоне `sethub.org`.
- Использование: Hysteria2 DNS-01 challenge.
- Хранится: в `.env` сервера / Environment Variables в Dokploy.

### CF Tunnel Token
- Из Zero Trust dashboard → Tunnels → marzban → Connector token.
- Хранится: `CLOUDFLARE_TUNNEL_TOKEN` в `.env` cloudflared контейнера.

### Безопасность секретов
- **Секретно:** CF API Token, CF Tunnel Token, Cloudflare Origin Cert key, `OBFS_PASSWORD`, `AUTH_PASSWORD`, `SUDO_PASSWORD`, Reality `privateKey`, R2 API Secret Key.
- **Не секретно:** Zone ID, Account ID, Reality `publicKey`, доменные имена, IP-серверов.

---

## 6. Серверы и инфраструктура

### Текущие
| Хост | Провайдер | IP | Роль | ОС | Расходы (мес) |
|---|---|---|---|---|---|
| **DE-exit** | HOSTKEY (Франкфурт) | `45.152.22.222` | Marzban + Hysteria2 + cloudflared + Dokploy | Linux + Docker | ~800 ₽ |

### Софт на сервере
- **Docker + Docker Compose** — все сервисы в контейнерах.
- **Dokploy** — менеджмент приложений (UI), Traefik для роутинга HTTPS.
- **dokploy-network** — общая Docker-сеть для Marzban + Hysteria2 + cloudflared.
- **iptables NAT** — port hopping для Hysteria2 (через systemd-сервис).

### Контейнеры
- `marzban` — Marzban-панель с Xray-core v26.3.27 (XHTTP, Reality, TLS).
- `hysteria2` — apernet/hysteria из tobyxdd/hysteria:latest.
- `cloudflared` — Cloudflare Tunnel connector (выходит на CF).

### Сетевые порты (внешние)
```
22/tcp      - SSH (только с известных IP)
80/tcp      - Traefik (HTTP→HTTPS redirect)
443/tcp     - Traefik (Dokploy роутинг доменов)
2443/tcp    - VLESS Reality TCP
2444/tcp    - VLESS XHTTP+Reality
8003/tcp   - Marzban панель (HTTPS, self-signed)
36712/udp  - Hysteria2 (основной порт)
20000-50000/udp - Hysteria2 port hopping (iptables NAT редиректит на 36712)
```

**Закрытые порты:**
- `8443/tcp` (был CF-fronting напрямую) — больше не нужен, CF Tunnel идёт через docker-сеть.

### Системные сервисы
- `hysteria-porthop.service` — systemd-юнит, восстанавливает iptables NAT правило для port hopping при загрузке. Установка — `setup-port-hopping.sh` + создание systemd-юнита (см. hysteria2-node README).

---

## 7. Репозитории

| Репо | Назначение | Visibility |
|---|---|---|
| **mikey-semy/marzban-vpn** | Marzban-панель + Xray-инбаунды + CF Tunnel | публичный |
| **mikey-semy/hysteria2-node** | Hysteria2 сервер + port hopping setup | приватный |
| **mikey-semy/clients-mirror** | Зеркало VPN-клиентов на Cloudflare R2 | приватный |

### marzban-vpn (структура)
- `config.json` — три VLESS инбаунда: Reality TCP, XHTTP+Reality, XHTTP+TLS+CF.
- `Dockerfile` — `FROM gozargah/marzban:v0.8.4` + пин Xray-core v26.3.27.
- `docker-compose.marzban.yml` — Marzban + SQLite, ports 8003/2443/2444.
- `docker-compose.cloudflared.yml` — cloudflared контейнер.
- `docker-entrypoint.sh` — Reality-keys gen, xray_config reseed, CF cert check.
- `docs/` — `HANDBOOK.md` (этот файл), `CLOUDFLARE_FRONTING.md`, `CLOUDFLARE_TUNNEL.md`, `INSTALLATION.md`, `TROUBLESHOOTING.md`, и др.

### hysteria2-node
- `Dockerfile` + `docker-entrypoint.sh` + `server.yaml.tmpl` — envsubst-генерация конфига.
- `docker-compose.yml` — Hysteria2 на UDP 36712, том для ACME.
- `setup-port-hopping.sh` — bash-скрипт для настройки iptables NAT + ufw для port hopping.
- `docs/PORT_HOPPING.md` — пошаговая документация.

### clients-mirror
- `clients.toml` — 11 клиентов: Hiddify, AmneziaVPN, Husi, NekoBox, NekoRay, v2rayNG, v2rayN, Karing, sing-box, ByeByeDPI, GoodbyeDPI.
- `update.py` — GitHub Releases API → manifest diff → upload в R2 → рендеринг index.html.
- `.github/workflows/update.yml` — daily cron + on-push trigger.
- `docs/CLIENTS.md` — platform-first гид по клиентам (Windows / macOS / iOS / Android + DPI-десинхр).

---

## 8. Расходы и складчина

### Расходы

| Статья | ₽/мес | ₽/год |
|---|---|---|
| HOSTKEY DE сервер | ~800 | ~9 600 |
| Домен sethub.org (.org) | ~85 | ~1 020 |
| Cloudflare Free + R2 free tier + Zero Trust Free | 0 | 0 |
| **Итого** | **~885** | **~10 620** |

При планируемой KZ-ноде (отложено): +500-1000 ₽/мес.

### Модель складчины (НЕ услуги)

**Что:** общий чат с реальными знакомыми, прозрачный расчёт «вот сервер, вот реквизиты, скидываемся, кто скинулся — пользуется месяц». Это **разделение издержек между знакомыми**, не «продажа VPN-доступа».

**Как считаем:**
- Общие расходы / число узлов = базовая ставка/мес.
- 5 узлов → ~180 ₽/мес/чел.
- 10 узлов → ~90 ₽/мес/чел.
- 15 узлов → ~60 ₽/мес/чел.

«Узел» = один реальный знакомый. Внутри узла может быть семья.

**Как платят:** СБП или перевод физик→физик (включая KZ-карту).

### Что НЕ делается
- ❌ Прикрытие VPN-платежей под «продажу картинок самозанятым».
- ❌ Шифрованный маппинг «UUID → знакомый» как анти-следственная архитектура.
- ❌ Привлечение через рекламу, изолированные каналы лора-vs-инструкций.

---

## 9. Эксплуатация: добавление пользователей и формат ссылок

### Добавить нового узла

1. Marzban панель `https://45.152.22.222:8003/dashboard/` или `https://vpn.sethub.org/dashboard/`.
2. Логин: `SUDO_USERNAME` / `SUDO_PASSWORD`.
3. **Create user**:
   - Имя: `vasya`.
   - **Inbounds:** галки на `VLESS Reality`, `VLESS XHTTP Reality`, **`VLESS XHTTP CF`** (все три).
   - Срок: дата expire (когда складчина истечёт) или «no limit».
   - Комментарий: `Вася / оплачен до 2026-07-15`.
   - Save.
4. У юзера копируешь **Subscription URL** → шлёшь другу — он импортит в Hiddify, получит все три VLESS-ссылки.
5. **Отдельно для Hysteria2** — собираешь URI руками (общий пароль для всех):

   **Базовая Hysteria2 ссылка (без port hopping):**
   ```
   hysteria2://AUTH_PASSWORD@hy.sethub.org:36712/?obfs=salamander&obfs-password=OBFS_PASSWORD&sni=hy.sethub.org#Hysteria2-DE
   ```

   **С port hopping (для устойчивости от точечных операторских блоков):**
   ```
   hysteria2://AUTH_PASSWORD@hy.sethub.org:36712/?obfs=salamander&obfs-password=OBFS_PASSWORD&sni=hy.sethub.org&ports=20000-50000#Hysteria2-DE-Hop
   ```

   ⚠ Если в паролях `+`, `/`, `=` — URL-кодировать (`%2B`, `%2F`, `%3D`).
   ⚠ Hiddify понимает `&ports=20000-50000`. NekoBox/Husi также понимают `:36712,20000-50000` (синтаксис URI), но в Hiddify это не парсится.

### Продлить / снять
- Marzban → user → Expire date → Save.
- Снять: Disable (UUID сохраняется) или Delete.

### Сменить Reality-ключи
1. На сервере: `docker exec marzban rm /var/lib/marzban/reality_keys.env && docker restart marzban`.
2. Перевыпустить subscription у всех юзеров.

### Сменить Hysteria2 пароли
1. Меняешь `OBFS_PASSWORD` / `AUTH_PASSWORD` в Dokploy Environment Variables (или `.env` на сервере) → Redeploy.
2. Перевыпустить Hysteria2-ссылки всем (вручную, у Hysteria2 нет панели генерации).

---

## 10. Клиенты — что ставить друзьям

См. **подробный гид** в [clients-mirror репо → docs/CLIENTS.md](https://github.com/mikey-semy/clients-mirror/blob/main/docs/CLIENTS.md). Здесь — кратко.

### По платформам

| Платформа | Основной | Резерв | Десинхр (опц.) |
|---|---|---|---|
| **Windows** | **Hiddify** | NekoRay / v2rayN / Karing | GoodbyeDPI |
| **macOS (MacBook)** | **Hiddify** | Karing / AmneziaVPN | — |
| **iOS (iPhone)** | **Streisand** (App Store) | Hiddify Next / Shadowrocket ($3) | — |
| **Android** | **Hiddify** | Husi / NekoBox / v2rayNG | ByeByeDPI |
| **Linux** | Hiddify (AppImage) / sing-box CLI | NekoRay | zapret |

### Где брать клиенты
- **clients.sethub.org/index.html** — наше R2-зеркало (обходит закрытие GitHub в РФ-мобильных сетях). Daily-обновляется через GitHub Actions.
- iOS — только App Store, ссылки в CLIENTS.md.

### Импорт ссылок
- **Marzban (VLESS)** — Subscription URL в Hiddify «Add from URL/clipboard». Все три инбаунда (Reality TCP, XHTTP+Reality, CF Tunnel) прилетят разом.
- **Hysteria2** — прямая ссылка `hysteria2://...` в clipboard, Hiddify → Add from clipboard.

### Что давать другу под мобильный МТС

**Только CF Tunnel** работает гарантированно:
```
vless://UUID@cf.sethub.org:443?security=tls&type=xhttp&path=%2Fapi%2Fv2%2Fcf&mode=packet-up&sni=cf.sethub.org&fp=chrome#CF-Tunnel
```

(берётся из Marzban subscription URL после клика на inbound CF в Hosts).

---

## 11. Обслуживание и обновления

### Обновить Xray-core
В `Dockerfile` репо `marzban-vpn`: `ARG XRAY_VERSION=v26.3.27` → новая версия → push → Dokploy redeploy.

### Обновить Marzban
`ARG MARZBAN_VERSION=v0.8.4` → новая → push. **Бэкап БД до обновления!**

### Обновить Hysteria2
`tobyxdd/hysteria:latest` авто-обновляется при пересборке. `docker compose up -d --build`.

### Обновить cloudflared
`cloudflare/cloudflared:latest` авто-обновляется. Перезапусти контейнер.

### Бэкап Marzban БД
```bash
docker exec marzban cp /var/lib/marzban/db.sqlite3 /var/lib/marzban/db.sqlite3.bak
docker cp marzban:/var/lib/marzban/db.sqlite3.bak ./db-backup-$(date +%F).sqlite3
```

### Бэкап секретов
В password manager (1Password / Bitwarden):
- Reality `privateKey` (и из `/var/lib/marzban/reality_keys.env`)
- Hysteria2 `OBFS_PASSWORD`, `AUTH_PASSWORD`
- CF API Token (для ACME)
- CF Tunnel Token
- CF Origin Cert + Key (если использовался для прямого 8443, сейчас отложен)
- R2 Access Key + Secret Key (для GH Actions)
- Marzban admin password

---

## 12. Известные грабли и решение проблем

### Marzban (v0.8.4) специфическое
- **`/api/health` возвращает 404** — нет такого. Healthcheck на `GET /`.
- **`DISABLE_INTERNAL_SSL=false` обязательно** — иначе Marzban биндится только на 127.0.0.1.
- **SQLite default → `/code/db.sqlite3`** в readonly слое образа. Наш entrypoint форсит `/var/lib/marzban/db.sqlite3`.
- **xray_config.json «залипает» в томе** — наш entrypoint reseed-ит шаблон при каждом старте.

### Hysteria2 специфическое
- **ACME rate-limit** — Let's Encrypt блочит на час после 5 неудач. DNS-запись + CF API Token должны быть верные ДО первого старта.
- **МТС-мобильный полностью режет UDP** — port hopping не помогает, потому что блочится не порт, а семейство. Используй CF Tunnel.
- **Hiddify не парсит `:port,range` в URI** — нужно использовать `&ports=20000-50000` в query.

### CF Tunnel специфическое
- **`No TLS Verify` обязательно** для public hostname.
- **`Origin Server Name: cf.sethub.org`** иначе SNI не совпадает с CF Origin Cert на marzban → 502 Bad Gateway.
- **Tunnel показывает INACTIVE в UI** при первом коннекте — поможет рефреш через 30 сек.
- **Cloudflared logs много `stream X canceled by remote with error code 0`** — это **нормально**, XHTTP packet-up закрывает streams явно.

### Cloudflare R2
- **R2 не отдаёт `/` как `index.html`** — нужен **Page Rule** или **Redirect Rule** для root → `/index.html`. У нас Page Rule `https://clients.sethub.org/` → 302 → `/index.html`.
- **Token: Account API Token** (не User), иначе теряется при смене юзера.

### Сеть / клиенты
- **Chrome ERR_CONNECTION_RESET с CF-сайтами** — кэш CHrome'а. Fix: `chrome://net-internals/#sockets` → Flush + `#dns` → Clear.
- **HTTP/3 (QUIC) глючит на некоторых Windows** — `chrome://flags/#enable-quic` → Disabled. Симптом: `ERR_FAILED` на сайтах с `Alt-Svc: h3`.
- **`+`, `/`, `=` в паролях ломают URI** — URL-кодировать.
- **«На WiFi работает, на мобиле — нет»** — проверь не висит ли другой VPN; на МТС-мобиле работает только CF Tunnel.

---

## 13. Восстановление после сбоев

### Сценарий 1 — сервер не отвечает
1. HOSTKEY консоль → жив ли VM, есть ли сетевая активность.
2. Перезагрузить VM при висе.
3. SSH → `docker ps` → перезапустить упавшие.

### Сценарий 2 — Marzban БД потеряна
1. `docker compose down`.
2. `docker cp ./db-backup-XXXX.sqlite3 marzban:/var/lib/marzban/db.sqlite3`.
3. `docker compose up -d`.
4. Без бэкапа — пересоздать юзеров; Reality-ключи возьмутся из `reality_keys.env` (тоже в volume).

### Сценарий 3 — Hysteria2 пароли потеряны
1. Из passwords manager — вернуть в `.env`, рестарт.
2. Без passwords manager — сгенерить новые, перевыпустить клиентам.

### Сценарий 4 — CF Tunnel сломался
1. Zero Trust → Tunnel marzban → проверить статус. Если красный — глянуть `docker logs cloudflared`.
2. Проверить что CF_TUNNEL_TOKEN не истёк (CF может ревовнуть после долгой inactivity).
3. Если token сломан — создать новый туннель в CF, обновить `.env` cloudflared, redeploy.

### Сценарий 5 — port hopping отвалился после ребута
1. `sudo systemctl status hysteria-porthop` — должен быть active.
2. Если нет — `sudo systemctl start hysteria-porthop`.
3. Или вручную: `sudo iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports 36712`.

### Сценарий 6 — домен sethub.org заблокирован / истёк
1. Истёк — продлить в Porkbun.
2. Заблокирован — резервный домен → CF → DNS-записи + новый Origin Cert + новый Tunnel hostname.

---

## 14. Глоссарий

| Термин | Что |
|---|---|
| **ТСПУ** | Технические Средства Противодействия Угрозам — оборудование РКН на стороне операторов для DPI/блокировок. |
| **DPI** | Deep Packet Inspection — глубокий анализ пакетов на уровне ISP. |
| **Reality** | Транспорт VLESS, при котором сервер при handshake мимикрирует под легитимный сайт (`dest`/`serverNames`). |
| **XHTTP** | Транспорт Xray, разбивающий трафик на отдельные HTTP-транзакции с padding. Ранее `splithttp`. |
| **Hysteria2** | VPN-протокол на QUIC/UDP с агрессивным CC «brutal». |
| **Salamander** | Обфускация Hysteria2 — XOR над QUIC-пакетами. |
| **Port hopping** | Hysteria2 фича: клиент рандомно меняет dst-порт из заявленного диапазона, сервер через iptables NAT принимает весь диапазон на один порт. |
| **AmneziaWG** | Обфусцированный WireGuard. |
| **ACME / DNS-01** | Протокол Let's Encrypt. DNS-01 — challenge через TXT-запись в DNS (нужны API-права на зону). |
| **CF-fronting** | Подача трафика через CF edge, dst-IP для DPI = CF (в белом списке). |
| **CF Tunnel** | Альтернатива fronting'у: cloudflared делает исходящее соединение от origin к CF, никаких inbound портов не нужно. Стандартный 443/tcp у клиента. |
| **Whitelist-режим** | Режим ТСПУ, при котором разрешены только соединения к white-list IPs. |
| **Складчина** | Прозрачное разделение расходов между знакомыми. |
| **Узел** | Один реальный знакомый-друг, скидывающийся в складчину. |

---

## 15. Roadmap

### ✅ Сделано
- Marzban-exit (DE) с VLESS Reality TCP (2443) и XHTTP+Reality (2444), Xray-core v26.3.27 пин.
- Hysteria2 (DE) с Salamander обфускацией на UDP 36712, Let's Encrypt через CF DNS-01.
- Hysteria2 **port hopping** через iptables NAT (диапазон 20000-50000/udp) с systemd-персистентностью.
- Домен sethub.org, Porkbun регистратор + Cloudflare DNS.
- **Cloudflare Tunnel** для cf.sethub.org:443 — обход whitelist + работа на МТС-мобильном.
- Cloudflare Origin Certificate инфраструктура (cf-origin.crt в Marzban volume).
- **clients-mirror** на Cloudflare R2 + custom domain `clients.sethub.org` + GitHub Actions daily cron.
- 11 клиентов мирорятся (Hiddify, AmneziaVPN, Husi, NekoBox, NekoRay, v2rayNG, v2rayN, Karing, sing-box, ByeByeDPI, GoodbyeDPI).
- Полная документация: HANDBOOK, CLOUDFLARE_FRONTING, CLOUDFLARE_TUNNEL, PORT_HOPPING, CLIENTS, INSTALLATION, TROUBLESHOOTING.

### ⬜ Отложено / на будущее
- **KZ-нода** (Hysteria2 в Алматы) — независимый географический канал + потенциально быстрее на CIS-маршрутах. Бюджет 500-1000 ₽/мес.
- **vpn.sethub.org** как красивый адрес панели Marzban через Traefik с Let's Encrypt.
- **Бэкапы Marzban БД автоматизировать** (cron + загрузка в R2 → бакет sethub-backup).
- **AmneziaWG в основном стеке** (сейчас self-hosted отдельно).

### 💡 Экспериментально
- Reality эволюция — `mldsa65` (пост-квантовая), `stream-one` mode для XHTTP с HTTP/2-мультиплексом.
- ВПН-узел в третьей юрисдикции (для географической избыточности).
- Перенос с Marzban на PasarGuard / Remnawave (если апстрим Marzban подзависнет).

---

**Последнее обновление:** см. git log этого файла.

**Поддержка:** не существует. Это личная инфра. Документ для тебя самого и для возможной передачи другу-помощнику.
