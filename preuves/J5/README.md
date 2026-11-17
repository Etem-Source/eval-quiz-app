# Preuves J5 – PostgreSQL cloud (Neon) (17/11/2026)

Base PostgreSQL externe **Neon** (offre gratuite) : projet `quiz-app`, région **AWS Europe Central 1 (Frankfurt)**, la plus proche de France Central. Le PostgreSQL local de Docker Compose est conservé pour le développement.

## Préparation

```powershell
. .\scripts\vars.ps1
$env:DATABASE_URL = Read-Host "Connection string Neon"   # jamais écrite dans un fichier ni commitée
```

## Fichiers de preuve

| Fichier | Ce qu'il prouve | Commande |
|---|---|---|
| `01-schema-neon.txt` | Schéma initialisé : tables `users`, `quiz_results`, `answers` | `Get-Content database\init.sql -Raw \| docker run --rm -i postgres:16-alpine psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1`, puis `docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c "\dt"` |
| `02-resultats-neon.txt` | Inscription et résultat de quiz faits depuis l'appli Azure, enregistrés dans Neon | `docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c $q` (requête ci-dessous) |
| `03-tls.txt` | Connexion chiffrée (`ssl = t`, TLS 1.3) | `docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"` |
| `04-persistance-apres-restart.txt` | Données toujours présentes après redémarrage du backend | `az containerapp revision restart -n quiz-backend -g $RG --revision $REV`, puis la même requête `$q` |
| `05-env-backend.txt` | `DATABASE_URL` injectée depuis un secret Container Apps (valeur jamais affichée) | `az containerapp show -n quiz-backend -g $RG --query "properties.template.containers[0].env[].{nom:name, secret:secretRef}" -o table` |
| `06-admin-azure.png` | Résultat visible dans la page d'administration sur l'URL Azure | Capture de `https://<FRONT>/gestion-quiz` |
| `07-tables-neon.png` | Tables et données visibles dans la console Neon | Capture du tableau de bord Neon |

Requête utilisée : `$q = "SELECT u.firstname, r.score, r.total_questions, r.completed_at FROM quiz_results r JOIN users u ON u.id = r.user_id;"`

Chaque sortie texte est suivie de `| Out-File -Encoding utf8 preuves\J5\<fichier>`.

## Configuration du backend Azure

```powershell
az containerapp secret set -n quiz-backend -g $RG --secrets "database-url=$env:DATABASE_URL"
az containerapp update -n quiz-backend -g $RG --set-env-vars "DATABASE_URL=secretref:database-url"
$REV = az containerapp show -n quiz-backend -g $RG --query properties.latestRevisionName -o tsv
az containerapp revision restart -n quiz-backend -g $RG --revision $REV
```

## Gestion des secrets

- La connection string (qui contient le mot de passe) est saisie au clavier avec `Read-Host`. Elle n'apparaît ni dans le dépôt, ni dans les scripts, ni dans les preuves.
- Sur Azure, elle est stockée comme **secret Container Apps** (`database-url`) et injectée dans la variable `DATABASE_URL` via `secretref:`.
- `.env.example` documente le format attendu, sans aucune valeur réelle.

## TLS

- La connection string Neon contient `sslmode=require` : le pilote `pg` du backend chiffre la connexion sans aucune modification du code.
- Vérification : `pg_stat_ssl` indique `ssl = t` (fichier `03-tls.txt`).

## Difficultés rencontrées

| Problème | Cause | Solution |
|---|---|---|
| Tables absentes sur Neon | `init.sql` n'est exécuté automatiquement que par le conteneur PostgreSQL local (`/docker-entrypoint-initdb.d/`) | Exécution manuelle unique avec `psql` dans un conteneur `postgres:16-alpine` (pas d'installation locale) |
| `'channel_binding' n'est pas reconnu en tant que commande` | Sous Windows, `az` est un script `.cmd`, et `cmd` interprète le `&` de l'URL comme un séparateur de commandes : le secret était tronqué | Retrait du paramètre `&channel_binding=require` (le chiffrement reste assuré par `sslmode=require`), puis nouveau secret et redémarrage de la révision |
| Première requête parfois en erreur | Neon met la base en veille, et le réveil peut dépasser le `connectionTimeoutMillis: 2000` du backend | Une nouvelle tentative suffit. Le code applicatif n'est pas modifié (consigne) |