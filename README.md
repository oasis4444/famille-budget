# Famille Budget

Application multi-appareils (Android, Windows, macOS, Linux) : revenus, dépenses, comptes,
transferts, bilans jour/mois/année, PIN par membre, **stock de riz**, et une **synchronisation
automatique** entre tous les appareils du foyer — **sans rien installer à part l'application
elle-même**. 100 % utilisable hors ligne : la synchronisation est un plus, jamais une obligation.

## Nouveau : synchronisation multi-appareils, sans serveur à installer

- L'application se construit pour **Android, Windows, macOS et Linux**.
- Un appareil « héberge » le foyer (un petit serveur tourne à l'intérieur même de l'application,
  démarré en un clic — téléphone, tablette ou PC, au choix), les autres le rejoignent. Tous les
  appareils doivent être sur le **même réseau Wi-Fi**.
- **Appairage par QR code** : Réglages > Appareils et synchronisation > « Héberger notre foyer »
  sur un appareil, puis « Rejoindre un foyer » (scanner le code, ou le copier/coller sur un PC
  sans caméra) sur chaque autre appareil.
- Dès qu'une opération est ajoutée ou modifiée quelque part, elle apparaît automatiquement partout
  ailleurs, tant que le Wi-Fi est disponible. Hors Wi-Fi ou appareil hôte éteint, chaque appareil
  continue de fonctionner normalement ; les changements sont envoyés dès que la connexion revient.
- Le partage par fichier WhatsApp (Réglages > Sauvegarde et partage) reste disponible en
  complément, pour un transfert ponctuel même sans Wi-Fi commun.

**Important à savoir :** ce n'est plus l'appli « PocketBase » demandée au départ, mais un petit
serveur équivalent écrit directement dans l'application. Le vrai PocketBase, pour fonctionner de
façon fiable sur téléphone Android, aurait demandé d'embarquer un programme externe que je n'ai
aucun moyen de tester ici — risque jugé trop élevé pour une version livrée sans essai préalable.
Cette solution maison vise le même résultat (sync automatique, aucune installation séparée,
fonctionne sur les quatre plateformes) avec une mise en œuvre plus simple à corriger si un problème
apparaît à la compilation.

## Sauvegarde des données

- **Chaque appareil relié au foyer garde une copie complète** de toutes les données (c'est le
  principe même de la synchronisation) : perdre un appareil ne fait pas perdre l'historique tant
  qu'un autre appareil relié existe encore.
- **Sauvegarde automatique locale** : en plus, chaque appareil écrit une copie complète une fois
  par jour dans son propre dossier de données (conservée 14 jours), sans rien demander à
  l'utilisateur.
- **Envoi manuel** : le bouton « Envoyer mes données » (Réglages > Sauvegarde et partage) ouvre le
  menu de partage de l'appareil, qui propose aussi bien WhatsApp que l'e-mail — pratique pour
  garder une copie chez un parent en dehors de la maison.

## Stock de riz

- Onglet « Stock de riz » : quantité actuelle en kg, seuil d'alerte (modifiable par un parent),
  historique des entrées et sorties.
- Boutons « Entrée » (achat, don reçu...) et « Sortie » (cuisiné, donné, perdu...) avec date et note.
- Quand une dépense est enregistrée dans **Alimentation > Riz**, l'application propose d'ajouter
  automatiquement la quantité achetée au stock (évite la double saisie).
- Tous les membres peuvent consulter et ajouter des mouvements ; seul un parent peut supprimer un
  mouvement ou changer le seuil d'alerte.

## Obtenir les applications gratuitement (sans installer Flutter)

1. Créez un compte gratuit sur https://github.com
2. Créez un dépôt **privé** « famille-budget ».
3. Envoyez-y tout le contenu de ce dossier, y compris le dossier caché `.github`.
4. Onglet **Actions** > « Construire les applications » > **Run workflow**. Quatre constructions
   se lancent en parallèle (Android, Windows, macOS, Linux) ; comptez 10 à 20 minutes.
5. Ouvrez l'exécution terminée, section **Artifacts** :
   - `FamilleBudget-Android` : le fichier .apk à installer sur téléphone/tablette.
   - `FamilleBudget-Windows`, `FamilleBudget-macOS`, `FamilleBudget-Linux` : l'application pour
     chaque PC (dossier à extraire, puis lancer l'exécutable à l'intérieur).
   - `CLE-DE-SIGNATURE-A-CONSERVER` : la clé de signature Android. Téléchargez-la et copiez-la à
     plusieurs endroits — sans elle, une future mise à jour Android ne pourra pas s'installer
     par-dessus l'ancienne.

Les quatre constructions sont indépendantes : si l'une échoue, les autres peuvent quand même
réussir. En cas d'erreur, envoyez-moi le message affiché dans Actions et je corrige celle-là sans
toucher aux autres — cette fonctionnalité de synchronisation n'a pu être ni compilée ni testée
dans mon environnement (aucun Flutter disponible ici), donc un ou deux allers-retours sont probables,
comme pour les étapes précédentes.

## Installer sur plusieurs téléphones

Envoyez `app-release.apk` par WhatsApp, Bluetooth ou câble, ouvrez-le, autorisez « Sources inconnues »
(Réglages > Sécurité), puis installez. Aucun Google Play, aucun frais.

## Réunir les données sans Wi-Fi commun (transfert ponctuel)

Réglages > Sauvegarde et partage > « Envoyer mes données » (WhatsApp ou e-mail), puis « Importer
un fichier » sur l'autre appareil.

## Compiler sur un PC (option)

    flutter create --platforms=android,windows,macos,linux --org mg.raoliarison --project-name famille_budget .
    flutter pub get
    flutter build apk --release      # ou : windows / macos / linux
