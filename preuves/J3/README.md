# Preuves J3 – Azure CLI et ACR (17/11/2026)

Toutes les ressources ont été créées avec **Azure CLI**, sans passer par le portail. La version automatisée et réutilisable se trouve dans `scripts/deploy.sh`.

## Prérequis (J0)

- Abonnement **Azure for Students**. La policy `sys.regionrestriction` n'autorise que : francecentral, norwayeast, switzerlandnorth, denmarkeast, italynorth. **Choix : `francecentral`** (région la plus proche, Container Apps et ACR disponibles).
- Providers enregistrés : `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`.

## Commandes utilisées

Préparation (PowerShell) : `. .\scripts\vars.ps1` (définit `$RG`, `$LOC`, `$ACR`, et `$TAG` = SHA court du commit)

```powershell
az group create -n $RG -l $LOC -o table
az acr create -g $RG -n $ACR --sku Basic -o table
az acr login -n $ACR

docker tag eval-quiz-app-backend  "$ACR.azurecr.io/quiz-backend:$TAG"
docker tag eval-quiz-app-frontend "$ACR.azurecr.io/quiz-frontend:$TAG"
docker push "$ACR.azurecr.io/quiz-backend:$TAG"
docker push "$ACR.azurecr.io/quiz-frontend:$TAG"
```

## Fichiers de preuve

| Fichier | Ce qu'il prouve | Commande |
|---|---|---|
| `01-resource-group.txt` | Groupe de ressources `rg-quiz-app` en francecentral | `az group show -n $RG -o table` |
| `02-acr.txt` | Registre `acrquizetem`, SKU Basic, serveur de connexion | `az acr show -n $ACR --query "{name:name, loginServer:loginServer, sku:sku.name, location:location}" -o table` |
| `03-repositories.txt` | Dépôts `quiz-backend` et `quiz-frontend` présents | `az acr repository list -n $ACR -o table` |
| `04-tags.txt` | Tags identifiables (SHA de commit) | `az acr repository show-tags -n $ACR --repository quiz-backend -o table` (idem pour `quiz-frontend`, avec `-Append`) |

Chaque commande est suivie de `| Out-File -Encoding utf8 preuves\J3\<fichier>`.

## Images publiées

| Image | Tag | Digest |
|---|---|---|
| quiz-backend | `d92968b` | `sha256:39b28394285bf3a8c4f0b63a3318c909b6027a06acf2cfaeb69da42316eb464d` |
| quiz-frontend | `d92968b` | `sha256:d0a00ae78b947103fcb61444b7f2e3951801a56f96b36aedee8f8ffd393b9e1d` |
| quiz-backend | `444d825` (J4) | `sha256:ff39eaf9f6afbda6d80feacd78eaac61934082a12d9fe384e411b642cedd026a` |
| quiz-frontend | `444d825` (J4) | `sha256:d97da8be3ef4fe50a6ac6b1c8f9a3208edac7445d3283349af7d59d4eca6cbe6` |

## Choix techniques

- **Tag = SHA court du commit Git** plutôt que `latest`. Chaque image correspond à un commit précis : on sait quel code tourne, et on peut revenir en arrière.
- **SKU Basic** : l'offre la moins chère, suffisante pour le projet (crédits étudiants limités).
- **Accès au registre** : aucun mot de passe stocké. Les Container Apps tirent les images grâce à leur **identité managée** (rôle AcrPull, voir J4).

## Difficulté rencontrée

- **MFA exigée** (`AADSTS50076`) : `az login` simple ne suffisait pas. Il a fallu se reconnecter avec `az login --tenant <id> --scope https://management.core.windows.net//.default --claims-challenge <...>`.