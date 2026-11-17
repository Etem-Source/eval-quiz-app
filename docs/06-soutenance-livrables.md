# 06 - Soutenance et livrables

## Dépôt de remise

Chaque groupe remet **l’URL de son fork GitHub** (ou de son projet GitLab), ainsi que les liens vers ses Pull/Merge Requests et exécutions CI/CD. Ne soumettez aucune Pull Request vers le dépôt officiel du formateur.

## Livrables dans votre dépôt

- Code applicatif fourni, sans modification métier non demandée.
- Dockerfiles, `docker-compose.yml`, `.env.example` sans secrets.
- Scripts Azure CLI, dont `scripts/deploy.sh` et `scripts/destroy.sh`.
- Workflow GitHub Actions **ou** `.gitlab-ci.yml`.
- Rapport de sécurité Trivy initial/final et corrections.
- Documentation des étapes de lancement local, du déploiement cloud, des prérequis et du nettoyage.
- Preuves datées de validation par jalon, sans informations confidentielles.
- Schéma d'architecture locale et cloud **réalisé par votre groupe**.

Vous pouvez créer un répertoire `preuves/J1/` à `preuves/J6/` contenant vos captures et comptes rendus expurgés. Pour les preuves volumineuses, fournissez des liens accessibles au formateur.

## Soutenance

**Format indicatif : 15 minutes par groupe**, dont présentation, démonstration et questions individuelles.

Présentez en six diapositives maximum : contexte, conteneurisation locale, sécurité, architecture Azure, CI/CD, difficultés et bilan (regroupez les thèmes si nécessaire).

La démonstration privilégiée est : modification d'une question dans le code → branche → Pull/Merge Request → contrôle Trivy → approbation → fusion → publication ACR → mise à jour Azure Container Apps. Si PostgreSQL cloud est fonctionnel, montrez également la nouvelle question dans l'application.

Si des ressources Azure ont dû être supprimées faute de crédits, les **preuves validées au fil du projet** peuvent remplacer la démonstration en direct de ces étapes. Expliquez précisément ce qui a fonctionné, ce qui n'a pas fonctionné et pourquoi.

Chaque membre doit pouvoir expliquer sa contribution, les choix techniques et les difficultés rencontrées.

## Vérification individuelle sans IA

Pendant les questions, le formateur peut demander une modification technique limitée ou un diagnostic en direct, sans assistant IA. Chaque membre doit pouvoir justifier les éléments qu’il a contribué à réaliser. Consultez la [charte d’utilisation de l’IA](09-utilisation-ia.md).
