#!/usr/bin/env bash
# Déploiement de Quiz App sur Azure Container Apps (Azure CLI).
# Prérequis : az CLI connecté (az login), Docker, extension containerapp.
# Secrets à fournir en variables d'environnement (jamais dans ce fichier) :
#   JWT_SECRET, ADMIN_PASSWORD   (obligatoires)
#   RESEND_API_KEY               (facultatif, valeur factice par défaut)
#   DATABASE_URL                 (facultatif, ex. Neon avec ?sslmode=require)
set -euo pipefail

RG="${RG:-rg-quiz-app}"
LOC="${LOC:-francecentral}"
ACR="${ACR:-acrquizetem}"
ENV_NAME="${ENV_NAME:-env-quiz-std}"
TAG="${TAG:-$(git rev-parse --short HEAD)}"
BUILD="${BUILD:-true}"   # BUILD=false pour réutiliser des images déjà poussées

: "${JWT_SECRET:?Variable JWT_SECRET manquante}"
: "${ADMIN_PASSWORD:?Variable ADMIN_PASSWORD manquante}"
RESEND_API_KEY="${RESEND_API_KEY:-re_dummy}"

BACKEND_IMAGE="$ACR.azurecr.io/quiz-backend:$TAG"
FRONTEND_IMAGE="$ACR.azurecr.io/quiz-frontend:$TAG"

echo "==> Groupe de ressources $RG ($LOC)"
az group create -n "$RG" -l "$LOC" -o none

echo "==> Registre $ACR"
az acr show -n "$ACR" -g "$RG" -o none 2>/dev/null \
  || az acr create -n "$ACR" -g "$RG" --sku Basic -o none

if [ "$BUILD" = "true" ]; then
  echo "==> Build et push des images (tag $TAG)"
  az acr login -n "$ACR"
  docker build -t "$BACKEND_IMAGE" ./backend
  docker build -t "$FRONTEND_IMAGE" .
  docker push "$BACKEND_IMAGE"
  docker push "$FRONTEND_IMAGE"
fi

echo "==> Environnement Container Apps $ENV_NAME (Workload Profiles, pas Express)"
az containerapp env show -n "$ENV_NAME" -g "$RG" -o none 2>/dev/null \
  || az containerapp env create -n "$ENV_NAME" -g "$RG" -l "$LOC" \
       --enable-workload-profiles true --environment-mode WorkloadProfiles -o none

SECRETS=("resend-key=$RESEND_API_KEY" "jwt-secret=$JWT_SECRET" "admin-password=$ADMIN_PASSWORD")
ENVVARS=("RESEND_API_KEY=secretref:resend-key" "JWT_SECRET=secretref:jwt-secret"
         "ADMIN_USERNAME=admin" "ADMIN_PASSWORD=secretref:admin-password")
if [ -n "${DATABASE_URL:-}" ]; then
  SECRETS+=("database-url=$DATABASE_URL")
  ENVVARS+=("DATABASE_URL=secretref:database-url")
fi

echo "==> Backend (ingress interne, port 3007)"
if az containerapp show -n quiz-backend -g "$RG" -o none 2>/dev/null; then
  az containerapp secret set -n quiz-backend -g "$RG" --secrets "${SECRETS[@]}" -o none
  az containerapp update -n quiz-backend -g "$RG" --image "$BACKEND_IMAGE" \
    --set-env-vars "${ENVVARS[@]}" -o none
else
  az containerapp create -n quiz-backend -g "$RG" --environment "$ENV_NAME" \
    --workload-profile-name Consumption --image "$BACKEND_IMAGE" \
    --registry-server "$ACR.azurecr.io" --registry-identity system \
    --ingress internal --target-port 3007 \
    --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 \
    --secrets "${SECRETS[@]}" --env-vars "${ENVVARS[@]}" -o none
  az containerapp ingress update -n quiz-backend -g "$RG" --allow-insecure -o none
fi

echo "==> Frontend (ingress externe, port 8080)"
if az containerapp show -n quiz-frontend -g "$RG" -o none 2>/dev/null; then
  az containerapp update -n quiz-frontend -g "$RG" --image "$FRONTEND_IMAGE" -o none
else
  az containerapp create -n quiz-frontend -g "$RG" --environment "$ENV_NAME" \
    --workload-profile-name Consumption --image "$FRONTEND_IMAGE" \
    --registry-server "$ACR.azurecr.io" --registry-identity system \
    --ingress external --target-port 8080 \
    --cpu 0.25 --memory 0.5Gi --min-replicas 1 --max-replicas 1 \
    --env-vars "BACKEND_HOST=quiz-backend" -o none
fi

FRONT=$(az containerapp show -n quiz-frontend -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)
echo "==> Déployé : https://$FRONT  (test : curl -i https://$FRONT/health)"
