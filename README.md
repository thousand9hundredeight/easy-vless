# easy-vless 🌐

Автоматическая идемпотентная установка **VLESS Reality (Docker + Xray-core)** на ваш сервер, с опциональной **веб‑панелью 3X‑UI** и **встроенным мониторингом**.

Тестировано на Debian 12 / Ubuntu 22.04+.

Набор скриптов **идемпотентен**: вы можете запускать `easy-install.sh` несколько раз. При каждом запуске старая установка VLESS удаляется, и контейнер пересоздаётся с новыми ключами и параметрами, без затрагивания уже работающих сервисов (например, MTProto через ваш nginx).

## Архитектура

```text
Internet
  │
  └── :1443 ──→ Docker vless-reality
                    └── VLESS + Reality + XTLS‑Vision
```

- Основной контейнер Xray‑core `vless-reality` публикуется на отдельном порту, например `:1443/tcp` (или `:2443/tcp`), чтобы не мешать nginx‑сервису MTProto на `:443`.
- nginx используется **только для MTProto** и не участвует в VLESS‑трафике. Если нужно, nginx можно использовать отдельно, но не как TLS‑прокси для VLESS в этом сценарии.
- Внешний клиент → ваша ссылка VLESS Reality → `vless-reality` → службы.

## Что получается после установки

| Компонент | Описание | Порты (пример) |
|---|---|---|
| VLESS Reality | Основной VPN‑туннель | `8443` внутри, `1443` снаружи |
| 3X‑UI (опц.) | Веб‑панель для управления Xray | `:20870` |
| vpnmon | tmux‑сессия с мониторингом | внутри контейнера |

В конце будет сгенерирована готовая к импорту клиентская ссылка `vless://...` и сохранена в `/root/vless-credentials.txt`.

## Структура репозитория

```bash
easy-vless/
├── easy-install.sh     — главный оркестратор
├── base.sh             — базовая настройка (apt, Docker, UFW, зависимости)
├── vless.sh            — настройка VLESS Reality (контейнер, ключи, config.json)
├── rotate-sni.sh       — смена Reality‑SNI раз в месяц
├── vpnmon.sh           — вспомогательный мониторинг (tmux, htop, логи)
├── .env                — конфигурация (не секретные параметры)
├── README.md
└── optional-3xui       — установщик панели 3X‑UI (опционально)
```

- Скрипты не лезут в логику друг друга, а считывают все настройки из `.env` и из начала `easy-install.sh`.
- При необходимости их можно запускать по отдельности, например:
  ```bash
  ./vless.sh
  ```

## Смена SNI (ежемесячно)

Скрипт `rotate-sni.sh` меняет Reality‑`SNI` раз в месяц и пересоздаёт контейнер с новыми ключами:

```bash
chmod +x rotate-sni.sh
./rotate-sni.sh
```

Можно запускать вручную или по cron:

```bash
0 0 1 * * /root/easy-vless/rotate-sni.sh
```

## Конфигурация через .env

Все не секретные параметры хранятся в `.env` рядом с `easy-install.sh`.  
Создайте его из шаблона:

```bash
cp env.example .env
nano .env
```

Обязательно задайте:

- `CONTAINER_NAME="vless-reality"`  
- `IMAGE_NAME="ghcr.io/xtls/xray-core:latest"`  
- `VLESS_SNI="dl.google.com"`  
- `VLESS_INTERNAL_PORT=8443`  
- `VLESS_PUBLIC_PORT=1443` (или `2443` – не конфликтует с nginx:443)  
- `CONFIG_DIR="/opt/vless"`  
- `CONFIG_FILE="/opt/vless/config.json"`  
- `CREDS_FILE="/root/vless-credentials.txt"`  
- `VLESS_USE_NGINX=false` (если для этого VLESS nginx не нужен)  
- `VLESS_INSTALL_3X_UI=true` (или `false` – по желанию)

После этого запустите:

```bash
sudo ./easy-install.sh
```

Все вспомогательные скрипты будут читать одни и те же значения из `.env`.

## Запуск на VPS

1. Клонируйте репо:

   ```bash
   git clone https://github.com/yourname/easy-vless.git
   cd easy-vless
   ```

2. Дайте права и запустите установку от root:

   ```bash
   chmod +x easy-install.sh base.sh vless.sh rotate-sni.sh vpnmon.sh optional-3xui
   sudo ./easy-install.sh
   ```

   Скрипт:
   - Установит необходимые пакеты, Docker, UFW;
   - Сгенерирует Reality‑ключ, UUID и short ID;
   - Запустит контейнер `vless-reality` на `VLESS_PUBLIC_PORT` (например, `1443`);
   - При `VLESS_INSTALL_3X_UI=true` запустит установку 3X‑UI.

3. Учётные данные:

   ```bash
   /root/vless-credentials.txt
   ```

   Права на файл установлены в `600` для безопасности.

4. 3X‑UI (если выбрано):

   После установки панель доступна по адресу:

   ```text
   https://YOUR_SERVER_IP:20870
   ```

   Логин: `admin`, пароль показывается на экране.  
   Сразу поменяйте оба в `/etc/3x-ui/config.json`.

5. Мониторинг:

   ```bash
   vpnmon
   ```

   Открывает tmux‑сессию с:
   - `htop` (потребление ресурсов),
   - `vless` (логи `vless-reality`),
   - `ports` (список открытых портов).

## Результат работы

После успешного запуска скрипт выведет:

- IP сервера;
- `VLESS_PUBLIC_PORT` (например, `1443`);
- `VLESS_SNI` (например, `dl.google.com`);
- UUID;
- Reality‑public‑key;
- `VLESS_SHORT_ID`;
- клиентскую ссылку `vless://...`.

Пример ссылки:

```text
vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=dl.google.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp#easy-vless
```

Это единственная строка, которую нужно импортировать в клиенте (Android/iOS/Windows).

## Повторный запуск и обновление

Оркестратор `easy-install.sh` можно запускать многократно:

- Он останавливает и удаляет `vless-reality`, затем пересоздаёт контейнер с обновлёнными ключами и параметрами.
- Не трогает `nginx` для MTProto, уже работающие контейнеры других сервисов и tmux‑сессии `vpnmon`, если их установщики не запускаются повторно.

## Безопасность

- `vless-credentials.txt` содержит UUID, public key, short ID и полную ссылку.  
  Не коммитьте его в Git и не передавайте по публичным каналам.
- Для регулярной смены ключей используйте `rotate-sni.sh` раз в месяц.
