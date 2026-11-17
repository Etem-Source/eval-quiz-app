# Preuves J1 – Conteneurisation locale (17/11/2026)

| À montrer | Preuve |
|---|---|
| Construction des images | `01-build.txt`, `Dockerfile`, `backend/Dockerfile` |
| Démarrage Compose | `02-compose-ps.txt`, `docker-compose.yml` |
| Communication front → back | `03-front-vers-back.txt` (HTTP 200 via Nginx sur /health) |
| PostgreSQL accessible | `04-db-tables.txt` (tables créées par init.sql) |
| Fonctionnalités | `05-*.png` (inscription, quiz, score, admin) |
| Persistance | `06a-avant.txt` / `06b-apres.txt` : mêmes résultats après `down` + `up` sans `-v` |
| Volume | `07-volume.txt` : volume nommé `pgdata` monté sur `/var/lib/postgresql/data` |
| Logs | `08-logs.txt` (expurgés) |
| Diagnostic | `09-crash-sans-resend.txt` |

**Explication du volume** : les données de PostgreSQL sont stockées dans le volume nommé `pgdata`, géré par Docker et indépendant du cycle de vie du conteneur. `docker compose down` supprime les conteneurs mais pas les volumes, donc la base est retrouvée intacte au redémarrage. Seul `docker compose down -v` supprimerait les données.