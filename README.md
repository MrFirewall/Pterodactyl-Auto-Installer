# 🚀 Pterodactyl Auto-Installer für **Debian 13 (Bookworm)**

Willkommen! Dieses Skript hilft dir dabei, **Pterodactyl schnell, sauber und vollautomatisch** auf Debian 13 zu installieren. Egal ob getrenntes Setup (Panel + Wings) oder alles auf einer Maschine – hier bist du richtig.

---

## ⚠️ Wichtige Hinweise (Bitte zuerst lesen!)

1. **Auf eigene Gefahr!**
   Das Skript greift tief ins System ein (MariaDB, Docker, Nginx usw.). Nutze es mit Bedacht.

2. **Nur auf frischen Servern!**
   Bereits konfigurierte Systeme können zu Konflikten führen.

3. **Nur Debian 13 (Bookworm)!**
   Andere Versionen werden *nicht* unterstützt.

4. **Root- oder Sudo-Rechte nötig!**

---

## 💻 Installation

Führe den folgenden Befehl als normaler Benutzer mit `sudo`-Rechten aus:

```bash
curl -sL https://raw.githubusercontent.com/MrFirewall/Pterodactyl-Auto-Installer/9a27d90d326206d6b532874a7cb47c74a7918d15/install_pterodactyl.sh | sudo bash
```

Das Skript lädt die Datei herunter und startet automatisch die Installation.

---

## ✨ Installationsoptionen

Beim Start fragt dich das Skript, was eingerichtet werden soll:

### **1️⃣ Pterodactyl Panel installieren**

* Installiert: **Nginx**, **MariaDB**, **PHP 8.3**, **Redis**
* Du benötigst eine Domain (FQDN) für den Panel-Zugriff.
* Das Skript richtet automatisch ein:

  * Datenbank + Benutzer
  * `.env` Datei
  * Admin-Account

### **2️⃣ Pterodactyl Wings installieren**

* Installiert: **Docker CE**, **Wings Daemon**
* Perfekt zur Skalierung: beliebig viele Wings-Server möglich

### **3️⃣ Beides auf einem Server installieren**

* Panel + Wings auf derselben Maschine
* Praktisch für kleine Projekte oder Tests

---

## 🛠️ Manuelle Schritte nach der Installation

### 🔧 Wings mit dem Panel verbinden (Option 2 oder 3)

Wings wird installiert, aber **nicht direkt gestartet**, da es zuerst eine gültige Konfiguration braucht.

So richtest du Wings ein:

1. Öffne dein Panel im Browser.
2. Gehe zu **Knoten** → wähle deinen Node oder erstelle einen neuen.
3. Unter **Konfiguration** findest du den Codeblock für die Datei `config.yml`.
4. Erstelle die Datei auf deinem Wings-Server:

```bash
nano /etc/pterodactyl/config.yml
```

5. Füge den Konfigurationsblock ein und speichere.

6. Prüfe, ob diese Ports offen sind:

   * **8080/TCP** – Panel ↔ Wings Kommunikation
   * **2022/TCP** – SFTP für Benutzer

7. Starte Wings:

```bash
systemctl enable --now wings
```

### 🌐 Zuweisungen (Allocations)

Im Panel musst du noch IPs und Ports definieren, die der Server später nutzen darf.
Ohne diese Zuweisungen können keine Gameserver gestartet werden.

---

## 📦 Was wird alles installiert?

| Komponente         | Version              | Beschreibung                                       |
| ------------------ | -------------------- | -------------------------------------------------- |
| **Betriebssystem** | Debian 13 (Bookworm) | Stabile Basis für moderne Software                 |
| **Nginx**          | aktuell              | Webserver für das Panel                            |
| **MariaDB**        | aktuell              | Datenbank für Panel-Daten                          |
| **PHP**            | 8.3                  | Benötigte PHP-Version inkl. aller wichtigen Module |
| **Redis**          | aktuell              | Cache + Queue-Verarbeitung fürs Panel              |
| **Docker CE**      | aktuell              | Container-Engine für Gameserver                    |
| **Wings**          | aktuell              | Pterodactyl Daemon zur Server-Verwaltung           |

---

## 🎉 Viel Spaß mit deinem Pterodactyl-Setup!

Wenn du Feedback hast oder Fehler findest, melde dich gern im GitHub-Repository.
