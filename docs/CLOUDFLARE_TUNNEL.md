# Cloudflare Tunnel — путь через CF на стандартном 443/tcp

Дополняет [CLOUDFLARE_FRONTING.md](CLOUDFLARE_FRONTING.md). Тот инбаунд (порт 8443) **остаётся** — он рабочий для тех сетей, где 8443 проходит. Но операторы (МТС и подобные) часто блочат нестандартные порты на CF — там нужен путь через **стандартный 443/tcp**, который оператор заблочить не может, не положив пол-интернета.

Делается через **Cloudflare Tunnel (cloudflared)**.

## Идея

```
Клиент → cf.sethub.org:443 (стандартный HTTPS) → CF edge
                                                    ↕
                              (зашифрованный туннель, ИСХОДЯЩИЙ от нас к CF)
                                                    ↕
                         cloudflared в Docker у нас на сервере
                                                    ↕
                              http://marzban:8443 через dokploy-network
                                                    ↕
                                         Marzban (тот же VLESS XHTTP CF инбаунд)
```

**Ключевые преимущества:**
- Клиент идёт на **стандартный 443** — оператор не может заблочить, не сломав HTTPS как класс.
- Origin **не открывает никакие порты наружу** для CF Tunnel — cloudflared делает исходящее соединение, как обычный браузер.
- CF автоматически выпускает Let's Encrypt сертификат для `cf.sethub.org` — клиент видит валидный публичный TLS, без всяких «Allow Insecure».
- Origin Certificate использовать необязательно (cloudflared может с `noTLSVerify`).
- Free план Cloudflare покрывает с запасом.

## Сетап — два параллельных хода

### A. В Cloudflare Zero Trust dashboard
Это часть твоего CF-аккаунта, бесплатная. Войти можно через тот же CF-логин.

1. **dash.cloudflare.com** → в боковом меню «Zero Trust».
2. При первом входе спросят имя команды (что-то типа `sethub`) и план — выбирай **Free**. Никаких карт привязывать не надо.
3. После настройки → **Networks → Tunnels → Create a tunnel**.
4. Тип **Cloudflared** → Next.
5. **Tunnel name:** `marzban` → Save tunnel.
6. На экране «Install connector» **скопируй токен** — это длинная строка вида `eyJ...`. Сохрани в надёжное место. На сервер сейчас НЕ ставь cloudflared «инструкциями для разных ОС» — у нас он в Docker.
7. Next → **Public Hostname** (это самый важный шаг):
   - **Subdomain:** `cf`
   - **Domain:** `sethub.org` (выбираешь из списка зон)
   - **Path:** (пусто или `api/v2/cf` — Xray примет любой матчинг)
   - **Service Type:** `HTTPS`
   - **URL:** `marzban:8443`
   - Раскрой **Additional application settings** → **TLS** → включи **No TLS Verify** (потому что Marzban на 8443 отдаёт CF Origin Cert, которому CF Tunnel доверять не обязан — он внутри docker-сети).
8. Save.

После сохранения CF сам пропишет CNAME-запись `cf.sethub.org` на UUID туннеля (можно посмотреть в DNS → она будет вида `<uuid>.cfargotunnel.com`, тип CNAME, серое облако — это норма для Tunnel).

⚠ **Удали старую A-запись** `cf.sethub.org → 45.152.22.222` если она есть (CF при создании public hostname должна её перезатёрть, но проверь). Иначе будет конфликт.

### B. На сервере
1. **В `.env` Marzban-приложения** добавь переменную (или в Dokploy Environment Variables):
   ```
   CLOUDFLARE_TUNNEL_TOKEN=<токен из шага A.6>
   ```
2. **Подними cloudflared стек.** Через Dokploy: создай новое приложение типа Docker Compose, репозиторий тот же, ветка main, путь к compose-файлу: `docker-compose.cloudflared.yml`. Не забудь подсунуть ту же .env с токеном.

   Или вручную по SSH:
   ```bash
   cd /etc/dokploy/compose/<имя_приложения>/code   # или где у тебя репо
   docker compose -f docker-compose.cloudflared.yml up -d
   ```

3. Проверь, что cloudflared подключился:
   ```bash
   docker logs cloudflared --tail 30
   ```
   Ожидаешь увидеть:
   ```
   Registered tunnel connection ... connIndex=0 ...
   Registered tunnel connection ... connIndex=1 ...
   ```
   Обычно 4 соединения в разные CF датацентры. В Zero Trust UI на странице туннеля статус станет **HEALTHY**.

## Marzban Host для нового пути

Чтобы у юзеров появилась ссылка через 443:

1. Marzban → **Hosts** → разверни `VLESS XHTTP CF` → **Добавить хост**.
2. Заполни:
   - **Remark:** `🌐 CF Tunnel`
   - **Address:** `cf.sethub.org`
   - **Port:** `443`
   - **SNI:** `cf.sethub.org`
   - **Host:** `cf.sethub.org`
   - **Security:** `tls`
   - **ALPN:** оставь `h2,http/1.1` или дефолт
   - **Fingerprint:** `chrome` (рекомендуется)
   - **Allow Insecure:** **OFF** (у CF теперь валидный публичный сертификат)
3. Применить.

У юзеров в subscription теперь будут две ссылки на CF-инбаунд:
- `cf.sethub.org:8443` (прямой CF proxy, для домашних/неагрессивных сетей)
- `cf.sethub.org:443` (через Tunnel, для МТС и whitelist-режима)

Клиент сам подберёт рабочий или ты вручную выбираешь.

## Проверка с мобильного

На iPhone в Safari **с МТС-мобильных данных без VPN**:
```
https://cf.sethub.org/
```
(без указания порта = 443)

Должно **отдать какую-то страницу** (хоть 404 от Xray) — не зависнуть. Если отдаёт ответ — туннель жив, МТС пропускает 443/tcp как обычный HTTPS, и в Hiddify теперь VLESS-ссылка с `:443` должна подключиться.

## Когда что-то идёт не так

| Симптом | Причина | Лечение |
|---|---|---|
| `cloudflared` логи: `Failed to fetch token`/`Unauthorized` | Токен не подхватился | Проверь `.env`: `CLOUDFLARE_TUNNEL_TOKEN=<строка>`, без кавычек/пробелов; пересоздай контейнер |
| Статус туннеля в Zero Trust UI: `DOWN` | cloudflared не стартовал или нет интернета | `docker logs cloudflared`; проверь что 443/tcp **исходящий** открыт у HOSTKEY (на 99% открыт) |
| `cf.sethub.org` отдаёт CF welcome page вместо Xray | Public Hostname не настроен или Service URL неверный | Zero Trust → Tunnels → marzban → Public Hostnames → проверь `https://marzban:8443` + `No TLS Verify ON` |
| Клиент коннектится, но рвёт через секунду | Cloudflared не доверяет cert Marzban'а | `No TLS Verify` должен быть **ON** в настройках Public Hostname |
| Старая A-запись `cf.sethub.org → IP` конфликтует с CNAME от туннеля | CF не успела затереть | Удали A вручную в DNS Records, CNAME `cf` → `<uuid>.cfargotunnel.com` должен остаться |

## Резюме: сколько каналов теперь у юзера

После всех шагов у каждого VPN-юзера в Marzban subscription будут **минимум** такие ссылки на один и тот же набор VLESS-инбаундов:

| Канал | Куда | Когда работает |
|---|---|---|
| VLESS Reality TCP | `45.152.22.222:2443` | дома, мягкие сети, где Reality ещё не палится |
| VLESS XHTTP Reality | `45.152.22.222:2444` | где Reality+TCP не годится, нужен XHTTP-обход поведенческого DPI |
| VLESS XHTTP CF (прямой) | `cf.sethub.org:8443` | где CF на нестандартных портах ещё проходит |
| **VLESS XHTTP CF (Tunnel)** | **`cf.sethub.org:443`** | **где режут всё, кроме стандартного 443/tcp (МТС, whitelist-режимы)** |

Это и есть «защита в глубину» — не один протокол на все случаи, а четыре независимых пути, и клиент пробует подряд, пока какой-то не пройдёт.
