#!/bin/bash
# Скрипт для antiX / Debian-подобных без systemd
# Устанавливает и настраивает PHP OPcache и Redis с php-redis, перезапускает apache

set -e

echo "Обновляем список пакетов..."
apt-get update

echo "Устанавливаем Redis и PHP расширения..."
apt-get install -y redis-server php-redis php-cli php-common php-opcache apache2

echo "Включаем OPcache в php.ini..."

PHP_INI=$(php --ini | grep "Loaded Configuration" | awk '{print $4}')
if [ -z "$PHP_INI" ]; then
  echo "Не удалось найти php.ini"
  exit 1
fi

grep -q "opcache.enable=1" "$PHP_INI" || echo -e "\n[opcache]\nopcache.enable=1\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=10000\nopcache.revalidate_freq=1\nopcache.validate_timestamps=1" >> "$PHP_INI"

echo "Настраиваем Redis для автозапуска (без systemd)..."
# Для запуска redis вручную или через rc.d скрипт, т.к. systemd нет

if [ ! -f /etc/init.d/redis-server ]; then
  echo "Скрипт /etc/init.d/redis-server не найден. Пропускаем автозапуск."
else
  echo "Добавляем Redis в автозапуск через update-rc.d"
  update-rc.d redis-server defaults
fi

echo "Запускаем Redis..."
service redis-server start || /etc/init.d/redis-server start || redis-server &

echo "Перезапускаем Apache..."
service apache2 restart || /etc/init.d/apache2 restart

echo "Всё готово! Не забудь добавить в config.php Nextcloud настройки для Redis:"

echo "
'memcache.local' => '\\\\OC\\\\Memcache\\\\APCu',
'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis',
'redis' => [
    'host' => 'localhost',
    'port' => 6379,
    'timeout' => 0.0,
    'password' => '',
],
"

echo "Готово!"
