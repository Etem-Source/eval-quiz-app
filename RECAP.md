# Quiz App – Récapitulatif complet (J0 à J5)

Projet d'évaluation : conteneuriser, sécuriser et déployer Quiz App sur Azure, puis automatiser les livraisons.
Dépôt du groupe : https://github.com/Etem-Source/eval-quiz-app (fork de `franklin-tutorials/eval-quiz-app`)
Dossier local : `C:\Users\Etem\eval-quiz-app`
État au 17/11/2026, 15 h 20 : **J0 à J5 terminés**, J6 (CI/CD) à faire.

---

## 1. Vue d'ensemble

### Architecture

```
LOCAL (Docker Compose)
Navigateur ──:8087──> frontend (Nginx non-root :8080) ──/api, /health──> backend (Node/Express :3007) ──:5432──> db (PostgreSQL 16)
                                                                                                                  └── volume pgdata

AZURE
Navigateur ──HTTPS──> quiz-frontend (Container App, ingress externe :8080)
                          └── http://quiz-backend ──> quiz-backend (Container App, ingress interne :3007)
                                                           └── TLS (sslmode=require) ──> Neon PostgreSQL (Frankfurt)
Images : ACR acrquizetem.azurecr.io (tag = SHA court du commit), tirées par identité managée
```

### Ressources

| Élément | Valeur |
|---|---|
| Abonnement | Azure for Students |
| Région | `francecentral` (imposée par la policy, voir J0) |
| Groupe de ressources | `rg-quiz-app` |
| Registre | `acrquizetem` (SKU Basic) |
| Environnement Container Apps | `env-quiz-std` (mode Workload Profiles, profil Consumption) |
| Apps | `quiz-backend` (interne), `quiz-frontend` (externe) |
| URL publique | https://quiz-frontend.gentlebay-5388aeac.francecentral.azurecontainerapps.io |
| Base cloud | Neon, projet `quiz-app`, AWS Europe Central 1 (Frankfurt) |

### Branches et Pull Requests (une PR par jalon, toujours vers `Etem-Source/main`)

| Jalon | Branche | PR |
|---|---|---|
| J1 | `feature/conteneurisation` | J1 - Conteneurisation locale (#1) |
| J2 | `feature/securite-trivy` | J2 - Sécurité des images |
| J3 | `feature/azure` | J3 - Azure CLI et ACR |
| J4 | `feature/container-apps` | J4 - Frontend et backend sur Azure Container Apps |
| J5 | `feature/postgres-cloud` | J5 - PostgreSQL cloud (Neon) |
| J6 | `feature/cicd` | J6 - CI/CD GitHub Actions (à faire) |

### Cycle Git utilisé à chaque jalon

```powershell
git checkout main
git pull
git checkout -b feature/<nom>
# ... travail ...
git status                      # vérifier la branche, et que .env n'apparaît jamais
git add <fichiers>
git commit -m "Jx: description"
git push -u origin feature/<nom>   # -u seulement la 1re fois, ensuite : git push
```

Ensuite, sur GitHub : Pull requests → New pull request → vérifier **base repository = Etem-Source/eval-quiz-app**, base `main` → Create → approbation → Merge.
⚠️ Le bouton « Compare & pull request » d'un fork propose par défaut le dépôt du formateur.

### À chaque nouveau terminal PowerShell

```powershell
cd C:\Users\Etem\eval-quiz-app
. .\scripts\vars.ps1        # point + espace devant
```

`scripts/vars.ps1` :

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$RG  = "rg-quiz-app"
$LOC = "francecentral"
$ACR = "acrquizetem"
$ENV_NAME = "env-quiz-std"
$TAG = git rev-parse --short HEAD
Write-Host "RG=$RG ACR=$ACR TAG=$TAG"
```

---

## 2. J0 – Vérification de l'abonnement Azure

Commandes lancées dans Azure Cloud Shell (Bash) :

```bash
az account show -o table
az policy assignment list -o table
az policy assignment show --name sys.regionrestriction \
  --scope /subscriptions/$(az account show --query id -o tsv) \
  --query "parameters.listOfAllowedLocations.value" -o tsv
az provider register -n Microsoft.App
az provider register -n Microsoft.ContainerRegistry
az provider register -n Microsoft.OperationalInsights
az provider show -n Microsoft.App --query "resourceTypes[?resourceType=='managedEnvironments'].locations" -o tsv | tr '\t' '\n' | grep -i france
az provider show -n Microsoft.App --query registrationState -o tsv
```

Résultat :
- Régions autorisées : francecentral, norwayeast, switzerlandnorth, denmarkeast, italynorth. **Choix : francecentral.**
- Container Apps est disponible en France Central, et les providers sont enregistrés.
- Azure CLI installé sur le PC : `winget install -e --id Microsoft.AzureCLI`

---

## 3. J1 – Conteneurisation locale

### `backend/Dockerfile` (version finale, après J2)

```dockerfile
FROM node:20-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN apk upgrade --no-cache \
 && apk add --no-cache tini \
 && npm install --omit=dev \
 && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

COPY --chown=node:node server.js ./

USER node
EXPOSE 3007

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3007/health || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
```

`backend/.dockerignore` : `node_modules`, `npm-debug.log`, `.env`

### `Dockerfile` frontend, à la racine (version finale, après J2 et J4)

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine
USER root
RUN apk upgrade --no-cache
USER 101
ENV BACKEND_HOST=backend:3007
COPY nginx/nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
```

`.dockerignore` à la racine : `node_modules`, `dist`, `.git`, `.env`, `backend`, `database`, `docs`, `preuves`

### `nginx/nginx.conf` (version finale J4 : template)

```nginx
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;

    location / {
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location = /gestion-quiz {
        try_files /gestion-quiz.html =404;
    }

    location /api/ {
        proxy_pass http://${BACKEND_HOST};
        proxy_http_version 1.1;
        proxy_set_header Host $proxy_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /health {
        proxy_pass http://${BACKEND_HOST};
        proxy_http_version 1.1;
        proxy_set_header Host $proxy_host;
    }
}
```

### `docker-compose.yml`

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: unless-stopped

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      RESEND_API_KEY: ${RESEND_API_KEY}
      FROM_EMAIL: ${FROM_EMAIL}
      ADMIN_USERNAME: ${ADMIN_USERNAME}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  frontend:
    build: .
    ports:
      - "8087:8080"
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  pgdata:
```

### Commandes J1

```powershell
# Test du backend seul
docker build -t quiz-backend ./backend
docker run --rm -p 3007:3007 -e RESEND_API_KEY=re_dummy quiz-backend
curl.exe http://localhost:3007/health          # → {"status":"ok"}
docker run --rm -p 3007:3007 quiz-backend      # sans clé → crash « Missing API key »

# Stack complète
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps
docker compose up -d --build --force-recreate frontend   # rebuild du frontend seul

# Preuves
docker compose build --no-cache 2>&1 | Out-File -Encoding utf8 preuves\J1\01-build.txt
docker compose ps | Out-File -Encoding utf8 preuves\J1\02-compose-ps.txt
curl.exe -s -i http://localhost:8087/health | Out-File -Encoding utf8 preuves\J1\03-front-vers-back.txt
docker compose exec db psql -U quiz_user -d quiz_db -c "\dt" | Out-File -Encoding utf8 preuves\J1\04-db-tables.txt
$q = "SELECT u.firstname, r.score, r.total_questions, r.completed_at FROM quiz_results r JOIN users u ON u.id = r.user_id;"
docker compose exec db psql -U quiz_user -d quiz_db -c $q | Out-File -Encoding utf8 preuves\J1\06a-avant.txt
docker compose down
docker compose up -d
docker compose exec db psql -U quiz_user -d quiz_db -c $q | Out-File -Encoding utf8 preuves\J1\06b-apres.txt
docker volume ls | Out-File -Encoding utf8 preuves\J1\07-volume.txt
docker volume inspect eval-quiz-app_pgdata | Out-File -Encoding utf8 -Append preuves\J1\07-volume.txt
docker compose logs --no-color backend db | Out-File -Encoding utf8 preuves\J1\08-logs.txt
```

### Choix à expliquer

| Choix | Raison |
|---|---|
| `node:20-alpine` | Node 20 exigé par le projet. Image légère, donc moins de failles |
| `COPY package*.json` avant le code | Cache des couches : pas de `npm install` si seul le code change |
| `USER node` / `nginx-unprivileged` (UID 101) | Aucun processus en root |
| `tini` en ENTRYPOINT | Node en PID 1 ignore SIGINT (Ctrl+C), tini transmet les signaux pour un arrêt propre |
| Frontend multi-stage | L'image finale ne contient ni Node, ni npm, ni le code source, seulement `dist/` |
| Nginx sur 8080 | Un utilisateur non-root ne peut pas ouvrir le port 80 |
| Volume nommé `pgdata` | Les données survivent à `docker compose down`. Seul `down -v` les supprime |
| `init.sql` dans `/docker-entrypoint-initdb.d/` | Exécuté automatiquement au **premier** démarrage, quand le volume est vide |
| `healthcheck` + `service_healthy` | Le backend attend que PostgreSQL soit prêt |
| Seul le frontend exposé (8087) | Le backend et la base restent sur le réseau interne Docker |
| `$${VAR}` dans le healthcheck | Évite que Compose remplace la variable lui-même : c'est le conteneur qui la lit |

---

## 4. J2 – Sécurité des images (Trivy)

### Commandes

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$trivy = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy:latest"

# Avant
iex "$trivy image --scanners vuln eval-quiz-app-backend"  | Out-File -Encoding utf8 preuves\J2\01-avant-backend.txt
iex "$trivy image --scanners vuln eval-quiz-app-frontend" | Out-File -Encoding utf8 preuves\J2\01-avant-frontend.txt

# Corrections dans les Dockerfiles, puis
docker compose up -d --build

# Après
iex "$trivy image --scanners vuln eval-quiz-app-backend"  | Out-File -Encoding utf8 preuves\J2\02-apres-backend.txt
iex "$trivy image --scanners vuln eval-quiz-app-frontend" | Out-File -Encoding utf8 preuves\J2\02-apres-frontend.txt

# Résumés (démo)
iex "$trivy image --scanners vuln --severity HIGH,CRITICAL eval-quiz-app-backend"
iex "$trivy image --scanners vuln --severity HIGH,CRITICAL eval-quiz-app-frontend"
Select-String "Total:" preuves\J2\*.txt        # totaux toutes sévérités
```

### Résultats (HIGH/CRITICAL)

| Image | Avant | Après |
|---|---|---|
| Frontend (OS Alpine) | 13 (12 HIGH + 1 CRITICAL `brotli-libs`) | **0** |
| Backend OS (Alpine) | 7 HIGH (openssl, musl, zlib) | **0** |
| Backend Node | 22 (21 HIGH + 1 CRITICAL `tar`) | **0** |
| **Total** | **42 (dont 2 CRITICAL)** | **0** |

⚠️ À l'oral, dire « 0 HIGH/CRITICAL », pas « 0 vulnérabilité » : des LOW/MEDIUM restent (voir les `Total:` des rapports complets).

### Analyse et corrections

1. **Les dépendances de l'application sont saines** : express, pg, resend… n'ont aucune faille HIGH/CRITICAL.
2. **Les 22 failles Node venaient de npm**, livré dans l'image `node:20-alpine` (`/usr/local/lib/node_modules/npm`). npm ne sert qu'au build. **Correction** : suppression de npm/npx dans l'image finale. Les fichiers vulnérables n'existent plus.
3. **Les failles OS avaient toutes un correctif publié** (colonne « Fixed Version », par exemple `brotli-libs 1.2.0-r1 → 1.2.1-r0`). L'image de base avait été construite avant ce correctif. **Correction** : `apk upgrade --no-cache`. Côté frontend, on repasse en `root` le temps de la mise à jour, puis on revient à l'utilisateur `101`.

Phrase pour l'oral : *« Les failles OS avaient des correctifs publiés, qu'on a appliqués avec apk upgrade. Les failles Node venaient de npm embarqué, inutile en production, qu'on a supprimé de l'image finale. »*

---

## 5. J3 – Azure CLI et ACR

```powershell
az login --tenant <tenant-id>      # voir le piège 4 si la MFA bloque
. .\scripts\vars.ps1
az group create -n $RG -l $LOC -o table
az acr create -g $RG -n $ACR --sku Basic -o table
az acr login -n $ACR
docker tag eval-quiz-app-backend  "$ACR.azurecr.io/quiz-backend:$TAG"
docker tag eval-quiz-app-frontend "$ACR.azurecr.io/quiz-frontend:$TAG"
docker push "$ACR.azurecr.io/quiz-backend:$TAG"
docker push "$ACR.azurecr.io/quiz-frontend:$TAG"

# Preuves
az group show -n $RG -o table | Out-File -Encoding utf8 preuves\J3\01-resource-group.txt
az acr show -n $ACR --query "{name:name, loginServer:loginServer, sku:sku.name, location:location}" -o table | Out-File -Encoding utf8 preuves\J3\02-acr.txt
az acr repository list -n $ACR -o table | Out-File -Encoding utf8 preuves\J3\03-repositories.txt
az acr repository show-tags -n $ACR --repository quiz-backend -o table  | Out-File -Encoding utf8 preuves\J3\04-tags.txt
az acr repository show-tags -n $ACR --repository quiz-frontend -o table | Out-File -Encoding utf8 -Append preuves\J3\04-tags.txt
```

Images publiées :

| Image | Tag | Digest |
|---|---|---|
| quiz-backend | `d92968b` | `sha256:39b28394…b464d` |
| quiz-frontend | `d92968b` | `sha256:d0a00ae7…b9e1d` |
| quiz-backend | `444d825` | `sha256:ff39eaf9…d026a` |
| quiz-frontend | `444d825` | `sha256:d97da8be…6cbe6` |

Choix : **tag = SHA court du commit Git** (traçabilité, retour arrière possible) plutôt que `latest`. **SKU Basic** pour le coût.

---

## 6. J4 – Frontend et backend sur Azure Container Apps

```powershell
. .\scripts\vars.ps1
az extension add -n containerapp --upgrade

# Environnement en mode Workload Profiles (pas Express, voir le piège 6)
az containerapp env create -n env-quiz-std -g $RG -l $LOC --enable-workload-profiles true --environment-mode WorkloadProfiles
az containerapp env show -n env-quiz-std -g $RG --query "properties.workloadProfiles[].name" -o tsv   # → Consumption

# Secrets saisis au clavier
$JWT = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | % {[char]$_})
$ADMINPWD = Read-Host "Mot de passe admin (lettres et chiffres uniquement)"

# Backend : ingress interne
az containerapp create -n quiz-backend -g $RG --environment $ENV_NAME --workload-profile-name Consumption `
  --image "$ACR.azurecr.io/quiz-backend:$TAG" `
  --registry-server "$ACR.azurecr.io" --registry-identity system `
  --ingress internal --target-port 3007 `
  --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 `
  --secrets "resend-key=re_dummy" "jwt-secret=$JWT" "admin-password=$ADMINPWD" `
  --env-vars "RESEND_API_KEY=secretref:resend-key" "JWT_SECRET=secretref:jwt-secret" "ADMIN_USERNAME=admin" "ADMIN_PASSWORD=secretref:admin-password" `
  -o table
az containerapp ingress update -n quiz-backend -g $RG --allow-insecure

# Frontend : ingress externe
az containerapp create -n quiz-frontend -g $RG --environment $ENV_NAME --workload-profile-name Consumption `
  --image "$ACR.azurecr.io/quiz-frontend:$TAG" `
  --registry-server "$ACR.azurecr.io" --registry-identity system `
  --ingress external --target-port 8080 `
  --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 `
  --env-vars "BACKEND_HOST=quiz-backend" `
  -o table

# Test
$FRONT = az containerapp show -n quiz-frontend -g $RG --query properties.configuration.ingress.fqdn -o tsv
curl.exe -s -i "https://$FRONT/health"     # → HTTP 200, server: nginx, x-powered-by: Express, {"status":"ok"}

# Preuves
az containerapp list -g $RG --query "[].{nom:name, image:properties.template.containers[0].image, ingress_externe:properties.configuration.ingress.external, fqdn:properties.configuration.ingress.fqdn}" -o table | Out-File -Encoding utf8 preuves\J4\01-apps.txt
az containerapp revision list -n quiz-backend -g $RG --query "[].{revision:name, active:properties.active, etat:properties.runningState, sante:properties.healthState}" -o table | Out-File -Encoding utf8 preuves\J4\02-revisions.txt
az containerapp revision list -n quiz-frontend -g $RG --query "[].{revision:name, active:properties.active, etat:properties.runningState, sante:properties.healthState}" -o table | Out-File -Encoding utf8 -Append preuves\J4\02-revisions.txt
curl.exe -s -i "https://$FRONT/health" | Out-File -Encoding utf8 preuves\J4\03-health.txt
az containerapp logs show -n quiz-backend -g $RG --tail 20 --type console | Out-File -Encoding utf8 preuves\J4\04-logs-backend.txt
az containerapp show -n quiz-backend -g $RG --query "properties.configuration.{secrets:secrets[].name, ingress:ingress.external, registre:registries}" -o json | Out-File -Encoding utf8 preuves\J4\05-config-backend.txt
```

### Choix à expliquer

| Choix | Raison |
|---|---|
| `--registry-identity system` | Identité managée avec le rôle AcrPull : aucun mot de passe de registre stocké |
| `--secrets` + `secretref:` | Valeurs sensibles stockées en secrets Container Apps, invisibles dans la config et les logs |
| Backend en `--ingress internal` | Inaccessible depuis Internet, seul le frontend le joint |
| `--allow-insecure` sur le backend | HTTP autorisé à l'intérieur de l'environnement. Sans ça, l'ingress redirige vers HTTPS et Nginx ne suit pas |
| `BACKEND_HOST` (template Nginx) | Même image partout : `backend:3007` en local, `quiz-backend` sur Azure |
| `proxy_set_header Host $proxy_host` | L'ingress interne route les requêtes selon l'en-tête Host |
| `RESEND_API_KEY=re_dummy` | Sans cette variable, le backend plante au démarrage |
| `/health` sans base | La route n'interroge pas PostgreSQL, et le pool `pg` ne se connecte qu'à la première requête |
| 0,25 vCPU / 0,5 Gi, 1 réplica | Configuration minimale pour économiser les crédits étudiants |

### Scripts livrables

- `scripts/deploy.sh` (Git Bash) : idempotent, il crée ou met à jour le groupe de ressources, l'ACR, les images, l'environnement en Workload Profiles et les 2 apps. Les secrets passent par des variables d'environnement :
  ```bash
  export JWT_SECRET="..." ADMIN_PASSWORD="..." DATABASE_URL="..."   # DATABASE_URL facultatif
  bash scripts/deploy.sh
  ```
- `scripts/destroy.sh` : `az group delete` sur `rg-quiz-app`, après avoir demandé de taper « oui ».

---

## 7. J5 – PostgreSQL cloud (Neon)

```powershell
. .\scripts\vars.ps1
$env:DATABASE_URL = Read-Host "Connection string Neon"      # jamais écrite dans un fichier
$env:DATABASE_URL = $env:DATABASE_URL -replace '&channel_binding=require',''   # voir le piège 7
$env:DATABASE_URL.Contains('&')                             # → False

# Schéma (une seule fois)
Get-Content database\init.sql -Raw | docker run --rm -i postgres:16-alpine psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1
docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c "\dt" | Out-File -Encoding utf8 preuves\J5\01-schema-neon.txt

# Branchement du backend Azure
az containerapp secret set -n quiz-backend -g $RG --secrets "database-url=$env:DATABASE_URL"
az containerapp update -n quiz-backend -g $RG --set-env-vars "DATABASE_URL=secretref:database-url"
$REV = az containerapp show -n quiz-backend -g $RG --query properties.latestRevisionName -o tsv
az containerapp revision restart -n quiz-backend -g $RG --revision $REV

# Preuves
$q = "SELECT u.firstname, r.score, r.total_questions, r.completed_at FROM quiz_results r JOIN users u ON u.id = r.user_id;"
docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c $q | Out-File -Encoding utf8 preuves\J5\02-resultats-neon.txt
docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();" | Out-File -Encoding utf8 preuves\J5\03-tls.txt
az containerapp revision restart -n quiz-backend -g $RG --revision $REV
Start-Sleep 30
docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c $q | Out-File -Encoding utf8 preuves\J5\04-persistance-apres-restart.txt
az containerapp show -n quiz-backend -g $RG --query "properties.template.containers[0].env[].{nom:name, secret:secretRef}" -o table | Out-File -Encoding utf8 preuves\J5\05-env-backend.txt
Select-String "neon.tech" preuves\J5\*     # doit être vide : aucune fuite de la connection string
```

Résultat : inscription et quiz faits depuis l'URL Azure, enregistrés dans Neon (`daze`, 3/10). Connexion TLS vérifiée (`ssl = t`).

`.env.example` complété :
```
# DATABASE_URL=postgresql://<user>:<password>@<host>.neon.tech/<db>?sslmode=require
```

---

## 8. Les 7 pièges rencontrés (bons sujets pour l'oral)

| # | Problème | Cause | Solution |
|---|---|---|---|
| 1 | Ctrl+C n'arrête pas le conteneur, port 3007 resté occupé | Node en PID 1 ignore SIGINT | `tini` en ENTRYPOINT |
| 2 | Backend qui plante au démarrage | `new Resend()` exige `RESEND_API_KEY` | Toujours fournir la variable (une valeur factice suffit) |
| 3 | Rapports Trivy illisibles (`Ôöé`) | PowerShell 5 décode mal l'UTF-8 | `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` |
| 4 | `AADSTS50076` sur les commandes az | MFA exigée par le tenant | `az login --tenant <id> --scope https://management.core.windows.net//.default --claims-challenge <...>` |
| 5 | Nginx garde l'ancienne config | `nginx.conf` pas enregistré avant le rebuild | Ctrl+S, puis `docker compose up -d --build --force-recreate frontend` |
| 6 | `ExpressRegistrySystemIdentityNotSupported` | Environnement créé par défaut en mode **Express** (pas d'identité managée, pas de communication entre apps) | Recréé en mode Workload Profiles (`env-quiz-std`) |
| 7 | `'channel_binding' n'est pas reconnu en tant que commande` | `az` est un `.cmd` sous Windows et `cmd` coupe la chaîne au `&` | Retrait de `&channel_binding=require` (TLS assuré par `sslmode=require`) |

Autres pièges évités : variables PowerShell perdues dans un nouveau terminal (`scripts/vars.ps1`), dossiers vides non suivis par Git, PR qui cible le dépôt du formateur par défaut.

---

## 9. Démo devant le formateur (J1 à J5)

Avant de commencer : lancer Docker Desktop, puis `cd C:\Users\Etem\eval-quiz-app`, `. .\scripts\vars.ps1`, et faire `az login` **à l'avance**.

**J1** (environ 3 min)
1. `docker compose build`, puis `docker compose up -d`, puis `docker compose ps` : 3 services, base `healthy`.
2. `curl.exe -s http://localhost:8087/health` : front vers back.
3. `docker compose exec db psql -U quiz_user -d quiz_db -c "\dt"` : 3 tables.
4. Navigateur sur http://localhost:8087 : inscription, quiz, score, puis `/gestion-quiz`.
5. Requête `$q`, puis `docker compose down` (sans `-v`), puis `up -d`, puis la même requête : données présentes.

**J2** (environ 2 min)
1. Ouvrir `preuves/J2/01-avant-backend.txt` : CRITICAL `tar` dans npm.
2. Montrer les Dockerfiles : `apk upgrade` et suppression de npm.
3. En direct : `iex "$trivy image --scanners vuln --severity HIGH,CRITICAL eval-quiz-app-backend"` : 0.

**J3** (environ 1 min)
1. `az acr repository list -n $ACR -o table`
2. `az acr repository show-tags -n $ACR --repository quiz-backend -o table` : tags = SHA de commit.

**J4** (environ 2 min)
1. `az containerapp list -g $RG -o table`
2. `az containerapp revision list -n quiz-backend -g $RG -o table`
3. `curl.exe -s -i "https://$FRONT/health"` : 200, avec les en-têtes nginx et Express.

**J5** (environ 2 min)
1. Navigateur sur l'URL Azure : inscription et quiz.
2. `docker run --rm postgres:16-alpine psql "$env:DATABASE_URL" -c $q` : le nouveau résultat est dans Neon.
3. Montrer `preuves/J5/03-tls.txt` : connexion chiffrée.

### Questions probables

- **Pourquoi tini ?** Node en PID 1 ignore SIGINT, tini transmet les signaux.
- **Pourquoi supprimer npm ?** Il n'est utile qu'au build. En production, c'est de la surface d'attaque inutile.
- **Comment Container Apps tire les images sans mot de passe ?** Par identité managée, avec le rôle AcrPull.
- **Pourquoi le backend est interne ?** Pour qu'il ne soit pas exposé à Internet : seul Nginx le joint.
- **Où est le mot de passe de la base ?** Dans un secret Container Apps, jamais dans le dépôt.
- **Que fait `down -v` ?** Il supprime aussi le volume, donc les données.

---

## 10. Reste à faire

- [ ] **Faire valider J1 par le formateur** (règle du doc 03, oubliée) et **lui signaler les restrictions Azure** : régions, MFA, mode Express.
- [ ] **J6 – CI/CD** :
  - fichiers `ci.yml` et `cd.yml` (déjà fournis) dans `.github/workflows/` ;
  - identité OIDC `gh-quiz-app` (credential fédéré sur `main`, rôles Contributor sur `rg-quiz-app` et AcrPush) ;
  - secrets GitHub `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` ;
  - PR « J6 - CI/CD GitHub Actions » et premier passage vert de la CI ;
  - protection de `main` (PR obligatoire, 1 approbation, checks `Build & Trivy (backend)` et `Build & Trivy (frontend)`) ;
  - démo : une CI en échec contrôlé, puis une modification d'une question dans `questions_docker.js` → PR → Trivy → fusion → ACR → nouvelle révision.
- [ ] Schéma d'architecture cloud dans `README-GROUPE.md`, et section « Usage de l'IA » à jour.
- [ ] 6 diapositives de soutenance.
- [ ] Après validation et accord du formateur : `bash scripts/destroy.sh`.
