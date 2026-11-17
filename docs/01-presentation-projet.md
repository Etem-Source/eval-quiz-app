# 01 - Présentation du projet

## Contexte

Quiz App est une application web de quiz avec un frontend, un backend, une base de données PostgreSQL pour les utilisateurs et les résultats, et éventuellement un service externe d'envoi d'emails.

L'entreprise veut remplacer les démarrages manuels par une chaîne de livraison reproductible : **développement → Pull/Merge Request → contrôle sécurité → fusion → images ACR → Azure Container Apps**.

## Objectifs pédagogiques

- Construire et optimiser des images avec Dockerfile.
- Orchestrer les services en local avec Docker Compose ; préserver les données PostgreSQL.
- Vérifier les images avec Trivy et corriger les vulnérabilités prioritaires.
- Utiliser Azure CLI pour provisionner et administrer ACR et Azure Container Apps.
- Séparer les configurations locales et cloud ; protéger les secrets.
- Créer un pipeline CI/CD avec contrôles obligatoires avant fusion.
- Expliquer l'architecture, les incidents rencontrés et les preuves de fonctionnement.

## Architecture cible indicative

**Local :** navigateur → frontend → backend → conteneur PostgreSQL (volume persistant).

**Cloud :** navigateur → frontend Azure Container Apps → backend Azure Container Apps → PostgreSQL managé externe, par exemple Neon. Les images sont publiées dans ACR ; GitHub Actions ou GitLab CI/CD pilote la livraison.

Adaptez le schéma au fonctionnement réel du code, notamment aux routes réseau et à la manière dont le frontend communique avec le backend. Le service backend peut avoir besoin d'une base opérationnelle pour démarrer ; ce cas doit être diagnostiqué et expliqué.

## Contraintes

- Aucun développement métier demandé, hors modification ciblée d'une question existante pour tester la chaîne de livraison.
- **Azure CLI et scripts shell** pour l'automatisation Azure ; Bicep et Terraform ne sont pas requis.
- GitHub Actions recommandé ; GitLab CI/CD autorisé à exigences équivalentes.
- Respecter les contraintes des abonnements Azure étudiants ; aucune dépense obligatoire non autorisée.
