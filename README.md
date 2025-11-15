# 🚀 Pterodactyl Auto-Installer für Debian 13 (Bookworm)

Willkommen! Dieses Skript installiert **Pterodactyl Panel & Wings** automatisch auf Debian 13, inkl.:

* Interaktive Auswahl (Panel, Wings oder Beides)
* Auto-Update direkt von GitHub
* Farbige Status- & Fehlerausgaben
* Externes Logfile (/var/log/ptero_installer.log)
* Eingabevalidierung (Domain, Email, Passwörter)

---

## ⚠️ Wichtige Hinweise

1. **Auf eigene Gefahr!** Das Skript ändert Systemdateien (MariaDB, Nginx, Docker, PHP).
2. **Nur frische Debian 13 Server!** Andere Versionen werden nicht unterstützt.
3. **Root-Rechte erforderlich.**

---

## 💻 Installation

Führe den Installer als Root aus:

```bash
curl -sL https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/main/install_pterodactyl.sh | sudo bash
```

---

## ✨ Optionen

Beim Start wähle:

* **Panel:** Web-Panel + Datenbank + Redis
* **Wings:** Docker-Host + Wings Daemon
* **Beides:** All-in-One
* **Abbrechen:** Skript beenden

Wenn Panel gewählt wird, wirst du nach folgenden Eingaben gefragt:

* Panel Domain (FQDN)
* MariaDB Passwort
* Admin E-Mail
* Admin Benutzername
* Admin Vorname/Nachname
* Admin Passwort (min. 8 Zeichen, Groß/Klein, Zahl)
* Zeitzone (z.B. Europe/Berlin)

---

## 🛠️ Manuelle Schritte nach Installation

### 🔧 Wings aktivieren

Wings wird installiert, aber **nicht gestartet**, solange die Konfigurationsdatei fehlt:

1. Öffne Panel → **Knoten** → Node erstellen.
2. Kopiere den Config-Block aus dem Panel.
3. Lege die Datei auf dem Wings-Host ab:

```bash
nano /etc/pterodactyl/config.yml
```

4. Starte Wings:

```bash
systemctl enable --now wings
```

### 🌐 Allocations

Definiere im Panel IPs und Ports für Gameserver. Ohne Zuweisungen können keine Server starten.

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

## 🎉 Hinweise

* Logs: `/var/log/ptero_installer.log`
* Auto-Update prüft beim Start automatisch auf neue Versionen.
* Farbige Ausgaben zeigen Status und Fehler an.

Viel Erfolg mit deinem Pterodactyl-Setup!
