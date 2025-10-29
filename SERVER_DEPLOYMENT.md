# 🚀 Деплой на сервер 146.190.157.194

Пошаговая инструкция для развертывания проекта USDX/Wexel на вашем сервере.

## Информация о сервере

- **IP**: 146.190.157.194
- **Пользователь**: root
- **ОС**: Ubuntu 20.04/22.04 (предполагается)

## Быстрый старт (автоматическая установка)

### Шаг 1: Подключитесь к серверу

```bash
ssh root@146.190.157.194
```

### Шаг 2: Скачайте и запустите скрипт установки

```bash
# Создайте директорию проекта
mkdir -p /opt/usdx-wexel
cd /opt/usdx-wexel

# Загрузите код проекта (один из вариантов):

# Вариант A: Если у вас есть git репозиторий
git clone https://github.com/elbek45/USDT.git .

# Вариант B: Загрузите код через SCP с вашей локальной машины
# На вашем локальном компьютере выполните:
# scp -r /path/to/USDT root@146.190.157.194:/opt/usdx-wexel/

# Запустите скрипт настройки сервера
cd /opt/usdx-wexel
bash scripts/server-setup.sh
```

Скрипт автоматически установит:
- Docker и Docker Compose
- Node.js и pnpm
- Все необходимые утилиты
- Настроит firewall
- Создаст конфигурационные файлы

### Шаг 3: Настройте переменные окружения

После установки отредактируйте файл `.env.production`:

```bash
cd /opt/usdx-wexel
nano .env.production
```

**Обязательно обновите следующие параметры:**

```bash
# Database (уже сгенерированы, но можете изменить)
POSTGRES_PASSWORD=<автоматически_сгенерирован>
DATABASE_URL=postgresql://usdx_user:<пароль>@postgres:5432/usdx_production?schema=public

# Redis (уже сгенерирован)
REDIS_PASSWORD=<автоматически_сгенерирован>
REDIS_URL=redis://:<пароль>@redis:6379

# JWT Secrets (уже сгенерированы)
JWT_SECRET=<автоматически_сгенерирован>
ADMIN_JWT_SECRET=<автоматически_сгенерирован>

# Solana Configuration
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com  # или devnet для тестов
SOLANA_NETWORK=mainnet  # или devnet

# ВАЖНО: Укажите адреса развернутых смарт-контрактов
SOLANA_WEXEL_PROGRAM_ID=<ваш_program_id>
SOLANA_LIQUIDITY_POOL_PROGRAM_ID=<ваш_program_id>
SOLANA_COLLATERAL_PROGRAM_ID=<ваш_program_id>

# Tron Configuration (если используете)
TRON_GRID_API_KEY=<ваш_api_key>
TRON_NETWORK=mainnet  # или nile для тестов

# Frontend URLs
NEXT_PUBLIC_API_URL=http://146.190.157.194:3001
# или используйте домен: https://api.your-domain.com

# Admin Panel
ADMIN_DEFAULT_EMAIL=admin@your-domain.com
ADMIN_DEFAULT_PASSWORD=<смените_при_первом_входе>
```

### Шаг 4: Запустите деплой

```bash
cd /opt/usdx-wexel

# Полный деплой
./deploy.sh --env production --tag v1.0.0

# Или быстрый деплой без тестов
./deploy.sh --env production --skip-tests
```

### Шаг 5: Проверьте работу сервисов

```bash
# Проверка статуса
./check-status.sh

# Или вручную
docker ps

# Проверка здоровья
curl http://146.190.157.194:3001/health
curl http://146.190.157.194:3000/

# Просмотр логов
./view-logs.sh indexer  # Backend
./view-logs.sh webapp   # Frontend
```

## Ручная установка (детальная)

Если автоматический скрипт не подходит, выполните установку вручную:

### 1. Установка Docker

```bash
# Обновление системы
apt-get update && apt-get upgrade -y

# Установка зависимостей
apt-get install -y ca-certificates curl gnupg lsb-release

# Добавление Docker GPG ключа
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавление репозитория
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Запуск Docker
systemctl start docker
systemctl enable docker
```

### 2. Установка утилит

```bash
apt-get install -y git curl wget jq htop vim nano net-tools ufw
```

### 3. Настройка Firewall

```bash
# Базовая настройка
ufw default deny incoming
ufw default allow outgoing

# Разрешение портов
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # WebApp
ufw allow 3001/tcp  # API

# Включение
ufw --force enable
```

### 4. Клонирование проекта

```bash
cd /opt
git clone https://github.com/elbek45/USDT.git usdx-wexel
cd usdx-wexel
```

### 5. Настройка окружения

```bash
# Копирование примера
cp .env.staging .env.production

# Генерация секретов
JWT_SECRET=$(openssl rand -base64 64)
ADMIN_JWT_SECRET=$(openssl rand -base64 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)

# Редактирование
nano .env.production
```

### 6. Запуск деплоя

```bash
chmod +x deploy.sh
./deploy.sh --env production
```

## Управление сервисами

### Просмотр статуса

```bash
# Все контейнеры
docker ps

# Статус конкретного сервиса
docker ps -f name=usdx-wexel-indexer
docker ps -f name=usdx-wexel-webapp
```

### Просмотр логов

```bash
# Backend логи
docker logs -f usdx-wexel-indexer

# Frontend логи
docker logs -f usdx-wexel-webapp

# Последние 100 строк
docker logs --tail 100 usdx-wexel-indexer

# Логи базы данных
docker logs -f usdx-wexel-postgres
```

### Перезапуск сервисов

```bash
# Перезапуск всех сервисов
cd /opt/usdx-wexel/infra/production
docker compose restart

# Перезапуск конкретного сервиса
docker restart usdx-wexel-indexer
docker restart usdx-wexel-webapp
```

### Остановка/Запуск

```bash
cd /opt/usdx-wexel/infra/production

# Остановка
docker compose down

# Запуск
docker compose up -d

# Запуск с пересборкой
docker compose up -d --build
```

## Настройка домена (опционально)

Если у вас есть доменное имя:

### 1. Установка Nginx

```bash
apt-get install -y nginx
```

### 2. Настройка Nginx

```bash
nano /etc/nginx/sites-available/usdx-wexel
```

Добавьте конфигурацию:

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
    }
}

# Backend API
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### 3. Активация конфигурации

```bash
ln -s /etc/nginx/sites-available/usdx-wexel /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

### 4. Установка SSL сертификата

```bash
# Установка certbot
apt-get install -y certbot python3-certbot-nginx

# Получение сертификата
certbot --nginx -d your-domain.com -d www.your-domain.com -d api.your-domain.com

# Авто-обновление
certbot renew --dry-run
```

## Мониторинг и обслуживание

### Проверка здоровья

```bash
# Health checks
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
top
```

### Бэкапы

```bash
# Бэкап базы данных
docker exec usdx-wexel-postgres pg_dump -U usdx_user usdx_production > backup_$(date +%Y%m%d).sql

# Бэкап с сжатием
docker exec usdx-wexel-postgres pg_dump -U usdx_user usdx_production | gzip > backup_$(date +%Y%m%d).sql.gz

# Восстановление
gunzip < backup_20241029.sql.gz | docker exec -i usdx-wexel-postgres psql -U usdx_user usdx_production
```

### Обновление приложения

```bash
cd /opt/usdx-wexel

# Получение последних изменений
git pull origin main

# Быстрый деплой
./quick-deploy.sh

# Или полный деплой
./deploy.sh --env production --tag v1.1.0
```

## Решение проблем

### Проблема: Контейнер не запускается

```bash
# Проверить логи
docker logs usdx-wexel-indexer

# Проверить конфигурацию
docker inspect usdx-wexel-indexer

# Пересоздать контейнер
cd infra/production
docker compose down
docker compose up -d --force-recreate
```

### Проблема: База данных недоступна

```bash
# Проверить статус
docker ps -f name=postgres

# Проверить подключение
docker exec usdx-wexel-postgres pg_isready

# Перезапустить БД
docker restart usdx-wexel-postgres

# Проверить DATABASE_URL в .env.production
```

### Проблема: Нехватка памяти

```bash
# Очистка Docker кеша
docker system prune -a

# Удаление неиспользуемых образов
docker image prune -a

# Удаление остановленных контейнеров
docker container prune
```

### Проблема: Порт уже занят

```bash
# Проверить, что использует порт
lsof -i :3000
lsof -i :3001

# Убить процесс (если нужно)
kill -9 <PID>
```

## Полезные команды

```bash
# Вход в контейнер
docker exec -it usdx-wexel-indexer sh
docker exec -it usdx-wexel-webapp sh

# Вход в базу данных
docker exec -it usdx-wexel-postgres psql -U usdx_user usdx_production

# Вход в Redis
docker exec -it usdx-wexel-redis redis-cli

# Просмотр переменных окружения
docker exec usdx-wexel-indexer env

# Копирование файлов из контейнера
docker cp usdx-wexel-indexer:/app/logs/. ./logs/

# Копирование файлов в контейнер
docker cp ./config.json usdx-wexel-indexer:/app/
```

## Чек-лист после деплоя

- [ ] Все контейнеры запущены (`docker ps`)
- [ ] Health checks проходят
- [ ] Frontend доступен по http://146.190.157.194:3000
- [ ] Backend API доступен по http://146.190.157.194:3001
- [ ] База данных работает
- [ ] Redis работает
- [ ] Логи не показывают критических ошибок
- [ ] Firewall настроен
- [ ] SSL сертификаты установлены (для production)
- [ ] Настроены автоматические бэкапы
- [ ] Мониторинг работает

## Контакты и поддержка

- **IP сервера**: 146.190.157.194
- **Директория проекта**: /opt/usdx-wexel
- **Логи деплоя**: /opt/usdx-wexel/deploy_*.log

## Дополнительные ресурсы

- [Полное руководство по деплою](DEPLOYMENT_GUIDE.md)
- [Быстрый старт](QUICK_DEPLOY.md)
- [Статус проекта](PROJECT_STATUS.md)

---

**Версия**: 1.0.0
**Дата**: 2025-10-29
**Сервер**: 146.190.157.194
