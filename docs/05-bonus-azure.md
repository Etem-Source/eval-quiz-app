# 05 - Fonctionnalités avancées (facultatives)

## Scalabilité Azure Container Apps

Si votre abonnement et ses quotas le permettent, configurez une règle de mise à l'échelle, par exemple basée sur les requêtes HTTP. Expliquez le minimum et le maximum de réplicas, puis apportez une preuve de configuration et, si possible, un test de charge démontrant la variation du nombre de réplicas.

Le nombre de réplicas configuré dans Docker Compose n'est **pas** une preuve d'autoscaling Azure.

## Sous-domaine personnalisé et HTTPS

Le formateur vous communiquera un sous-domaine, par exemple `quiz.g01.labformation.fr`, **uniquement lorsque votre application sera prête**. Ne créez ni n'utilisez de sous-domaine sans attribution.

Configurez le rattachement au frontend Azure Container Apps et le certificat HTTPS selon les possibilités de l'abonnement. Communiquez au formateur les enregistrements DNS nécessaires (par exemple CNAME et enregistrement de vérification TXT). **Le formateur conserve la gestion de la zone DNS** ; vous ne disposez pas automatiquement des droits de modification.

## Important

Ces fonctionnalités sont facultatives et ne doivent pas empêcher la validation des jalons principaux en cas de restriction de l'abonnement étudiant.
