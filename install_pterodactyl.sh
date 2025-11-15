#!/bin/bash
# Pterodactyl Panel & Wings Installationsskript für Debian 13
# Automatisiert und interaktiv mit Komponenten-Auswahl

# Prüfen, ob das Skript als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "Dieses Skript muss als root ausgeführt werden."
  exit 1
fi

echo "======================================================="
echo "  Pterodactyl Installation (Panel & Wings) auf Debian 13"
echo "======================================================="

# --- 0. INSTALLATIONSWAHL ---
echo ""
echo "Was möchten Sie auf dieser VM installieren?"
echo "1) Pterodactyl Panel (Web, DB, Redis)"
echo "2) Pterodactyl Wings (Docker Host)"
echo "3) Beides (All-in-One)"
echo "4) Abbrechen"
read -r -p "Geben Sie die Zahl der gewünschten Option ein (1-4): " INSTALL_CHOICE

case "$INSTALL_CHOICE" in
  1|2|3) ;;
  *) echo "Installation abgebrochen."; exit 1 ;;
esac

INSTALL_PANEL=false
INSTALL_WINGS=false

if [[ "$INSTALL_CHOICE" == "1" || "$INSTALL_CHOICE" == "3" ]]; then
  INSTALL_PANEL=true
fi

if [[ "$INSTALL_CHOICE" == "2" || "$INSTALL_CHOICE" == "3" ]]; then
  INSTALL_WINGS=true
fi


# --- 1. INTERAKTIVE EINGABEN SAMMELN (NUR WENN PANEL BENÖTIGT) ---
if $INSTALL_PANEL; then
  echo ""
  read -r -p "Geben Sie den FQDN (Domain) für Ihr Panel ein (z.B. game-panel.ihredomain.de): " PANEL_DOMAIN
  read -r -p "Geben Sie das Passwort für den Pterodactyl-Datenbankbenutzer ein: " DB_PASSWORD

  echo ""
  echo "--- Admin-Benutzer-Details für das Panel ---"
  read -r -p "Admin E-Mail: " ADMIN_EMAIL
  read -r -p "Admin Benutzername: " ADMIN_USERNAME
  read -r -p "Admin Vorname: " ADMIN_FIRST
  read -r -p "Admin Nachname: " ADMIN_LAST
  read -r -p "Admin Passwort (mind. 8 Zeichen, Groß/Klein, Zahl): " ADMIN_PASS

  echo ""
  read -r -p "Geben Sie Ihre Zeitzone ein (z.B. Europe/Berlin): " APP_TIMEZONE
fi

echo "Starte Installation..."
sleep 2

# --- 2. ABHÄNGIGKEITEN INSTALLIEREN ---

install_dependencies() {
  echo "--- 2. System aktualisieren und Abhängigkeiten installieren ---"
  apt update -y
  apt upgrade -y
  apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release tar unzip git

  # PHP 8.3 und Redis Repositories hinzufügen
  echo "Füge PHP 8.3 und Redis Repositories hinzu..."
  curl -sSL https://packages.sury.org/php/README.txt | bash
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
  curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
  apt update

  # Installiere Basis-Pakete, abhängig von der Wahl
  COMMON_PACKAGES="redis-server"
  PANEL_PACKAGES="php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx"
  WINGS_PACKAGES="" # Docker wird separat über curl installiert

  if $INSTALL_PANEL; then
    echo "Installiere Panel-Abhängigkeiten..."
    apt install -y $COMMON_PACKAGES $PANEL_PACKAGES
    
    # Composer installieren (Nur für Panel)
    echo "Installiere Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  elif $INSTALL_WINGS; then
    echo "Installiere Basis-Abhängigkeiten für Wings..."
    apt install -y $COMMON_PACKAGES
  fi
}
install_dependencies

# --- 3. MARIADB-KONFIGURATION (NUR FÜR PANEL) ---

install_mariadb() {
  echo "--- 3. MariaDB-Datenbank und Benutzer einrichten ---"
  
  # Datenbank und Benutzer erstellen (Nicht-interaktiv)
  mysql -u root <<MYSQL_COMMANDS
  CREATE DATABASE panel;
  CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
  GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
  FLUSH PRIVILEGES;
MYSQL_COMMANDS
}

if $INSTALL_PANEL; then
  install_mariadb
fi

# --- 4. PTERODACTYL PANEL INSTALLIEREN (NUR FÜR PANEL) ---

install_panel() {
  echo "--- 4. Pterodactyl Panel-Dateien herunterladen und konfigurieren ---"
  
  # Dateien herunterladen
  mkdir -p /var/www/pterodactyl
  cd /var/www/pterodactyl
  curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
  tar -xzvf panel.tar.gz
  rm panel.tar.gz
  chmod -R 755 storage/* bootstrap/cache/

  # Panel-Umgebung vorbereiten
  cp .env.example .env
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
  php artisan key:generate --force

  # Panel-Umgebungskonfiguration (teilweise automatisiert)
  echo "Konfiguriere Panel-Umgebungsvariablen..."
  php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="$DB_PASSWORD"
  php artisan p:environment:mail --driver=mail # Standardwert setzen
  
  php artisan p:environment:setup --url="http://$PANEL_DOMAIN" --timezone="$APP_TIMEZONE" --cache=redis --session=redis --queue=redis

  # Datenbank migrieren
  echo "Migriere Datenbank und seede initiale Daten..."
  php artisan migrate --seed --force

  # Ersten Admin-Benutzer erstellen (automatisiert)
  echo "Erstelle den ersten Administrator-Benutzer: $ADMIN_USERNAME..."
  php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first="$ADMIN_FIRST" --name-last="$ADMIN_LAST" --password="$ADMIN_PASS" --admin=1

  # Berechtigungen festlegen
  echo "Setze Datei-Berechtigungen..."
  chown -R www-data:www-data /var/www/pterodactyl/*

  # CRONTAB UND WARTESCHLANGEN-WORKER
  echo "--- 5. Crontab und Queue Worker (pteroq) einrichten ---"
  (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

  # Warteschlangen-Worker Service erstellen
  cat <<EOF > /etc/systemd/system/pteroq.service
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable --now pteroq.service

  # NGINX-KONFIGURATION
  echo "--- 6. NGINX-Webserver konfigurieren (für Reverse Proxy) ---"
  rm -f /etc/nginx/sites-enabled/default

  cat <<EOF > /etc/nginx/sites-available/pterodactyl.conf
server {
    listen 80;
    server_name $PANEL_DOMAIN;
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  # NGINX-Konfiguration aktivieren und neu starten
  ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
  systemctl restart nginx
}

if $INSTALL_PANEL; then
  install_panel
fi

# --- 7. WINGS INSTALLATION (NUR FÜR WINGS ODER BEIDES) ---

install_wings() {
  echo "--- 7. Wings Daemon installieren ---"

  # Docker installieren
  echo "Installiere Docker CE..."
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
  systemctl enable --now docker

  # Wings-Executable herunterladen
  echo "Lade Wings-Executable herunter..."
  mkdir -p /etc/pterodactyl
  curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
  chmod u+x /usr/local/bin/wings

  # Wings Service Daemon erstellen
  echo "Erstelle Wings Systemd Service Datei..."
  cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  echo "Wings-Dateien und Dienst sind bereit."
}

if $INSTALL_WINGS; then
  install_wings
fi

# --- 8. ABSCHLUSS & MANUELLE SCHRITTE ---

echo "======================================================="
echo "✅ Installation der ausgewählten Komponenten abgeschlossen."
echo "======================================================="

if $INSTALL_PANEL; then
  echo "Panel-URL: http://$PANEL_DOMAIN"
fi

if $INSTALL_WINGS; then
  echo ""
  echo "!!! WICHTIGER ABSCHLIESSENDER MANUELLER SCHRITT FÜR WINGS !!!"
  echo "Wings ist installiert, aber NICHT gestartet, da die Konfigurationsdatei (/etc/pterodactyl/config.yml) fehlt."
  echo ""
  
  if $INSTALL_PANEL; then
    echo "1. Melden Sie sich in Ihrem Panel an: http://$PANEL_DOMAIN"
    echo "2. Gehen Sie zu 'Knoten' und erstellen Sie einen neuen Knoten (oder verwenden Sie den vorhandenen, falls es eine All-in-One-Installation ist)."
    echo "3. Auf der Registerkarte 'Konfiguration' des Knotens, kopieren Sie den Konfigurationsblock."
  else
    echo "1. Erstellen Sie einen Knoten in Ihrem Pterodactyl Panel (auf der separaten Panel-VM)."
    echo "2. Kopieren Sie den Konfigurationsblock von diesem Knoten."
  fi
  
  echo "4. Erstellen Sie die Datei /etc/pterodactyl/config.yml auf DIESER VM und fügen Sie den Inhalt dort ein."
  echo "5. Führen Sie DIESEN Befehl aus, um Wings zu starten:"
  echo "   systemctl enable --now wings"
  echo ""
  echo "Vergessen Sie nicht, Zuweisungen für den Knoten im Panel zu erstellen!"
fi

if ! $INSTALL_PANEL && ! $INSTALL_WINGS; then
  echo "Es wurden keine Komponenten zur Installation ausgewählt."
fi
