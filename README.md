# discourse-steam-login

Anmeldung und Registrierung in Discourse mit einem **Steam-Konto**.

- Button „Mit Steam anmelden“ im Anmelde- und Registrierungsdialog
- Steam-Name und Profilbild werden übernommen (mit Steam Web API Key)
- Bestehende Konten können Steam unter *Einstellungen → Konto → Verknüpfte Konten*
  nachträglich verbinden und wieder trennen
- Kein zusätzliches Gem nötig: Steam-OpenID wird direkt im Plugin umgesetzt, jede
  Anmeldung wird bei Steam selbst gegengeprüft

## Installation (Docker)

In `containers/app.yml` unter `hooks -> after_code -> cmd`:

    - git clone https://github.com/0eiki0/steamauth.git

Danach `./launcher rebuild app`.

## Einrichtung

1. **Steam Web API Key** erstellen: https://steamcommunity.com/dev/apikey
   (als Domain eure Forum-Domain eintragen). Der Key ist optional – ohne ihn klappt die
   Anmeldung, aber Name und Profilbild werden nicht übernommen.
2. Admin → Plugins → **discourse-steam-login**:
   - `steam login enabled` aktivieren
   - `steam web api key` eintragen
   - `steam login import avatar`: Steam-Profilbild bei der Registrierung übernehmen

## Gut zu wissen

- **E-Mail-Adresse:** Steam gibt keine E-Mail-Adresse heraus. Neue Nutzer tragen sie bei der
  ersten Anmeldung selbst ein und bestätigen sie wie gewohnt.
- **Profilbild:** Das Steam-Bild wird nur übernommen, wenn noch kein eigenes Bild gesetzt ist.
  Wer lieber seinen Minecraft-Kopf möchte, kann ihn danach wie gewohnt übernehmen.
- Die Anmeldung läuft über `https://steamcommunity.com/openid/login`. Jede Antwort wird
  direkt bei Steam bestätigt; manipulierte, fremde oder veraltete Antworten werden abgelehnt.

## Einstellungen

| Einstellung | Beschreibung |
|---|---|
| `steam_login_enabled` | Steam-Anmeldung ein/aus |
| `steam_web_api_key` | Steam Web API Key (geheim) für Name und Profilbild |
| `steam_login_import_avatar` | Steam-Profilbild bei der Registrierung übernehmen |
