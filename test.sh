#!/bin/bash

# Проверка на root
if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите как root"
  exit 1
fi

echo "[*] Обновление пакетов..."
apt update && apt upgrade -y

echo "[*] Установка Apache, MariaDB, PHP и зависимостей..."
apt install -y apache2 mariadb-server unzip wget \
  php php-mysql php-gd php-zip php-curl php-xml php-mbstring php-intl php-bcmath libapache2-mod-php php-cli

echo "[*] Настройка MariaDB..."
mysql -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER 'ncuser'@'localhost' IDENTIFIED BY 'supersecurepassword';"
mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'ncuser'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "[*] Загрузка и распаковка Nextcloud..."
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
mv nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud

echo "[*] Настройка Apache..."
cat <<EOF > /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud/
    ServerName localhost

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>
</VirtualHost>
EOF

a2ensite nextcloud.conf
a2enmod rewrite headers env dir mime
systemctl restart apache2 || service apache2 restart

echo "[*] Установка завершена. Перейдите в браузере на http://<ваш-IP>/ для завершения настройки Nextcloud."
