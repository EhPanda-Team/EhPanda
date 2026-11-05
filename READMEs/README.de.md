<h1 align="center">EhPanda</h1>

<h4 align="center">Eine inoffizielle E-Hentai-App für iOS</h4>

<p align="center">
<img src="https://user-images.githubusercontent.com/31207151/105609404-0acbff00-5de4-11eb-9e88-f3c6e0ba9d44.png" width="400"></img>
</p>

<p align="center">
  <a href="/README.md">English</a>・
  <a href="/READMEs/README.de.md">Deutsch</a>・
  <a href="/READMEs/README.ko.md">한국어</a>・
  <a href="/READMEs/README.jpn.md">日本語</a>・
  <a href="/READMEs/README.cht.md">繁體中文</a>・
  <a href="/READMEs/README.chs.md">简体中文</a>
</p>

## Installation
1. Lade die IPA-Datei von [Releases](https://github.com/EhPanda-Team/EhPanda/releases) herunter.
2. Installiere sie mit einem Tool wie [AltStore](https://altstore.io) auf deinem Gerät.

<sub>Erfordert iOS / iPadOS 27.0 oder neuer.</sub>

## Community
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## Haftungsausschluss
Alle Inhalte dieser App stammen von E-Hentai und wurden von dessen Nutzern hochgeladen.

**Der Zugriff auf E-Hentai-Inhalte erfolgt auf eigene Gefahr.**

## Analyse
EhPanda sendet anonyme Analysedaten an [TelemetryDeck](https://telemetrydeck.com), damit die Entwickler erkennen können, wie viele Menschen die App nutzen und welche Funktionen wichtig sind. **Wie viel geteilt wird, wählst du beim ersten Öffnen der App, und du kannst deine Wahl jederzeit unter Einstellungen → Allgemein → Analyse ändern. Bevor du gewählt hast, wird nichts gesendet.** Es gibt drei Stufen:

- **Minimal**: Sendet nur, dass EhPanda installiert ist, und woher du die App installiert hast.
- **Basis**: Alles aus „Minimal“, dazu wie oft die App genutzt wird, welche Bildschirme und Funktionen du nutzt, technische Angaben wie Gerätemodell und App-Version und welche Arten von Fehlern auftreten.
- **Vollständig**: Alles aus „Basis“, dazu deine Lese- und Downloadaktivität und deine wichtigsten Einstellungen.

Auf keiner Stufe enthalten die Daten Galerie-Bezeichner, Token oder Titel, Links zu Galerien oder Seiten, den Text von Suchbegriffen, Tag-Werte, Benutzernamen, Cookies oder andere Zugangsdaten sowie Dateipfade.

Bei „Minimal“ sendet EhPanda ein einziges Installationssignal, einmal pro Installation. Es enthält, woher du die App installiert hast (etwa aus dem App Store, über TestFlight, aus einem alternativen App-Marktplatz oder aus dem Web), und eine zufällige Kennung, die für diese Installation erzeugt wird, aber nichts über dein Gerät. Das TelemetryDeck-SDK wird nie gestartet.

Bei „Basis“ sendet EhPanda dasselbe Installationssignal, startet das TelemetryDeck-SDK und sendet zusätzlich:
- wie oft die App genutzt wird: die eigenen Sitzungssignale und Kennzahlen des SDK, etwa das Datum der ersten Nutzung, die Anzahl der Sitzungen, an wie vielen einzelnen Tagen du die App geöffnet hast und wie lange Sitzungen dauern;
- welche Bildschirme und Funktionen du nutzt: die Tabs und Startseiten-Bereiche, die du öffnest, die Filter- und Schnellsuche-Bereiche, gespeicherte Suchen, Tipps auf Tags (der Namensraum des Tags, nie sein Wert) und Suchanfragen als Merkmale (Anzahl der Wörter, ob Tag-Syntax verwendet wurde, Länge des Suchbegriffs und ungefähr wie viele Treffer zurückkamen) statt als Text;
- welche Arten von Fehlern auftreten, einschließlich fehlgeschlagener Anmeldungen und Cloudflare-Prüfungen;
- die technischen Angaben, die das SDK jedem Ereignis von sich aus hinzufügt: Gerätemodell und Architektur, Bildschirmgröße, Skalierung und Ausrichtung, die Version des Betriebssystems, App-Version und Build-Nummer, ob es sich um einen Debug- oder Simulator-Build handelt, deine Sprache, Region, Textlaufrichtung und Zeitzone, das Datum und die Uhrzeit, zu der das Ereignis gesendet wurde, sowie deine Darstellungs- und Bedienungshilfen-Einstellungen (heller oder dunkler Modus, Textgröße, fetter Text, Bewegung reduzieren, Transparenz reduzieren, Farben umkehren, Kontrast erhöhen und ohne Farben differenzieren).

Bei „Vollständig“ kommen die Galerien hinzu, die du öffnest (als Kategorie und Anzahl der Tags je Namensraum, nie die Galerie selbst), Lesesitzungen als grobe Spannen von Seitenzahl und Dauer, Download-Ergebnisse wie abgeschlossen oder fehlgeschlagen sowie bei jedem Ereignis die aktuellen Werte von fünf App-Einstellungen: Galerie-Website, Anmeldestatus, Leserichtung, Doppelseitenmodus und Tag-Übersetzung.

Bei „Basis“ und „Vollständig“ enthalten Ereignisse die in TelemetryDeck eingebaute anonyme Installationskennung, die vor dem Senden auf dem Gerät gehasht wird. Die Kennung ist nicht mit dir verknüpft und wird zurückgesetzt, sobald iOS die Anbieterkennung des Geräts neu erzeugt, was geschieht, wenn alle Apps desselben Entwicklers entfernt werden. TelemetryDeck speichert keine IP-Adressen. Wie die Daten verarbeitet werden, steht in der [Datenschutzerklärung von TelemetryDeck](https://telemetrydeck.com/privacy).

Offizielle Releases werden mit Analyse-Zugangsdaten gebaut, die der Release-Workflow aus den Repository-Secrets bezieht, und senden daher, was die gewählte Stufe erlaubt. Ein Build ohne diese Zugangsdaten sendet überhaupt nichts, unabhängig von der gewählten Stufe: Bei selbst aus dem Quellcode erstellten Builds und bei Forks ist die Analyse deaktiviert, weil die Zugangsdaten fehlen.
