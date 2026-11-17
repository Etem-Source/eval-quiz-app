# Preuves J2 – Sécurité des images (17/11/2026)

Outil : Trivy (image `aquasec/trivy:latest`), scanner `vuln`, sévérités HIGH/CRITICAL.

## Résultats

| Image | Avant | Après |
|---|---|---|
| Frontend | 13 (12 HIGH, 1 CRITICAL `brotli-libs`) – OS uniquement | **0** |
| Backend – OS | 7 HIGH (openssl, musl, zlib) | ? |
| Backend – Node | 22 (21 HIGH, 1 CRITICAL `tar`) | ? |

Rapports complets : `01-avant-*.txt` et `02-apres-*.txt`.

## Analyse et corrections

1. **Les dépendances de l'application sont saines** : express, pg, resend… n'ont aucune faille HIGH/CRITICAL.
2. **Les 22 failles Node venaient de npm**, livré dans `node:20-alpine` (`/usr/local/lib/node_modules/npm`). npm sert uniquement à installer les dépendances au build, pas à exécuter l'application. **Correction** : suppression de npm/npx de l'image finale après `npm install`.
3. **Les failles OS (Alpine) avaient toutes un correctif publié** (statut `fixed`). **Correction** : `apk upgrade --no-cache` dans les deux images. Côté frontend, on passe temporairement en `root` pour la mise à jour, puis on revient à l'utilisateur non-root `101`.

Mesures déjà en place depuis J1 : images Alpine minimales, utilisateurs non-root, multi-stage (le frontend final ne contient ni Node ni le code source).

## Vulnérabilités résiduelles

(À compléter : « aucune HIGH/CRITICAL », ou la liste des failles sans correctif publié et la justification.)

## Commandes utilisées

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $trivy = "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ aquasec/trivy:latest"
    iex "$trivy image --scanners vuln --severity HIGH,CRITICAL <image>"