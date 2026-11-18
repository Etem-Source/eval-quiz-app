# J6 – CI/CD avec GitHub Actions

## Le principe

Avant J6, tout se faisait à la main : build, scan, push vers l'ACR, mise à jour des Container Apps.
Avec J6, **GitHub Actions automatise la chaîne**, à des moments précis et avec des garde-fous.

```
Branche feature/... → modification → git push → Pull Request
                                                    │
                                      ┌─────────────▼─────────────┐
                                      │  CI (ci.yml)              │  ← sur chaque PR vers main
                                      │  build + Trivy            │
                                      │  CRITICAL → échec         │
                                      └─────────────┬─────────────┘
                                                    │ checks verts + approbation
                                                    ▼
                                             Merge dans main
                                                    │
                                      ┌─────────────▼─────────────┐
                                      │  CD (cd.yml)              │  ← seulement sur main
                                      │  connexion Azure (OIDC)   │
                                      │  build + Trivy            │
                                      │  push ACR (tag = SHA)     │
                                      │  update Container Apps    │
                                      └─────────────┬─────────────┘
                                                    ▼
                                      Nouvelle révision en ligne
```

## CI – Intégration continue (`.github/workflows/ci.yml`)

**Déclencheur** : chaque Pull Request vers `main`.
**Rôle** : vérifier, sans rien déployer.

1. Build des 2 images (backend et frontend), en parallèle grâce à une matrice.
2. Premier passage de **Trivy** : rapport HIGH/CRITICAL, publié en **artefact** téléchargeable.
3. Second passage de **Trivy en mode bloquant** : `--severity CRITICAL --exit-code 1`. Une seule faille CRITICAL fait échouer le job, sans `continue-on-error`.

La CI n'utilise **aucun secret**, car elle ne se connecte pas à Azure. Du code proposé par un contributeur externe ne peut donc rien récupérer.

## CD – Déploiement continu (`.github/workflows/cd.yml`)

**Déclencheur** : un push sur `main`, c'est-à-dire après la fusion d'une PR. Jamais sur une PR.

1. **Connexion à Azure par OIDC** : GitHub présente un jeton signé, qu'Azure accepte seulement s'il vient de `Etem-Source/eval-quiz-app`, branche `main`. Aucun mot de passe n'est stocké.
2. Build des images, puis nouveau **contrôle Trivy** bloquant (double sécurité).
3. Push dans l'**ACR**, avec un tag égal au **SHA court du commit** (traçabilité).
4. `az containerapp update` sur les 2 applications, ce qui crée une **nouvelle révision** de chacune.
5. Affichage des révisions actives dans les logs du workflow.

`concurrency: deploy-production` empêche que deux déploiements tournent en même temps.

## Accès à Azure sans mot de passe (OIDC)

| Élément | Valeur |
|---|---|
| Identité | Identité managée attribuée par l'utilisateur `id-github-quiz` (dans `rg-quiz-app`) |
| Credential fédéré | `github-main`, issuer `https://token.actions.githubusercontent.com`, subject `repo:Etem-Source/eval-quiz-app:ref:refs/heads/main` |
| Droits | **Contributor** sur `rg-quiz-app` uniquement, **AcrPush** sur `acrquizetem` uniquement |
| Secrets GitHub | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (des identifiants, pas des mots de passe) |

**Pourquoi une identité managée plutôt qu'une inscription d'application ?** Le compte étudiant n'a pas le droit de créer d'inscription d'application dans l'annuaire Entra ID de l'école (`Insufficient privileges`). L'identité managée est créée dans l'abonnement et prend en charge l'OIDC de la même façon.

### Commandes utilisées

```powershell
. .\scripts\vars.ps1
$SUB    = az account show --query id -o tsv
$TENANT = az account show --query tenantId -o tsv

az identity create -n id-github-quiz -g $RG -l $LOC -o table
$CLIENT_ID    = az identity show -n id-github-quiz -g $RG --query clientId -o tsv
$PRINCIPAL_ID = az identity show -n id-github-quiz -g $RG --query principalId -o tsv

az identity federated-credential create --name github-main --identity-name id-github-quiz -g $RG `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:Etem-Source/eval-quiz-app:ref:refs/heads/main" `
  --audiences "api://AzureADTokenExchange" -o table

az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role Contributor --scope "/subscriptions/$SUB/resourceGroups/$RG" -o none
az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal --role AcrPush --scope (az acr show -n $ACR --query id -o tsv) -o none

# Preuves
az identity federated-credential list --identity-name id-github-quiz -g $RG --query "[].{nom:name, issuer:issuer, subject:subject}" -o table | Out-File -Encoding utf8 preuves\J6\01-oidc-federated-credential.txt
az role assignment list --assignee $PRINCIPAL_ID --all --query "[].{role:roleDefinitionName, scope:scope}" -o table | Out-File -Encoding utf8 preuves\J6\02-roles-identite-github.txt
```

## Protection de la branche `main`

Dans Settings, puis Branches, une règle de protection est configurée sur `main` **après** le premier passage vert de la CI :

- PR obligatoire avant toute fusion.
- **1 approbation** requise (relecture par le collègue avec « Submit review », puis « Approve »).
- **Checks obligatoires** : `Build & Trivy (backend)` et `Build & Trivy (frontend)`.
- Force push et suppression de `main` interdits.

## Où voir les exécutions

| Quoi | Où |
|---|---|
| CI d'une PR | Dans la PR, bloc « checks » en bas, puis **Details** |
| CD après fusion | Onglet **Actions** du dépôt, workflow **CD** dans la liste de gauche, exécution nommée d'après le commit de fusion (« Merge pull request #… ») |
| Rapport Trivy | Exécution de la CI, en bas de la page, rubrique **Artifacts** (`trivy-backend`, `trivy-frontend`) |
| Révisions Azure | Logs de la CD (dernière étape), ou `az containerapp revision list -n quiz-backend -g rg-quiz-app -o table` |

## Difficultés rencontrées

| Problème | Cause | Solution |
|---|---|---|
| `Insufficient privileges` sur `az ad app create` | Le compte étudiant ne peut pas créer d'inscription d'application dans l'annuaire | Identité managée attribuée par l'utilisateur, avec credential fédéré |
| `RequestDisallowedByAzure ... without authenticating through MFA` | Le `az login` simple n'incluait pas la MFA | `az login --tenant <id> --scope https://management.core.windows.net//.default --claims-challenge <...>` |
| Workflows absents du premier commit (805 octets poussés) | Fichiers jamais copiés dans `.github/workflows` | Création des fichiers depuis PowerShell, vérification avec `git ls-files .github` |
| Bouton « Review changes » introuvable | Nouvelle interface GitHub | Le bouton s'appelle « Submit review » |

## Validations J6 attendues

- **J6-A (CI sur PR)** : PR #8 avec 2 checks verts ; démo d'un **échec contrôlé** (PR qui remet npm dans l'image backend : CRITICAL `tar`, CI rouge, fusion bloquée, PR fermée sans fusion) ; protection de `main` active.
- **J6-B (CD après fusion)** : exécution du workflow CD verte, images taguées avec le SHA dans l'ACR, nouvelles révisions des Container Apps.
- **Démo finale** : modification d'une question dans `questions_docker.js`, puis PR, CI, approbation, fusion, CD, nouvelle révision, et la question modifiée visible sur l'URL Azure.

## Preuves (`preuves/J6/`)

| Fichier | Contenu |
|---|---|
| `01-oidc-federated-credential.txt` | Credential fédéré limité à `main` |
| `02-roles-identite-github.txt` | Rôles Contributor (RG) et AcrPush (ACR) |
| `03-ci-pr-verte.png` | PR #8 : 2 checks verts |
| `04-protection-main.png` | Règle de protection de `main` |
| `05-cd-run.png` | Exécution du workflow CD verte |
| `06-acr-tags.txt` | Tags ACR après la CD |
| `07-revisions.txt` | Nouvelles révisions Azure |
| `08-ci-echec-critical.png` | Démo de la CI rouge, fusion bloquée |
| `09-question-modifiee.png` | Question modifiée visible sur l'URL Azure |
