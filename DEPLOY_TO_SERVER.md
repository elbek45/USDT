# 🚀 Деплой на сервер 146.190.157.194

## Краткая информация

- **IP сервера**: 146.190.157.194
- **Пользователь**: root
- **Директория проекта**: /opt/usdx-wexel

## 🎯 Варианты деплоя

### Вариант 1: Автоматический деплой (рекомендуется)

Подключитесь к серверу и выполните один скрипт:

```bash
# 1. Подключитесь к серверу
ssh root@146.190.157.194

# 2. Создайте директорию и перейдите в неё
mkdir -p /opt/usdx-wexel
cd /opt/usdx-wexel

# 3. Загрузите код (выберите один из вариантов):

# Вариант A: Если код уже на локальной машине, используйте SCP
# На ЛОКАЛЬНОЙ машине выполните:
scp -r /path/to/USDT/* root@146.190.157.194:/opt/usdx-wexel/

# Вариант B: Если есть git репозиторий
git clone https://github.com/elbek45/USDT.git .

# Вариант C: Если код уже в директории, пропустите этот шаг

# 4. Запустите скрипт автоматической настройки
bash scripts/server-setup.sh

# 5. Отредактируйте .env.production (обязательно!)
nano .env.production
# Обновите:
# - SOLANA_WEXEL_PROGRAM_ID
# - SOLANA_LIQUIDITY_POOL_PROGRAM_ID
# - NEXT_PUBLIC_API_URL (укажите http://146.190.157.194:3001 или ваш домен)

# 6. Запустите деплой
./deploy.sh --env production --skip-tests
```

### Вариант 2: Деплой с локальной машины

Если вы хотите развернуть код с вашего компьютера на сервер:

```bash
# На вашей ЛОКАЛЬНОЙ машине:
cd /path/to/USDT

# Запустите скрипт удалённого деплоя
./scripts/remote-deploy.sh

# Скрипт автоматически:
# - Подключится к серверу
# - Загрузит код
# - Настроит окружение
# - Запустит деплой
```

### Вариант 3: Ручной деплой (полный контроль)

Для опытных пользователей, кто хочет полностью контролировать процесс:

```bash
# 1. Подключитесь к серверу
ssh root@146.190.157.194

# 2. Установите Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker

# 3. Установите утилиты
apt-get update
apt-get install -y git curl jq

# 4. Клонируйте проект
mkdir -p /opt/usdx-wexel
cd /opt/usdx-wexel
# Загрузите код (git clone или scp)

# 5. Настройте окружение
cp .env.staging .env.production
nano .env.production

# 6. Запустите деплой
chmod +x deploy.sh
./deploy.sh --env production
```

## 📋 Пошаговая инструкция (детально)

### Шаг 1: Подключение к серверу

```bash
ssh root@146.190.157.194
# Пароль: eLBEK451326a
```

### Шаг 2: Загрузка кода на сервер

**Способ A: С локальной машины через SCP**

```bash
# На вашей локальной машине:
cd /path/to/USDT
scp -r . root@146.190.157.194:/opt/usdx-wexel/
```

**Способ B: Через Git**

```bash
# На сервере:
cd /opt
git clone https://github.com/elbek45/USDT.git usdx-wexel
cd usdx-wexel
```

**Способ C: Создать tar архив**

```bash
# На локальной машине:
tar -czf usdx-wexel.tar.gz --exclude=node_modules --exclude=.git .
scp usdx-wexel.tar.gz root@146.190.157.194:/tmp/

# На сервере:
mkdir -p /opt/usdx-wexel
cd /opt/usdx-wexel
tar -xzf /tmp/usdx-wexel.tar.gz
```

### Шаг 3: Запуск автоматической настройки

```bash
cd /opt/usdx-wexel
bash scripts/server-setup.sh
```

Скрипт установит:
- ✅ Docker и Docker Compose
- ✅ Node.js 20 и pnpm
- ✅ Все необходимые утилиты (git, curl, jq, etc.)
- ✅ Firewall (UFW)
- ✅ Fail2Ban для защиты SSH
- ✅ Создаст .env.production с автоматически сгенерированными секретами

### Шаг 4: Настройка переменных окружения

```bash
nano /opt/usdx-wexel/.env.production
```

**Обязательно обновите:**

```bash
# Solana Configuration
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com
SOLANA_NETWORK=mainnet

# !!! ВАЖНО: Укажите ID развёрнутых контрактов
SOLANA_WEXEL_PROGRAM_ID=<ваш_program_id>
SOLANA_LIQUIDITY_POOL_PROGRAM_ID=<ваш_program_id>
SOLANA_COLLATERAL_PROGRAM_ID=<ваш_program_id>
SOLANA_ORACLE_PROGRAM_ID=<ваш_program_id>
SOLANA_MARKETPLACE_PROGRAM_ID=<ваш_program_id>

# Frontend Configuration
NEXT_PUBLIC_API_URL=http://146.190.157.194:3001
# Или если у вас есть домен:
# NEXT_PUBLIC_API_URL=https://api.your-domain.com

NEXT_PUBLIC_SOLANA_NETWORK=mainnet
NEXT_PUBLIC_ENVIRONMENT=production

# Tron (если используете)
TRON_GRID_API_KEY=<ваш_trongrid_api_key>
TRON_NETWORK=mainnet
```

**Опциональные настройки:**

```bash
# Мониторинг (если хотите)
SENTRY_DSN=<ваш_sentry_dsn>

# Email уведомления
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<ваш_email>
SMTP_PASSWORD=<пароль>

# Slack/Telegram уведомления
SLACK_WEBHOOK_URL=<ваш_webhook>
TELEGRAM_BOT_TOKEN=<токен>
TELEGRAM_CHAT_ID=<chat_id>
```

### Шаг 5: Деплой Solana контрактов (если ещё не развёрнуты)

```bash
cd /opt/usdx-wexel/contracts/solana/solana-contracts

# Установка Anchor (если нужно)
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
avm install latest
avm use latest

# Сборка
anchor build

# Деплой на mainnet
anchor deploy --provider.cluster mainnet

# Скопируйте Program ID из вывода
# Обновите его в .env.production
```

### Шаг 6: Запуск деплоя

```bash
cd /opt/usdx-wexel

# Полный деплой с тестами
./deploy.sh --env production --tag v1.0.0

# Или быстрый деплой без тестов (рекомендуется для первого раза)
./deploy.sh --env production --skip-tests

# Или совсем быстрый (без тестов и бэкапа)
./deploy.sh --env production --skip-tests --skip-backup
```

### Шаг 7: Проверка работы

```bash
# Проверка статуса контейнеров
docker ps

# Проверка здоровья сервисов
curl http://localhost:3001/health
curl http://localhost:3000/

# Или используйте helper script
./check-status.sh

# Просмотр логов
./view-logs.sh indexer
./view-logs.sh webapp
```

## 🔧 Управление сервисами

### Просмотр статуса

```bash
# Все контейнеры
docker ps

# Статус через helper script
/opt/usdx-wexel/check-status.sh
```

### Просмотр логов

```bash
cd /opt/usdx-wexel

# Backend
./view-logs.sh indexer
# или
docker logs -f usdx-wexel-indexer

# Frontend
./view-logs.sh webapp
# или
docker logs -f usdx-wexel-webapp
```

### Перезапуск сервисов

```bash
# Перезапуск конкретного сервиса
docker restart usdx-wexel-indexer
docker restart usdx-wexel-webapp

# Перезапуск всех сервисов
cd /opt/usdx-wexel/infra/production
docker compose restart
```

### Остановка/Запуск

```bash
cd /opt/usdx-wexel/infra/production

# Остановить все
docker compose down

# Запустить все
docker compose up -d

# Запустить с пересборкой
docker compose up -d --build --force-recreate
```

### Обновление приложения

```bash
cd /opt/usdx-wexel

# Получить последние изменения
git pull origin main

# Быстрый деплой
./quick-deploy.sh

# Или полный деплой с новой версией
./deploy.sh --env production --tag v1.1.0
```

## 🌐 Настройка домена (опционально)

Если у вас есть доменное имя:

### 1. Настройка DNS

Добавьте A-записи в DNS:

```
A    @                146.190.157.194
A    www              146.190.157.194
A    api              146.190.157.194
```

### 2. Установка Nginx

```bash
apt-get install -y nginx

# Создайте конфигурацию
nano /etc/nginx/sites-available/usdx-wexel
```

Вставьте конфигурацию:

```nginx
# Frontend
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Backend API
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Активируйте:

```bash
ln -s /etc/nginx/sites-available/usdx-wexel /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

### 3. SSL сертификат

```bash
# Установка certbot
apt-get install -y certbot python3-certbot-nginx

# Получение сертификата
certbot --nginx -d your-domain.com -d www.your-domain.com -d api.your-domain.com

# Авто-обновление
certbot renew --dry-run
```

Обновите `.env.production`:

```bash
NEXT_PUBLIC_API_URL=https://api.your-domain.com
```

Перезапустите сервисы:

```bash
cd /opt/usdx-wexel
./deploy.sh --env production --skip-tests --skip-migrations
```

## 🔍 Мониторинг и диагностика

### Проверка здоровья

```bash
# Health endpoints
curl http://146.190.157.194:3001/health
curl http://146.190.157.194:3000/

# Статус базы данных
docker exec usdx-wexel-postgres pg_isready -U usdx_user

# Статус Redis
docker exec usdx-wexel-redis redis-cli ping
```

### Использование ресурсов

```bash
# Ресурсы контейнеров
docker stats

# Диск
df -h

# Память
free -h

# CPU
htop
```

### Логи деплоя

```bash
# Последний лог деплоя
ls -lt /opt/usdx-wexel/deploy_*.log | head -1
tail -f /opt/usdx-wexel/deploy_*.log
```

## 🛠️ Решение проблем

### Контейнер не запускается

```bash
# Смотрим логи
docker logs usdx-wexel-indexer

# Проверяем конфигурацию
cat /opt/usdx-wexel/.env.production

# Пересоздаём контейнер
cd /opt/usdx-wexel/infra/production
docker compose down
docker compose up -d --force-recreate
```

### База данных недоступна

```bash
# Проверка статуса
docker ps -f name=postgres

# Логи БД
docker logs usdx-wexel-postgres

# Перезапуск
docker restart usdx-wexel-postgres
```

### Порт занят

```bash
# Проверить что использует порт
lsof -i :3000
lsof -i :3001

# Убить процесс
kill -9 <PID>
```

### Нехватка места

```bash
# Очистка Docker
docker system prune -a
docker volume prune

# Удаление старых логов
find /opt/usdx-wexel -name "*.log" -mtime +7 -delete
```

## 📊 Полезные команды

```bash
# Вход в контейнер
docker exec -it usdx-wexel-indexer sh

# Вход в БД
docker exec -it usdx-wexel-postgres psql -U usdx_user usdx_production

# Проверка переменных окружения
docker exec usdx-wexel-indexer env

# Бэкап БД
docker exec usdx-wexel-postgres pg_dump -U usdx_user usdx_production > backup.sql

# Восстановление БД
cat backup.sql | docker exec -i usdx-wexel-postgres psql -U usdx_user usdx_production
```

## ✅ Чек-лист после деплоя

- [ ] Сервер доступен по SSH
- [ ] Docker установлен и работает
- [ ] Код загружен в /opt/usdx-wexel
- [ ] .env.production настроен правильно
- [ ] Solana контракты развёрнуты
- [ ] Program IDs указаны в .env.production
- [ ] Деплой завершился успешно
- [ ] Все контейнеры запущены (docker ps)
- [ ] Frontend доступен: http://146.190.157.194:3000
- [ ] Backend доступен: http://146.190.157.194:3001
- [ ] Health checks проходят
- [ ] Firewall настроен
- [ ] Логи не показывают ошибок

## 📞 Быстрая помощь

**Адреса сервисов:**
- Frontend: http://146.190.157.194:3000
- Backend API: http://146.190.157.194:3001
- Swagger API Docs: http://146.190.157.194:3001/api

**Основные команды:**
```bash
cd /opt/usdx-wexel
./check-status.sh          # Проверка статуса
./view-logs.sh indexer     # Логи backend
./view-logs.sh webapp      # Логи frontend
./quick-deploy.sh          # Быстрый деплой
```

**Документация:**
- [Полная инструкция](SERVER_DEPLOYMENT.md)
- [Руководство по деплою](DEPLOYMENT_GUIDE.md)
- [Быстрый старт](QUICK_DEPLOY.md)

---

**Сервер**: 146.190.157.194
**Версия**: 1.0.0
**Дата**: 2025-10-29
