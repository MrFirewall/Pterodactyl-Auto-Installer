# 🚀 Pterodactyl Auto-Installer für Debian 13 (Bookworm/Trixie)

Willkommen! Dieses Skript installiert **Pterodactyl Panel & Wings** automatisch auf Debian 13 (Bookworm/Trixie), inkl.:

* Vollständig in Bash ohne `dialog`.
* Auto-Update direkt von GitHub.
* Farbige Status- & Fehlerausgaben.
* Externes Logfile (/var/log/pteroinstall.log).
* Validierung von Domain, Email, und Passwörtern.
* CLI-Flags für automatische Installation ohne interaktive Eingaben.

---

## ⚠️ Wichtige Hinweise

1. **Auf eigene Gefahr!** Das Skript verändert Systemdateien (MariaDB, Nginx, Docker, PHP).
2. **Nur frische Debian 13 Server!** Andere Versionen werden nicht unterstützt.
3. **Root-Rechte erforderlich.**

---

## 💻 Installation

### 🔹 Git & Bash All-in-One Beispiel

```bash
sudo bash -c 'git clone https://github.com/MrFirewall/Pterodactyl-Auto-Installer.git /tmp/pterodactyl-installer && \
cd /tmp/pterodactyl-installer && \
chmod +x install_pterodactyl.sh && \
./install_pterodactyl.sh \
  --all \
  --domain "<Ihre Domain, z.B. game-panel.domain.de>" \
  --db-pass "<Ihr Sicheres DB-Passwort>" \
  --email "<Ihre Admin-E-Mail>" \
  --user "<Ihr Admin-Benutzername>" \
  --admin-pass "<Ihr Sicheres Admin-Passwort>" \
  --first "Admin" \
  --last "User" \
  --tz "Europe/Berlin"'
```

### 🔹 Direkt via Curl

```bash
curl -sL https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/main/install_pterodactyl.sh | sudo bash
```

---

## ✨ CLI-Flags / Optionen

| Kategorie           | Flag           | Wert erforderlich? | Beschreibung                      |
| ------------------- | -------------- | ------------------ | --------------------------------- |
| Installationswahl   | --panel        | Nein               | Nur Panel installieren            |
| Installationswahl   | --wings        | Nein               | Nur Wings installieren            |
| Installationswahl   | --all          | Nein               | Panel + Wings installieren        |
| Panel-Konfiguration | --domain       | Ja                 | FQDN/Domain des Panels            |
| Panel-Konfiguration | --db-pass      | Ja                 | Passwort für Datenbank-Benutzer   |
| Panel-Konfiguration | --email        | Ja                 | E-Mail des ersten Admins          |
| Panel-Konfiguration | --user         | Ja                 | Benutzername des ersten Admins    |
| Panel-Konfiguration | --admin-pass   | Ja                 | Passwort des ersten Admins        |
| Panel-Konfiguration | --first        | Ja                 | Vorname Admin                     |
| Panel-Konfiguration | --last         | Ja                 | Nachname Admin                    |
| Panel-Konfiguration | --tz           | Ja                 | Zeitzone (z.B. Europe/Berlin)     |
| Allgemein           | --help oder -h | Nein               | Zeigt Hilfe/Usage                 |
| Allgemein           | --yes oder -y  | Nein               | Überspringt interaktive Eingaben  |
| Allgemein           | --no-update    | Nein               | Überspringt Installer Auto-Update |

---

## 🛠️ Nach der Installation

### 🔧 Wings aktivieren

1. Öffne Panel → **Knoten** → Node erstellen
2. Kopiere den Config-Block aus dem Panel
3. Erstelle/fülle die Datei:

```bash
nano /etc/pterodactyl/config.yml
```

4. Wings starten:

```bash
systemctl enable --now wings
```

### 🌐 Firewall Hinweis

Ports öffnen:

* 80/443 TCP (Panel)
* 8080 TCP (Wings <-> Panel)
* 2022 TCP (SFTP Wings)

---

## 📦 Installierte Komponenten

| Komponente | Version | Beschreibung          |
| ---------- | ------- | --------------------- |
| Debian 13  | aktuell | Basisbetriebssystem   |
| Nginx      | aktuell | Webserver für Panel   |
| MariaDB    | aktuell | Datenbank für Panel   |
| PHP 8.3    | 8.3     | Alle wichtigen Module |
| Redis      | aktuell | Cache & Queue         |
| Docker CE  | aktuell | Container Engine      |
| Wings      | aktuell | Pterodactyl Daemon    |

---

## 📋 Beispiel All-in-One CLI Installation

```bash
sudo ./install_pterodactyl.sh \
  --all \
  --domain "game-panel.ihredomain.de" \
  --db-pass "SicherPW#123" \
  --email "admin@ihredomain.de" \
  --user "meinadmin" \
  --admin-pass "SicherAdminPW456" \
  --first "Admin" \
  --last "User" \
  --tz "Europe/Berlin"
```

---

Viel Erfolg mit deinem Pterodactyl-Setup!
