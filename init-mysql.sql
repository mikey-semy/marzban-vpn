-- ===========================================
-- СПРАВОЧНЫЙ ФАЙЛ - НЕ ИСПОЛЬЗУЕТСЯ АВТОМАТИЧЕСКИ
-- ===========================================
-- Этот файл показывает структуру БД, которая создается автоматически
-- через переменные окружения в docker-compose.marzban.yml
--
-- Если нужно создать БД вручную, выполните эти команды:
-- mysql -u root -p < init-mysql.sql

-- Создание базы данных
CREATE DATABASE IF NOT EXISTS `marzban-db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Создание пользователя (замените password на реальный пароль)
-- CREATE USER IF NOT EXISTS 'marzban'@'%' IDENTIFIED BY 'your_secure_password';

-- Предоставление прав
-- GRANT ALL PRIVILEGES ON `marzban-db`.* TO 'marzban'@'%';

-- Применение изменений
-- FLUSH PRIVILEGES;

-- ===========================================
-- ПРИМЕЧАНИЕ
-- ===========================================
-- При использовании docker-compose.marzban.yml база данных и пользователь
-- создаются автоматически через переменные окружения:
--   MYSQL_DATABASE=marzban-db
--   MYSQL_USER=marzban
--   MYSQL_PASSWORD=${MYSQL_PASSWORD}
--   MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
