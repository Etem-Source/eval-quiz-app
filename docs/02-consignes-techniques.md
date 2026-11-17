# 02 — Consignes techniques

## Conteneurisation locale

- Étudiez les dépendances et les commandes de lancement du code source fourni.
- Rédigez les Dockerfiles nécessaires ; documentez les choix d'images de base, de couches et de sécurité.
- Rédigez `docker-compose.yml` pour le frontend, le backend et PostgreSQL.
- Configurez le réseau, les variables d'environnement, les dépendances et les volumes.
- Montrez que l'application démarre localement et que les résultats enregistrés persistent après recréation des conteneurs **sans supprimer le volume**.
- Fournissez un `.env.example` sans valeurs sensibles ; le vrai `.env` ne doit pas être versionné.

## Sécurité

- Analysez les images avec Trivy (Docker Scout peut compléter l'analyse locale).
- Conservez un état initial, listez les vulnérabilités pertinentes et justifiez les corrections.
- Réanalysez les images et documentez les vulnérabilités résiduelles.
- Dans la CI, une vulnérabilité de sévérité **CRITICAL** détectée par Trivy doit provoquer l'échec du contrôle, selon la politique définie dans [04 — CI/CD](04-pipeline-cicd.md).

## Azure

- Connectez-vous à l'abonnement étudiant avec Azure CLI ; vérifiez les droits et quotas disponibles avant provisionnement.
- Créez un groupe de ressources, un ACR, un environnement Azure Container Apps et les Container Apps nécessaires.
- Publiez vos images dans ACR, puis configurez les applications pour récupérer ces images.
- Configurez correctement les accès au registre, l'ingress, les communications interservices, les variables d'environnement et les secrets.
- Rédigez un script `scripts/deploy.sh` réutilisable et un script `scripts/destroy.sh` pour le nettoyage ; documentez les prérequis et les opérations sensibles.
- Ne stockez aucun secret dans les scripts ni dans le dépôt.

## PostgreSQL cloud

- Conservez **PostgreSQL local** dans Docker Compose.
- Pour le cloud, utilisez une base PostgreSQL externe, Neon recommandé, ou une autre solution PostgreSQL compatible.
- Fournissez au backend sa chaîne de connexion via un secret et vérifiez les exigences TLS du pilote utilisé.
- Initialisez le schéma via les scripts ou migrations existants ; ne supposez pas que les tables apparaîtront automatiquement.
- Démontrez l'enregistrement et la persistance d'un utilisateur et/ou d'un résultat de quiz.

## Maîtrise des coûts

- Privilégiez les configurations minimales compatibles avec l'exercice.
- Conservez des preuves **sans secrets** avant de supprimer les ressources.
- Une ressource supprimée peut devoir être recréée pour un jalon suivant : planifiez le nettoyage et signalez les blocages liés au compte étudiant.
