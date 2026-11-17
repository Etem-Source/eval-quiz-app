# 03 — Jalons de validation progressive

**Chaque jalon donne lieu à une courte démonstration au formateur et à la conservation de preuves dans le dépôt. Aucun point chiffré n'est communiqué ici.** La validation d'un jalon reste acquise, même si une ressource Azure est supprimée ensuite.

## Règle de dépôt et de validation des modifications

Chaque groupe crée **son propre fork du dépôt officiel**. Toutes les branches de travail (`feature/*`) et Pull Requests ciblent la branche **`main` de ce fork**, jamais celle du formateur. Pour les groupes utilisant GitLab, les Merge Requests ciblent `main` de leur projet GitLab. Les contrôles CI et le scan Trivy doivent réussir avant la fusion. La fusion doit être approuvée selon les règles de revue configurées. Chaque groupe transmet au formateur le lien de son dépôt et des PR/MR utilisées comme preuves.

## J0 — Vérification préalable (non notée)

Vérifiez que votre abonnement Azure fonctionne et identifiez les restrictions concernant ACR, Azure Container Apps, la région, les quotas et les crédits. Signalez tout blocage au formateur avant d'engager des dépenses.

## J1 — Conteneurisation locale

**À montrer :** construction des images, démarrage avec Docker Compose, communication frontend/backend, base PostgreSQL accessible, fonctionnalités principales et persistance des données après recréation des conteneurs sans suppression du volume.

**Preuves :** Dockerfiles, Compose, commandes, logs expurgés, captures de fonctionnement, explication du volume.

## J2 — Sécurité des images

**À montrer :** scan Trivy initial, correction des problèmes pertinents, deuxième scan et explication des vulnérabilités résiduelles.

**Preuves :** rapport avant/après, choix justifiés, commandes utilisées.

## J3 — Azure CLI et ACR

**À montrer :** ressources créées avec Azure CLI ; images présentes dans ACR avec des tags identifiables.

**Preuves :** scripts, captures ou sorties non sensibles des ressources et des images.

## J4 — Frontend et backend dans Azure Container Apps

**À montrer :** deux applications conteneurisées configurées sur Azure, images tirées d’ACR, ingress du frontend, configuration réseau et état des révisions. Le backend expose `GET /health` sur le port **3007** ; si le serveur démarre, démontrez une réponse HTTP 200 avec `{"status":"ok"}` (test sans requête à PostgreSQL). Fournissez un diagnostic si le démarrage du backend est empêché par une dépendance à la base.

**Preuves :** configuration, état et logs des révisions, URL du frontend si disponible, test de `/health` avec code HTTP et réponse, ou diagnostic argumenté si la route reste inaccessible.

**La réussite de la connexion PostgreSQL cloud n’est pas exigée ici.** Le test `/health` ne prouve pas la disponibilité de la base. Le démarrage sans PostgreSQL n’a pas encore été validé expérimentalement par le formateur : si la base bloque effectivement le démarrage, une validation technique partielle sera envisagée selon les preuves et le diagnostic fournis.

## J5 — PostgreSQL cloud

**À montrer :** connexion chiffrée à PostgreSQL distant, initialisation du schéma, inscription et/ou enregistrement de résultats, persistance.

**Preuves :** démonstration fonctionnelle, logs non sensibles, explication de la gestion des secrets.

**Un échec sur ce jalon n'annule pas J1 à J4 et n'interdit pas de présenter J6.**

## J6 — CI/CD, deux validations distinctes

**J6-A — CI sur Pull/Merge Request :** build des images, scan Trivy bloquant sur CRITICAL, contrôle requis avant fusion, revue/approbation.

**J6-B — CD après fusion dans `main` :** publication des images validées dans ACR et mise à jour automatique des Container Apps. Prouvez le déclenchement et la mise à jour des révisions même si la validation fonctionnelle dépend encore de PostgreSQL.

**Preuves :** URL de PR/MR, exécutions CI/CD, rapports Trivy, tags ou digests d'images, révisions Azure.

## Règles de passage

- Faites valider J1 avant le déploiement cloud.
- Les jalons techniques ultérieurs peuvent être avancés indépendamment dès que leurs prérequis pratiques sont disponibles.
- Signalez au formateur les restrictions du compte Azure ; conservez vos scripts et les preuves.
- **Ne partagez jamais d'informations d'authentification dans les captures ou les logs.**
