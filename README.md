# Famille Budget

Application Android (Flutter) : revenus, dépenses, comptes, transferts, bilans jour/mois/année,
PIN par membre, fusion des téléphones par fichier (WhatsApp), export CSV. 100 % hors ligne.

## Obtenir l'APK gratuitement (sans installer Flutter)

1. Créez un compte gratuit sur https://github.com
2. Créez un dépôt **privé** « famille-budget ».
3. Envoyez-y tout le contenu de ce dossier (bouton « Add file » > « Upload files »).
   Le dossier caché `.github/workflows/build.yml` doit être inclus.
4. Onglet **Actions** > « Construire l'APK » > **Run workflow**. Attendez 6 à 10 minutes.
5. Ouvrez l'exécution terminée, section **Artifacts** :
   - `FamilleBudget-APK` : le fichier à installer (dans un .zip, à extraire).
   - `CLE-DE-SIGNATURE-A-CONSERVER` : la clé de signature. Téléchargez-la et copiez-la à plusieurs endroits.
     Sans elle, une future mise à jour ne pourra pas s'installer par-dessus l'ancienne.

## Installer sur plusieurs téléphones

Envoyez `app-release.apk` par WhatsApp, Bluetooth ou câble, ouvrez-le, autorisez « Sources inconnues »
(Réglages > Sécurité), puis installez. Aucun Google Play, aucun frais.

## Réunir les données de plusieurs téléphones

Réglages > Sauvegarde et partage > « Envoyer mes données » (WhatsApp), puis « Importer un fichier » sur l'autre téléphone.

## Compiler sur un PC (option)

    flutter create --platforms=android --org mg.raoliarison --project-name famille_budget .
    flutter pub get
    flutter build apk --release
