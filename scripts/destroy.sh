#!/usr/bin/env bash
# Supprime TOUTES les ressources Azure du projet (groupe de ressources entier).
# Opération irréversible : sauvegarder les preuves avant.
set -euo pipefail

RG="${RG:-rg-quiz-app}"

read -r -p "Supprimer définitivement le groupe '$RG' et tout son contenu ? (oui/non) " ANSWER
if [ "$ANSWER" != "oui" ]; then
  echo "Annulé."
  exit 0
fi

az group delete -n "$RG" --yes --no-wait
echo "Suppression de $RG lancée (quelques minutes). Vérifier avec : az group exists -n $RG"
