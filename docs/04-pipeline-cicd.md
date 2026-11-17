# 04 - Exigences CI/CD

## Plateforme au choix

- **GitHub Actions : recommandé.** Workflow dans `.github/workflows/`.
- **GitLab CI/CD : autorisé.** Pipeline dans `.gitlab-ci.yml`.

Les exigences sont identiques ; ni bonus ni pénalité selon l'outil. Une Pull Request (GitHub) correspond à une Merge Request (GitLab).

## Organisation des dépôts et des branches

Le dépôt du formateur sert de **référence en lecture**. Chaque groupe travaille dans **son fork GitHub**. Toute Pull Request doit cibler la branche `main` **du fork du groupe**, et non `main` du formateur. Pour GitLab, travaillez dans votre projet de groupe et ciblez son `main` avec les Merge Requests. Une branche `develop` n’est pas requise. Les secrets et l’accès Azure sont à configurer sur le dépôt du groupe ; ils ne sont pas hérités du dépôt initial.

## Procédure GitHub — protéger `main` et créer une Pull Request

Cette procédure se réalise **dans le fork de votre groupe**, jamais dans le dépôt du formateur.

### A. Créer et vérifier votre fork

1. Ouvrez le [dépôt de référence](https://github.com/franklin-tutorials/eval-quiz-app), puis cliquez sur **Fork** > **Create a new fork**.
2. Vérifiez que votre fork appartient à votre compte ou à votre organisation de groupe et possède une branche `main`.
3. Dans **Settings** > **General** (rubrique **Pull Requests**, si elle est présente), vérifiez qu'au moins une méthode de fusion est activée. Chaque membre qui doit contribuer doit avoir les droits nécessaires sur le fork.

### B. Protéger la branche `main` de votre fork

1. Dans **votre fork** : **Settings** > **Branches** > **Add branch protection rule** (ou **Settings** > **Rules** > **Rulesets** > **New branch ruleset**, selon l'interface et les droits disponibles).
2. Ciblez exactement la branche `main`.
3. Activez **Require a pull request before merging**. Si la revue obligatoire est disponible et qu'un autre membre a les permissions requises, demandez une approbation. Vous pouvez également activer **Require conversation resolution before merging**.
4. N'autorisez ni la suppression de `main` ni les **force pushes**. Enregistrez et vérifiez que la règle est **active** (une règle en mode évaluation seule n'empêche pas la fusion).
5. **Après la première exécution réussie du workflow CI**, activez **Require status checks to pass before merging** et sélectionnez les contrôles de build et de scan Trivy réellement publiés par le workflow. Ne devinez pas le nom des contrôles et ne définissez pas un contrôle absent, ce qui pourrait bloquer toute fusion.

Les possibilités d'application effective des règles dépendent du **plan GitHub**, de la visibilité du fork, de son propriétaire et des droits du groupe. Si une règle ne peut pas être appliquée sur votre fork, **ne prétendez pas qu'elle est active** : documentez la restriction et montrez les contrôles réellement obtenus. Une règle affichée dans l'interface n'est pas à elle seule la preuve qu'elle bloque les actions.

### C. Créer une PR vers votre propre fork

1. Sur `main` de **votre fork**, créez `feature/test-pr` (par exemple une petite modification d'un fichier Markdown).
2. Poussez cette branche sur **votre fork**.
3. Ouvrez **Pull requests** > **New pull request** et vérifiez **avant de créer la PR** :
   - **Base repository** : dépôt de **votre groupe**, et **Base** : `main`.
   - **Head repository** : dépôt de **votre groupe**, et **Compare** : `feature/test-pr`.
4. Créez la PR et consultez les contrôles CI. Corrigez les échecs, faites approuver la PR si une approbation est requise, puis fusionnez uniquement lorsque les conditions obligatoires sont satisfaites.
5. Vérifiez que le changement apparaît sur `main` **de votre fork**. N'ouvrez **aucune PR vers `franklin-tutorials/eval-quiz-app`**.

### D. Vérifier que la protection fonctionne réellement

- Tentez de pousser une petite modification directement sur `main` **sans forcer** et sans modifier l'historique ; si la protection est effectivement appliquée à votre compte, l'opération doit être refusée. Ne réalisez pas ce test si vous avez des modifications non sauvegardées.
- Montrez qu'une PR peut être créée, que les contrôles requis s'exécutent et qu'une CI en échec empêche la fusion.
- Fournissez des captures ou liens **sans secrets** : règle de protection active, PR vers votre fork, résultat des vérifications, puis fusion.
- Si votre plateforme ou votre offre ne permet pas d'imposer toutes ces restrictions, signalez-le explicitement et présentez la mesure alternative choisie.

**Variante GitLab :** appliquez la même logique avec branches protégées, Merge Requests, pipelines obligatoires et approbations, selon les capacités disponibles sur votre projet GitLab.

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
