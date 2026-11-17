# Preuves J4 – Frontend et backend sur Azure Container Apps (17/11/2026)

Préparation (PowerShell) : `. .\scripts\vars.ps1`, puis `$FRONT = az containerapp show -n quiz-frontend -g $RG --query properties.configuration.ingress.fqdn -o tsv`

| Fichier | Ce qu'il prouve | Commande |
|---|---|---|
| `01-apps.txt` | Les 2 apps, leurs images ACR taguées au SHA, l'ingress externe (front) et interne (back) | `az containerapp list -g $RG --query "[].{nom:name, image:properties.template.containers[0].image, ingress_externe:properties.configuration.ingress.external, fqdn:properties.configuration.ingress.fqdn}" -o table` |
| `02-revisions.txt` | Révisions actives, en cours d'exécution et saines | `az containerapp revision list -n quiz-backend -g $RG --query "[].{revision:name, active:properties.active, etat:properties.runningState, sante:properties.healthState}" -o table` (idem pour `quiz-frontend`, avec `-Append`) |
| `03-health.txt` | `GET /health` → HTTP 200 `{"status":"ok"}` via le frontend public (en-têtes `server: nginx` + `x-powered-by: Express`) | `curl.exe -s -i "https://$FRONT/health"` |
| `04-logs-backend.txt` | Démarrage du backend (`Server running on port 3007`) | `az containerapp logs show -n quiz-backend -g $RG --tail 20 --type console` |
| `05-config-backend.txt` | Secrets gérés par Container Apps (noms uniquement) et registre via identité managée | `az containerapp show -n quiz-backend -g $RG --query "properties.configuration.{secrets:secrets[].name, ingress:ingress.external, registre:registries}" -o json` |
| `06-quiz-azure.png` | Le quiz accessible sur l'URL publique | Capture du navigateur sur `https://<FRONT>` |

Chaque commande est suivie de `| Out-File -Encoding utf8 preuves\J4\<fichier>`.

## Commandes de déploiement utilisées

```powershell
az containerapp env create -n env-quiz-std -g $RG -l $LOC --enable-workload-profiles true --environment-mode WorkloadProfiles

az containerapp create -n quiz-backend -g $RG --environment $ENV_NAME --workload-profile-name Consumption `
  --image "$ACR.azurecr.io/quiz-backend:$TAG" --registry-server "$ACR.azurecr.io" --registry-identity system `
  --ingress internal --target-port 3007 --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 `
  --secrets "resend-key=***" "jwt-secret=***" "admin-password=***" `
  --env-vars "RESEND_API_KEY=secretref:resend-key" "JWT_SECRET=secretref:jwt-secret" "ADMIN_USERNAME=admin" "ADMIN_PASSWORD=secretref:admin-password"
az containerapp ingress update -n quiz-backend -g $RG --allow-insecure

az containerapp create -n quiz-frontend -g $RG --environment $ENV_NAME --workload-profile-name Consumption `
  --image "$ACR.azurecr.io/quiz-frontend:$TAG" --registry-server "$ACR.azurecr.io" --registry-identity system `
  --ingress external --target-port 8080 --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 `
  --env-vars "BACKEND_HOST=quiz-backend"
```

Version automatisée et réutilisable : `scripts/deploy.sh` (nettoyage : `scripts/destroy.sh`).

## Diagnostics et choix

- **Environnement Express créé par défaut** : erreur `ExpressRegistrySystemIdentityNotSupported`. Le mode Express ne gère ni l'identité managée pour l'ACR ni la communication entre apps. L'environnement a été recréé en mode **Workload Profiles** (`env-quiz-std`).
- **Nginx → backend** : l'adresse du backend est injectée par la variable `BACKEND_HOST` (template Nginx), qui vaut `backend:3007` en local et `quiz-backend` sur Azure. `proxy_set_header Host $proxy_host` est nécessaire, car l'ingress interne route les requêtes selon l'en-tête Host.
- **`--allow-insecure` sur le backend** : HTTP autorisé uniquement à l'intérieur de l'environnement (ingress interne). Sans cette option, l'ingress répond par une redirection HTTPS que Nginx ne suit pas.
- **`RESEND_API_KEY` factice** : le backend plante au démarrage sans cette variable (voir J1).
- **Sans base de données** : `/health` répond 200, car il n'interroge pas PostgreSQL et le pool `pg` ne se connecte qu'à la première requête. L'inscription renvoie une erreur tant que `DATABASE_URL` n'est pas configuré (J5).