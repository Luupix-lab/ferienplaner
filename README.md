# Ferienplaner

Mobile Web-App für Ferien, WK und Prüfungsphasen im Team. Läuft auf GitHub Pages, Daten in Supabase.

## Teams

| Team | Link | Supabase-Projekt | Einstellungen |
|---|---|---|---|
| Hauptteam | https://luupix-lab.github.io/ferienplaner/ | `jrwwuequwhofjrhsxpxb` | `config.js` |
| Steinhausen | https://luupix-lab.github.io/ferienplaner/steinhausen/ | `fhmdajmxxmxjhjljuixh` | `steinhausen/config.js` |

Jedes Team hat eine eigene Datenbank, eigene Admin-PIN (lokal in `ADMIN-PIN*.txt`, nicht im Repo) und eigenen Browser-Speicher.

## Änderungen ausrollen

Der App-Code liegt nur in `index.html`. Vor jedem Push in alle Team-Ordner verteilen:

```sh
./sync-teams.sh
git add -A && git commit -m "..." && git push
```

Datenbank-Änderungen (`sql/`) in **allen** Supabase-Projekten ausführen.

## Neues Team

1. Neues Supabase-Projekt anlegen, `sql/001`–`00x` der Reihe nach ausführen, Admin-PIN setzen (siehe Kommentar in `sql/001_init.sql`).
2. Ordner anlegen mit `config.js` (eigene `id`, Titel, Supabase-URL und Publishable Key) und `manifest.webmanifest`.
3. Ordnernamen in `sync-teams.sh` ergänzen, ausführen, pushen.
