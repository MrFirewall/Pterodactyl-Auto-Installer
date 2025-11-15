# 🚀 Pterodactyl Auto-Installer für **Debian 13 (Bookworm)**

Willkommen! Dieses Skript installiert **Pterodactyl schnell, sauber, interaktiv und vollautomatisch** auf Debian 13 – inklusive **Auto-Update, Logfile, Eingabevalidierung und farbigen Ausgaben**.

Es unterstützt:

* 🖥️ **Panel-Installation** (PHP 8.3, Redis, MariaDB, Nginx)
* 🐦 **Wings-Installation** (Docker CE + Wings-Daemon)
* 🔄 **All-in-One-Setup**
* ⚙️ Interaktive Menüs
* 🧪 Validierte Eingaben (Domain, E-Mail, Passwörter)
* 📄 Logfile unter: `/var/log/ptero_installer.log`
* 🆕 Automatisches Self-Update

---

## ⚠️ Wichtige Hinweise

1. **Auf eigene Gefahr!**
   Das Skript greift tief ins System ein.

2. **Nur frische Systeme verwenden.**

3. **Nur Debian 13 (Bookworm).**

4. **Root- oder Sudo-Rechte nötig.**

---

## 💻 Installation

```bash
curl -sL https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/main/install_pterodactyl.sh | sudo bash
```

Das Skript startet automatisch und prüft auf Updates.

---

## ✨ Installationsoptionen

### **1️⃣ Panel installieren**

* Nginx, PHP 8.3, MariaDB, Redis
* Automatische Einrichtung: Datenbank, Admin, .env, Queue-Worker

### **2️⃣ Wings installieren**

* Docker CE + Wings Daemon
* Nicht direkt starten – config.yml nötig

### **3️⃣ Beides (All-in-One)**

* Panel + Wings auf einer VM

---

## 🛠️ Nach der Installation

### 🔧 Wings verbinden

1. Panel → Knoten → Node erstellen
2. Konfigurationsblock kopieren
3. `/etc/pterodactyl/config.yml` erstellen
4. Ports öffnen: 8080/TCP, 2022/TCP
5. Wings starten: `systemctl enable --now wings`

### 🌐 Zuweisungen (Allocations)

* IPs und Ports für Gameserver im Panel definieren

---

## 📦 Installierte Komponenten

| Komponente | Version | Beschreibung          |
| ---------- | ------- | --------------------- |
| Debian 13  | aktuell | Stabile Basis         |
| Nginx      | aktuell | Webserver Panel       |
| MariaDB    | aktuell | Datenbank Panel       |
| PHP        | 8.3     | PHP inkl. Module      |
| Redis      | aktuell | Cache & Queue         |
| Docker CE  | aktuell | Container Engine      |
| Wings      | aktuell | Daemon zur Verwaltung |

---

## 🔄 Auto-Update

* Prüft Remote-Version aus GitHub
* Herunterladen und self-replace bei neuer Version
* Validierung der Version, Dateigröße, Inhalt
* Logfile: `/var/log/ptero_installer.log`

---

## 🎉 Viel Erfolg!
