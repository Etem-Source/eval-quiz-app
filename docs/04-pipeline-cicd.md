# 04 - Exigences CI/CD

## Plateforme au choix

- **GitHub Actions : recommandé.** Workflow dans `.github/workflows/`.
- **GitLab CI/CD : autorisé.** Pipeline dans `.gitlab-ci.yml`.

Les exigences sont identiques ; ni bonus ni pénalité selon l'outil. Une Pull Request (GitHub) correspond à une Merge Request (GitLab).

## Organisation des dépôts et des branches

Le dépôt du formateur sert de **référence en lecture**. Chaque groupe travaille dans **son fork GitHub**. Toute Pull Request doit cibler la branche `main` **du fork du groupe**, et non `main` du formateur. Pour GitLab, travaillez dans votre projet de groupe et ciblez son `main` avec les Merge Requests. Une branche `develop` n’est pas requise. Les secrets et l’accès Azure sont à configurer sur le dépôt du groupe ; ils ne sont pas hérités du dépôt initial.

## Scénario de démonstration

1. À partir de la branche `main` **de votre dépôt de groupe**, créez une branche `feature/...`.
2. Modifiez une **question de quiz déjà présente dans le code** sans réécrire l'application.
3. Poussez la branche et ouvrez une Pull/Merge Request.
4. La CI exécute les vérifications et la construction des images nécessaires, puis lance **Trivy sur les images construites**.
5. Si Trivy trouve au moins une vulnérabilité **CRITICAL**, le job échoue (code de sortie non nul). Le contrôle doit être **obligatoire avant fusion** et ne doit pas être ignoré avec `continue-on-error` ou équivalent.
6. Après contrôle réussi et approbation, fusionnez dans **`main` de votre dépôt de groupe**.
7. Le workflow de déploiement publie des images identifiables dans **ACR**, puis met à jour le frontend et le backend dans **Azure Container Apps**.
8. Vérifiez l'exécution du pipeline et les nouvelles révisions. Si la base de données est opérationnelle, montrez également la question modifiée dans Quiz App.

## Précisions importantes

- **Ne déployez pas automatiquement les Pull/Merge Requests** dans l'environnement cible : le déploiement est déclenché après fusion dans `main`.
- Un simple rapport Trivy ne suffit pas : un contrôle critique doit échouer et être requis pour fusionner.
- Les fonctionnalités de protection des branches, de revue et de contrôles requis dépendent de la plateforme, de la visibilité du dépôt et du plan disponible. Documentez les éventuelles restrictions et les mesures mises en place ; le formateur examinera les preuves.
- Pour le cloud, authentifiez le pipeline avec une identité de service disposant du minimum de droits. Préférez OIDC lorsque disponible et autorisé ; sinon, protégez strictement les secrets CI/CD.
- Les secrets ne doivent ni apparaître dans les journaux ni être accessibles à du code non approuvé provenant de contributions externes.
- Le pipeline peut prouver la construction, la publication et la création d'une révision **sans PostgreSQL fonctionnel** ; cela ne prouve pas que l'application est pleinement opérationnelle.
- Utilisez des tags d'images traçables, par exemple basés sur le commit Git, plutôt que de vous fier uniquement à `latest`.

## Preuves attendues

Lien vers la PR/MR et son approbation, contrôle échoué puis réussi (par démonstration contrôlée et documentée), exécution de déploiement sur `main`, images ACR, révisions Container Apps et explication du fonctionnement.

**Ne créez pas intentionnellement une image dangereuse sur un registre partagé pour la démonstration.** Un scénario contrôlé de test du comportement bloquant suffit.
