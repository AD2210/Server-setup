# Migration ITC : boost, data-suite et HP-Oscar

## Restauration SQL et releases — 15 octobre 2026

Les six domaines définitifs sont `boost`, `data-suite`, `hp-oscar` et leurs
équivalents `*-preprod`, sous `itcformation.fr`. Les domaines et fichiers Caddy
locaux sont alignés. Boost et Data-suite prod pointent déjà vers le VPS ; les
quatre autres domaines pointent encore vers le parking IONOS `217.160.0.170`
au dernier contrôle et nécessitent un enregistrement A vers `87.106.26.105`.

Les quatre bases Boost/Data-suite sont restaurées atomiquement depuis la capture
finale : 26 tables pour chacune des stacks Boost, 17 pour chacune des stacks
Data-suite. Les objets appartiennent au nouveau rôle applicatif `app` ; les
anciens mots de passe des rôles sauvegardés ne sont pas réappliqués. Les deux
bases HP-Oscar sont initialisées et attendent leurs migrations applicatives.
Les documents Data-suite sont restaurés et leurs 590 empreintes vérifiées
dans les deux environnements, sur deux dossiers indépendants.

Les projets Compose utilisent les vrais noms GitHub : `itc-{prod,preprod}`,
`itc-cfa-opco-{prod,preprod}` et `itc-hp-oscar-{prod,preprod}`. Des manifestes
runtime canoniques existent pour conserver ces identités lors de la première
CD. Les marqueurs de migration sont créés après validation SQL/documentaire.
Six cibles DB sont enregistrées ; timer actif et première sauvegarde distante
terminée avec code 0. Le runtime DB est verrouillé globalement pour empêcher
des sauvegardes concurrentes lors des déploiements des trois dépôts.

Les releases applicatives prévues sont `V1.0.4`, `V0.2.6` et `V0.2.4`.
Git Flow est aligné sur `main` et `develop`. Les workflows remplacent les
anciennes CD et séparent les builds preprod/prod puis la promotion manuelle.
Les workers démarrent après readiness PHP et migrations ; Mercure est lu
depuis son secret Docker, sans valeur stockée dans le manifeste ni le candidat.
Les apps Boost/Data-suite utilisent HTTP interne sur port 80 derrière Caddy.
Les réglages IDE locaux restent hors des commits de release.

Contrôles locaux : Boost 165 tests/991 assertions (deux notices, un test ignoré),
Data-suite 119 tests/907 assertions, HP-Oscar 25 tests/175 assertions avant le
dernier ajustement du rendu Mercure ; les tests de tooling mis à jour passent.
Composer, PHPStan, linters, YAML et Caddy sont validés. Aucun avis de sécurité
Composer sur les trois applications. L'authentification CLI GitHub reste à
finaliser pour mettre à jour les secrets SSH et piloter les promotions.

## État courant après réinstallation — 14 octobre 2026

Cette section remplace les états de préparation historiques ci-dessous. Après
l'interruption de la mise à niveau, le propriétaire a réinstallé le VPS IONOS
sur Ubuntu 26.04.1 LTS. Il a confirmé que les images seront reconstruites par la
CD : leur export et leur reconstruction avant réinstallation ne sont pas requis.
La capture finale de référence est `/home/andel/backup/itc/20261014T184129Z`,
empreintes vérifiées, avec 590 documents dont 585 PDF. La capture précédente
`20261014T182423Z` contient la preuve de restauration PostgreSQL 16 avec les
rôles, propriétaires et permissions (26 tables boost, 17 tables data-suite).
Les anciens services n'ont pas repris leurs écritures après la capture finale.

Le provisionnement du serveur neuf `87.106.26.105` est terminé et contrôlé :

- SSH port 55122, compte `admin-dsn`, clé locale `~/.ssh/admin-dsn-prod`, sudo sans
  mot de passe et groupe Docker. Root SSH, mots de passe et authentification
  interactive désactivés ; seule la méthode `publickey` est autorisée.
  Le compte `admin` créé initialement par erreur est désormais verrouillé, sans
  sudo, sans groupe Docker et sans accès SSH ; son ancien dossier est conservé.
- Empreinte d'hôte ED25519 vérifiée :
  `SHA256:/dNNu4Rwi9sp3zUDYJgTl+F0/4ltJGVhn4M/cuDoepA`.
- Source locale Server-setup installée dans `/opt/Server-setup`, configuration
  privée `/etc/server-setup/setup.conf`, commande `/usr/local/bin/setup`.
- Docker officiel 29.9.1, Compose v5.6.0, Caddy stable officiel 2.11.7,
  Make, jq, `server-release` et `server-api-config` installés.
- UFW actif : 55122/80/443 autorisés, port 22 fermé ; Fail2ban protège SSH et la récidive.
  La jail Caddy est désactivée car aucun filtre `caddy.conf` n'est fourni.
- Caddy global et snippets partagés installés ; aucun endpoint applicatif
  ajouté avant la restauration et les déploiements.
- Configuration rclone restaurée, sauvegarde logique et mises à jour de sécurité
  planifiées. Fuseau serveur UTC ; sauvegarde fichiers à 03 h et redémarrage
  hebdomadaire dimanche à 05 h UTC. Aucun redémarrage immédiat requis.
- Sauvegarde logique du système neuf `files-20261014T204954Z` terminée : SHA-256,
  lecture intégrale zstd/tar et comparaison avec téléchargement distant validés
  (trois fichiers identiques, aucune différence). Aucun service en échec.

Les applications et leurs données restent à restaurer et déployer. Le runtime
de sauvegarde PostgreSQL est installé mais refuse les appels tant que les cibles
ne sont pas enregistrées et activées ; aucun timer DB n'est actif sur ce serveur
sans bases. Créer les nouvelles stacks, restaurer boost prod et data-suite bêta
vers sa nouvelle production, restaurer les documents actifs, puis activer et
tester les sauvegardes DB avant les déploiements d'une stack existante. Installer
les secrets et l'inventaire commun des API avec leurs permissions, renseigner
les accès GitHub `admin-dsn`, port 55122 et nouvelle clé d'hôte, puis lancer CD et recette.

Les étapes interactives ont été remplacées par une configuration unattended :
`KEEP_RCLONE_CONFIG=true` et `RCLONE_REMOTE=gdrive` réutilisent le fichier rclone
de la capture finale (installé root-only dans `/etc/rclone/rclone.conf`), avec
accès distant et sauvegarde testés. `GHCR_ENABLED=false` signifie qu'aucun
`docker login` permanent ni jeton GHCR personnel n'a été configuré : la CD
utilise son `GITHUB_TOKEN` temporaire selon le contrat GitHub du template.

### Préparation des six dossiers applicatifs

Les dossiers suivants sont créés, appartenant à `admin-dsn`, avec accès ciblé
pour l'UID applicatif 33 aux secrets et aux vaults :

| Dossier | Base source sauvegardée | Vault runtime |
| --- | --- | --- |
| `/srv/apps/boost` | boost prod | `config/secrets/prod` |
| `/srv/apps/boost-preprod` | boost prod, copie privée de préparation | `config/secrets/prod` |
| `/srv/apps/data-suite` | data-suite bêta, future production | `config/secrets/prod` |
| `/srv/apps/data-suite-preprod` | data-suite bêta, copie privée de préparation | `config/secrets/prod` |
| `/srv/apps/hp-oscar` | aucune base existante | `config/secrets/prod` |
| `/srv/apps/hp-oscar-preprod` | aucune base existante | `config/secrets/preprod` |

Boost et Data-suite utilisent actuellement `APP_ENV=prod` dans leurs deux
stacks, donc leurs préproductions ont un vault `prod` distinct physiquement de
celui de la production. HP-Oscar utilise ses deux environnements Symfony.
Les env `.env`, `.env.<environnement>.local` et `.env.api.local` sont nettoyés :
secrets applicatifs, DSN SMTP avec identifiants et credentials d'API sont dans
les vaults ; aucun mot de passe PostgreSQL ni URL DB avec identifiants ne reste
dans ces fichiers. Les vues API publiques sont activées par `.public-only`.

Six mots de passe PostgreSQL distincts ont été générés. Les clés Mercure de
Boost et HP-Oscar sont nouvelles et distinctes ; Boost dispose aussi des secrets
Docker `invitation_jwt_secret` et `reset_password_jwt_secret`, cohérents avec
ses vaults. Les valeurs JWT et APP_SECRET de la production Boost sont conservées
pour ne pas invalider les liens existants ; ses valeurs de préproduction sont
distinctes. Les clés de décryptage HP-Oscar sont restaurées. Le mot de passe
Hyperplanning prod vide dans son ancien vault est remplacé par la valeur
existante de la sauvegarde Data-suite bêta, sans rotation côté fournisseur.

Les dumps et rôles sont dans `APP_PATH/backups`, root-only, sans restauration
SQL à ce stade. Le stockage actif Data-suite est restauré dans
`/srv/apps/data-suite/var/storage` : 590 fichiers, dont 585 PDF, toutes les
empreintes identiques à l'archive finale. La préproduction documentaire reste
vide. Les six configurations Compose sont validées ; les six vaults sont
déchiffrables dans les vrais montages Compose avec un conteneur PHP diagnostic
exécuté sous UID 33. Les ressources de diagnostic sont supprimées après test.
Aucune base, application ou release n'est démarrée et aucun `.migration-ready`
n'est créé avant restauration SQL et recette.

Les trois dépôts locaux ont les montages readonly des vaults et les secrets
Docker consommés au démarrage (Mercure/JWT pour Boost, Mercure pour HP-Oscar),
avec exclusion des clés privées des builds. Ces modifications ne sont pas
encore publiées. Les domaines de préproduction et le choix `o-hp`/`hp-oscar`
en production restent à confirmer avant la CD ; Data-suite préprod conserve
pour le moment son domaine placeholder du dépôt. Les fichiers Caddy applicatifs
devront être alignés avec les domaines confirmés avant publication.

L'état final préparé est sauvegardé dans le snapshot logique distant
`servers/itc-vps/files/20261014T212417Z` : service terminé avec code 0, SHA-256 et
flux zstd valides, trois fichiers identiques au stockage distant (aucune
différence). Une capsule privée locale à jour est conservée dans
`/home/andel/backup/itc/provision-20261014/application-provision-validated.tar.gz`
avec son empreinte ; utiliser cette capsule validée plutôt que la capture
initiale de préparation. Les contrôles de tooling HP-Oscar passent (10 tests,
130 assertions), ainsi que les tests du runtime API, la lecture Mercure/JWT par
les entrypoints, les six montages Compose sous UID 33 et les ACL d'isolation.

> **Audit direct du VPS, 14 octobre 2026 :** aucun snapshot/image IONOS n'est
> disponible dans le contrat du client. La protection retenue est une copie
> logique complète, des dumps PostgreSQL cohérents et une copie hors serveur,
> avec restauration testée. Cela ne donne pas un retour instantané à une image
> du VPS : la reconstruction du système et la restauration prendront plus de
> temps. Aucune bascule avant validation des portes G0 à G3.

Ce runbook prepare une migration du serveur et un redeploiement des trois
applications. **Aucune installation `setup`, modification de Compose, rotation
de secret, restauration en production ou bascule DNS ne commence tant que les
portes G0 a G3 ci-dessous ne sont pas prouvees.** Conserver les trois anciens
projets Compose et leurs volumes jusqu'a la recette finale.

Etat au 14 octobre 2026 : G0 est partiel (audit VPS en lecture seule effectué),
G1 est partiel (première copie hors serveur réalisée ; capture finale avec arrêt
des écritures et preuve complète de reprise encore requises), G2 est partiel
(secrets copiés dans l'archive de configuration, inventaire et rotation à faire),
G3 est partiel (restauration des deux bases testée localement ; reconstruction
complète des services à tester). Aucun serveur n'a été modifié par cet audit ou
ces sauvegardes et aucun déploiement production n'est autorisé à ce stade.

Première sauvegarde sur le poste opérateur :
`/home/andel/backup/itc/20261014T133807Z` (dossier `0700`, fichiers `0600`,
environ 560 Mio). Elle contient les dumps boost et data-suite, leurs rôles
PostgreSQL (`pg_dumpall --globals-only`), l'archive du
stockage documentaire actif (588 fichiers, dont 583 PDF), `/etc`, les deux
dossiers applicatifs hors documents, la configuration rclone, les quatre volumes
Caddy, un inventaire du VPS, `README.txt` et `SHA256SUMS`. Toutes les empreintes
ont été vérifiées sur le poste ; les deux dumps ont été restaurés dans un
PostgreSQL 16 local isolé (26 et 17 tables). Les documents ont été lus en entier
depuis l'archive. Cette copie a été prise **sans arrêt des écritures** : elle
n'est pas le point de transfert final commun aux bases et aux documents. Le
test de reconstruction de la configuration et le transfert final restent à faire.

Nouvelle capture complète après l'échec du timer de 20 h :
`/home/andel/backup/itc/20261014T182423Z` (environ 564 Mio). Les six conteneurs
PHP/messenger/scheduler ont été arrêtés pendant toute la capture, les deux
bases sont restées actives, puis les six conteneurs ont été redémarrés. Le
stockage actif contient 590 fichiers dont 585 PDF. Toutes les empreintes sont
valides ; les deux bases ont été restaurées avec leurs rôles, propriétaires et
permissions dans PostgreSQL 16 isolé (26 et 17 tables). Les PDF ont été lus
en entier depuis l'archive ; `RESTORE_CHECK.txt` conserve la preuve. Les huit
conteneurs sont sains après reprise. Les écritures ayant repris, un nouveau
point final sera nécessaire avant la bascule effective.

Correctifs de dépendances préparés localement pour les deux applications :
`composer audit --locked` ne signale plus d'avis de sécurité (avant mise à jour :
65 avis sur 21 paquets pour boost, 41 avis sur 14 paquets pour data-suite).
Symfony reste sur 7.4 pour boost et 8.0 pour data-suite. EasyAdmin, Twig, les
composants Symfony concernés et leurs dépendances sont corrigés ; Guzzle/JWT
sur boost et FPDI sur data-suite sont également mis à jour. Validation Composer
et PHPStan passent ; PHPUnit : boost 165 tests, 991 assertions, deux notices et
un test ignoré ; data-suite 119 tests, 907 assertions. Les fichiers Composer
doivent encore être publiés avant reconstruction des images ; les alertes
Dependabot GitHub seront réévaluées après publication.

## Etat de départ (audit local et VPS du 14 octobre 2026)

| Application | Source actuelle | Cible | Etat du code |
| --- | --- | --- | --- |
| boost | PostgreSQL production | nouvelle stack boost production | migration locale vers template V1.0.1 en cours, non deployee |
| data-suite | PostgreSQL beta et stockage `var/storage` | nouvelle stack data-suite production | migration locale vers template V1.0.1 en cours, non deployee |
| HP-Oscar | aucune stack active sur le VPS ; `/srv/app/o-hp` ne contient pas de données applicatives visibles | nouvelle stack connecteur production | proche du template Docker `V1.0.1` |

Le VPS actuel est Ubuntu 24.04.5, Docker 29.1.3 / Compose 2.29.7 ; le disque
racine de 232 Gio a environ 217 Gio libres lors de l'audit. Deux projets
Compose tournent : `boost` (`/srv/app/boost/compose.yaml` et
`compose.prod.yaml`) et `itc-cfa-opco-beta` (`/srv/app/data-suite/compose.yaml`).
Chaque projet a son PostgreSQL 16 et ses workers. Caddy écoute sur 80/443 ;
les applications sur 127.0.0.1:8081 et :8088. Les PostgreSQL écoutent
actuellement sur toutes les interfaces, ports 5432 et 5438 : fermer cette
exposition lors de l'alignement serveur, après avoir prévu l'accès admin via
SSH. HP-Oscar n'est pas encore déployé ici.

Les données à préserver sont notamment `boost_database_data`,
`itc-cfa-opco-beta_database_data` et le bind mount documentaire actif
`/srv/app/data-suite/var/storage` (555 Mio, 588 fichiers dont 583 PDF).
L'ancien volume `itc-cfa-opco-beta_app_storage` (177 Mio, 252 fichiers) n'est
plus monté. **Décision du propriétaire : seul le stockage actif est à reprendre** ;
l'ancien volume est exclu de la nouvelle sauvegarde et de la migration.
Le nom de base boost est `app` (utilisateur `itc_boost`) ; celui de data-suite
bêta est `data-suite_db` (utilisateur `itc`).

Sauvegardes réellement en place : `itc-db-backup-local.timer` exécute un
`pg_dump` gzip **de boost seulement** vers `/var/backups/db` ;
`itc-server-snapshot.timer` crée chaque semaine un tar sous
`/var/backups/snapshots` avec `/etc`, `/srv/app/boost` et
`/var/lib/docker/volumes`. Le tar inclut les données brutes des deux bases et
l'ancien volume documentaire, mais **exclut `/srv/app/data-suite` et donc le
stockage documentaire actif**. Une synchronisation rclone vers `gdrive:` est
active ; au moment de l'audit, 17 fichiers de dumps et 4 tar sont visibles dans
ses répertoires. Leur intégrité et leur restaurabilité restent à contrôler. Le tar des
volumes PostgreSQL en fonctionnement n'est pas une sauvegarde cohérente
garantie des bases. Les archives et dumps locaux sont sur le même VPS.

Les adaptations d'API ne constituent pas la migration des stacks boost et
data-suite. Leurs ports, volumes, workers, domaines, configurations Caddy et
integrations doivent etre compares au template avant publication. Le serveur
actuel, ses chemins `APP_PATH`, versions PostgreSQL, noms de projets Compose,
domaines et accès SSH sont à compléter en lecture seule.

Points de correspondance a figer avant de produire les nouveaux Compose :

| Sujet | boost actuel | data-suite actuelle | Condition de migration |
| --- | --- | --- | --- |
| HTTP | port local par defaut `8081` | port local par defaut `8088` | relever les ports reels et la configuration Caddy avant changement |
| DB | volume Compose `database_data`, PostgreSQL | volume Compose `database_data`, PostgreSQL | nouveau nom de projet = nouveau volume ; restaurer le dump plutot que rebrancher a l'aveugle |
| Fichiers | volumes Caddy et `/app/var` | bind mount `APP_STORAGE_HOST_PATH` | recopier et verifier les documents data-suite avec la DB correspondante |
| Workers | `messenger-worker`, `scheduler-worker` | `messenger-worker`, `scheduler-worker` | ne pas demarrer les jobs avant validation des donnees/API |
| Images | `app-php` et tags mutables `prod` | `itc-cfa-opco-php` et tags mutables `beta`/`prod` | figer les digests source, puis utiliser tags/digests valides du template |

Les ports ci-dessus ont été relevés sur le VPS. Le template retire l'exposition
directe PostgreSQL ; si un outil
d'administration depend du port hote, preparer son acces via SSH/Compose avant
la bascule. Ne pas changer les noms de projets Compose en pensant que leurs
volumes seront repris automatiquement.

## G0 — Inventaire et gel du changement

- Relever pour les trois applications les chemins et noms de projets Compose,
  images/digests en service, bases/versions PostgreSQL, volumes et bind mounts,
  domaines, ports, Caddy, workers, timers et webhooks. Ne jamais publier la
  sortie de `docker compose config` sans `--quiet` dans les logs CI : elle peut
  contenir les secrets des `env_file`.
- Verifier l'espace disponible sur le serveur et sur la destination de backup,
  ainsi que l'acces de lecture **et** d'ecriture au stockage hors serveur.
- Conserver les commits/tags exacts du code courant et des trois candidats.
  Laisser `ENABLE_DEPLOYMENT` absent ou different de `true` dans les depots
  boost, data-suite et HP-Oscar durant la preparation. **Une fois les changements
  de workflows publies**, leurs deploiements seront alors suspendus ; leur
  retour doit etre explicite apres recette, lorsque les nouvelles stacks et
  les sauvegardes sont pretes. Avant publication, verifier les workflows deja
  actifs sur GitHub et suspendre tout declencheur susceptible de modifier le VPS.
- La base data-suite beta est la seule source de donnees. La cible production
  sera creee neuve puis integralement remplacee par le dump final beta ; aucune
  fusion n'est prevue. Identifier le repertoire documentaire correspondant.

Preuve G0 : inventaire date, chemins et proprietaires des donnees, plan de
correspondance source/cible, version du template et fenetre de maintenance.

## G1 — Capture logique et sauvegardes indépendantes

1. Préparer une **capture logique complète** horodatée, indépendante des
   timers existants : `/etc`, `/srv/app/boost`, `/srv/app/data-suite`, les
   fichiers de déploiement, les volumes Docker utiles et un inventaire des
   paquets, services, ports, montages et règles réseau. Conserver les archives
   anciennes sans déclencher de purge. Si un clone bloc est souhaité, le faire
   uniquement depuis un environnement de secours ou un disque arrêté, puis
   tester son démarrage isolé ; une copie `dd` du disque racine actif ne prouve
   pas une restauration cohérente. Le clone reste facultatif si la capture
   logique, les dumps et le test de restauration ci-dessous sont validés.
2. Sauvegarder separement les bases **boost prod** et **data-suite beta** en
   format PostgreSQL custom (`pg_dump -Fc`) avec les versions serveur relevees.
   Il n'y a pas de base HP-Oscar active sur ce VPS à ce jour. Mettre les dumps dans
   un repertoire prive, calculer SHA-256, verifier `pg_restore --list` et copier
   les dumps hors serveur. Ne pas activer la retention/nettoyage pendant cette
   sauvegarde de migration.
   Dans `server-setup`, declarer `POSTGRES_PASSWORD_FILE` pour une base qui
   utilise un secret Docker par fichier, et `POSTGRES_PASSWORD` pour les stacks
   anciennes qui utilisent une variable directe.
3. Sauvegarder les donnees non-DB : stockage documentaire data-suite, dossiers
   applicatifs et Compose, configuration Caddy, `/etc/itc`, configuration
   `server-setup`, secrets Symfony/decrypt keys et inventaire des volumes.
   Verifier checksums et presence de la copie hors serveur. Pour data-suite,
   inventorier le chemin reel de `APP_STORAGE_HOST_PATH`, copier tout le contenu
   en conservant proprietaire, droits, liens et dates, puis enregistrer un
   manifeste SHA-256 des fichiers. Copier cette archive sur le poste operateur
   via le terminal SSH partage ; garder la meme generation que le dump beta.

Le tar hebdomadaire actuellement produit par les scripts de boost manque
`/srv/app/data-suite` et n'a pas de dump dédié data-suite. Ne pas le considérer
comme G1. L'archive documentaire doit couvrir le bind mount actif ; le volume
historique non monté est explicitement exclu. Les volumes PostgreSQL
ne doivent pas être copiés à chaud comme unique preuve de restauration.

Exemple de dumps **après vérification des chemins/projets et de l'espace libre**
(les variables ci-dessous sont à renseigner avec les valeurs du
serveur ; elles ne contiennent aucun mot de passe) :

```bash
set -euo pipefail
umask 077
install -d -m 700 "$EVIDENCE_DIR/db"
(
  cd "$BOOST_APP_PATH"
  docker compose --project-name "$BOOST_COMPOSE_PROJECT" --env-file .env.prod \
    -f compose.yaml -f compose.prod.yaml exec -T database \
    sh -lc 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc'
) > "$EVIDENCE_DIR/db/boost-prod.dump"
(
  cd "$DATA_SUITE_BETA_APP_PATH"
  docker compose --project-name "$DATA_SUITE_BETA_COMPOSE_PROJECT" \
    --env-file .env.beta -f compose.yaml exec -T database \
    sh -lc 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc'
) > "$EVIDENCE_DIR/db/data-suite-beta.dump"
test -s "$EVIDENCE_DIR/db/boost-prod.dump"
test -s "$EVIDENCE_DIR/db/data-suite-beta.dump"
pg_restore --list "$EVIDENCE_DIR/db/boost-prod.dump" >/dev/null
pg_restore --list "$EVIDENCE_DIR/db/data-suite-beta.dump" >/dev/null
(cd "$EVIDENCE_DIR/db" && sha256sum *.dump > SHA256SUMS)
```

`pg_restore --list` verifie la lisibilite du format, pas la restaurabilite des
donnees ; G3 impose donc une restauration complete et des controles metier.

La capture logique et les dumps protègent les éléments inventoriés, mais ne
recréent pas automatiquement un VPS démarrable. Un dump pris avant la fenêtre de
maintenance est une preuve de restauration, mais le transfert final necessite
un nouveau dump apres arret des ecritures.

Apres arret des ecritures beta, sauvegarder les documents data-suite a partir
du chemin **reel** releve dans `APP_STORAGE_HOST_PATH`. Exemple a adapter dans
le terminal partage (le parent et le nom doivent venir de l'inventaire, pas
d'une valeur supposee) :

```bash
set -euo pipefail
test -d "$DATA_SUITE_DOCUMENT_DIR"
DOC_PARENT="$(dirname "$DATA_SUITE_DOCUMENT_DIR")"
DOC_NAME="$(basename "$DATA_SUITE_DOCUMENT_DIR")"
tar -C "$DOC_PARENT" -cpf "$EVIDENCE_DIR/data-suite-documents.tar" "$DOC_NAME"
tar -tf "$EVIDENCE_DIR/data-suite-documents.tar" >/dev/null
sha256sum "$EVIDENCE_DIR/data-suite-documents.tar" > "$EVIDENCE_DIR/data-suite-documents.tar.sha256"
```

Copier le dump beta, l'archive et leurs fichiers SHA-256 sur le poste operateur,
puis verifier les empreintes sur ce poste. Restaurer l'archive dans un dossier
isole pour G3 et comparer un echantillon de documents aux references SQL. Lors
de la bascule, restaurer d'abord dans un dossier de staging, puis recopier le
contenu avec proprietaires et droits conserves vers le bind mount absolu de la
nouvelle stack ; ne pas extraire l'archive directement sur l'ancien stockage.

Preuve G1 : horodatage, manifestes des chemins couverts, dumps des deux bases,
archive du stockage documentaire actif, empreintes contrôlées sur le poste
opérateur et espace suffisant pour la restauration. Vérifier aussi le contenu
de `gdrive:` et conserver une copie indépendante de la synchronisation rclone,
qui peut propager les suppressions locales.

## G2 — Secrets et acces aux bases

- Inventorier hors logs les valeurs actuellement utilisees par boost
  (`.env.prod`, Oscar, secrets DB), data-suite (`.env.beta`, autres API,
  stockage, secrets DB) et HP-Oscar (Symfony Secrets, cles privees, secrets DB).
  Un ancien secret dans Git doit etre considere expose et planifie pour rotation.
- Copier les secrets necessaires a la restauration dans un coffre chiffre
  accessible aux operateurs de reprise, avec droits limites. Verifier que la
  copie est lisible **avant** de changer les anciens identifiants. Ne jamais
  mettre ces valeurs dans un ticket, log CI ou ce depot.
- Tester la connexion SQL en lecture seule avec les identifiants actuels sur
  boost prod et data-suite beta. Garder cet acces et une voie d'administration
  PostgreSQL durant la migration. Faire tourner les secrets API exposes apres
  sauvegarde et validation de leurs nouvelles valeurs. La rotation DB vient
  apres restauration/recette avec un chemin de retour documente ; elle ne doit
  pas couper l'acces aux anciennes bases.
- Preparer l'inventaire commun
  `/etc/server-setup/api-config/<client>/<environnement>/` et ses trois vues
  `APP_PATH/.env.api.local` via `server-api-config`. Les autres API de data-suite
  restent propres a l'application. Pour Hyperplanning 2026-2027, WSDL et SOAP
  sont sur le port 81. Garder les synchronisations et webhooks inactifs pendant
  le test de restauration et jusqu'a la verification de la base annuelle.

Preuve G2 : liste des emplacements et proprietaires (sans valeurs), test de
lecture du coffre, tests SQL, plan de rotation et de retour arriere.

## G3 — Restauration de validation, hors production

1. Restaurer les dumps **depuis la copie hors serveur** dans une instance
   PostgreSQL isolee, de meme version majeure que chaque source. La cible de
   test ne doit pas etre reliee aux applications en production.
2. Verifier `pg_restore --list`, fin de `pg_restore` sans erreur, contraintes,
   tables, tailles et comptes des entites cles. Comparer avec les mesures
   relevees sur les sources au moment du dump. Sur data-suite, verifier aussi
   un echantillon de documents dans le stockage restaure et leurs references
   SQL, puis comparer le manifeste SHA-256 et les droits. Aucun webhook, email
   ou appel API sortant ne doit partir de cet essai.
3. Extraire la capture logique dans un dossier de staging sans écraser `/etc`
   ni `/srv/app`. Vérifier la présence des deux projets, configurations serveur,
   secrets sauvegardés et volumes attendus. Recréer dans un environnement isolé
   les services nécessaires ; documenter le temps réel de reconstruction.
4. Conserver le compte rendu, les commandes utilisees et les checksums.

Preuve G3 : journal de restauration isolee, ecarts expliques, documents
verifies et procedure de retour arriere exercee. **Sans G3 vert, ne pas
migrer le serveur.**

## Apres G3 — Migration et deploiement

1. Finaliser boost et data-suite sur le template Docker choisi et exiger leurs
   validations locales/CI. Sur le serveur, appliquer `server-setup` par modules
   controles en preservant SSH, pare-feu, Caddy, noms Compose, volumes et
   sauvegardes en place ; ne pas lancer `setup all` aveuglement sur le VPS actif.
2. Installer `server-release` et `server-api-config`, creer les secrets root
   sous `/etc/server-setup`, puis produire les vues limitees aux trois apps.
   Verifier les permissions et l'absence de secrets dans les manifestes Compose
   et les journaux CI.
3. Ouvrir la maintenance, arreter ecritures/schedulers/webhooks, effectuer des
   **dumps finaux** boost prod et data-suite beta et sauvegarder les fichiers
   modifies depuis G1. Verifier leurs checksums et une restauration rapide de
   controle dans la cible isolee.
4. Restaurer boost prod dans sa nouvelle base. Creer la nouvelle base data-suite
   production, y restaurer **integralement** le dump final beta et restaurer
   ensemble les documents du meme point de sauvegarde dans le bind mount absolu
   `APP_STORAGE_HOST_PATH`. Verifier checksums, droits de lecture/telechargement
   depuis l'application et correspondance des references SQL. Executer les
   migrations applicatives seulement sur une copie ou
   une cible sauvegardee, avec controle des differences de schema et donnees.
5. Apres ces controles, poser `.migration-ready` dans les nouveaux dossiers
   boost et data-suite. La premiere release de ces deux applications refuse de
   demarrer sans ce marqueur ; celle de data-suite exige aussi un stockage
   documentaire de production absolu et non vide. Deployer les trois images
   depuis des tags/digests valides. Lancer en premier
   les bases, puis les applications, puis les workers/schedulers. Tester sante,
   acces DB, parcours metier, API Oscar et Hyperplanning, dates de la base HP,
   puis remettre les jobs et le trafic progressivement.

La configuration Caddy data-suite dans le depot contient des domaines
`example.invalid` temporaires. Renseigner les domaines effectivement inventaries,
les URL `APP_URL` et les ports avant d'activer les workflows de release.
6. Conserver l'ancien environnement et les dumps finaux jusqu'a la recette.
   En cas d'echec avant nouvelles ecritures, revenir aux anciens services et
   routages. Apres de nouvelles ecritures, ne pas restaurer un vieux dump sans
   traiter les donnees produites pendant la fenetre.

`setup restore` peut recharger une release precedente, mais ce rechargement ne
restaure pas un schema PostgreSQL modifie : conserver les dumps et le plan de
retour des donnees separement.

La mise en production n'est complete qu'apres preuve des trois applications,
des donnees boost prod et data-suite beta, des fichiers associes, des trois
configurations API et des sauvegardes de la nouvelle plateforme.

## Fenêtre du 14 octobre 2026 à 20 h (Europe/Paris)

Intervention en cours : console IONOS confirmée par l'opérateur. Capture de
maintenance `/home/andel/backup/itc/20261014T184129Z` créée avec les six services
applicatifs arrêtés ; restauration des deux bases/rôles validée. Les huit
conteneurs sont maintenant arrêtés et leur redémarrage automatique suspendu.
Leurs politiques d'origine sont dans `/root/itc-maintenance-20261014.tsv` ;
`/root/itc-maintenance-restore.sh` permettra la reprise après validation.
Les 23 mises à jour 24.04 sont terminées, puis un premier redémarrage a réussi
sur le noyau `6.8.0-147`. `do-release-upgrade` vers 26.04.1 a démarré dans la
session tmux root `itc-release-upgrade` (660 mises à jour, 113 nouveaux paquets,
4 suppressions sans impact sur les applications). Pendant l'installation,
SSH 55122 et 22 ont cessé d'écouter ; HTTPS répond toujours. L'opérateur doit
relancer SSH depuis la console avant poursuite du contrôle interactif.
La fin de la mise à niveau et le second redémarrage ne sont pas encore attestés.
Les modules de provisionnement n'ont pas encore été exécutés.
Les ajouts Caddy partagé/Make/jq et les ajustements de backup sont préparés
localement ; réinstaller l'archive source courante avant le provisionnement.

Préparation du provisionnement réalisée après la sauvegarde complète : source
validée de `server-setup` installée sous `/opt/Server-setup`, commande `setup`
installée et configuration privée `/etc/server-setup/setup.conf` préparée.
Compte `admin` créé avec les clés SSH existantes ; connexion indépendante sur
55122 et `sudo -n` testés. L'accès root et les huit conteneurs restent actifs.
La sauvegarde locale contient désormais `admin-access.tar.gz` (SSH/Docker root).
Ubuntu est encore en 24.04.5 ; `do-release-upgrade -c` propose 26.04.1 et un
redémarrage était déjà requis avant l'intervention. Les paquets n'ont pas encore
été mis à niveau : seul l'index APT a été actualisé. La réponse sur l'accès à
la console IONOS hors SSH est attendue avant le premier redémarrage.

Les corrections préparées et copiées couvrent les clés de configuration
non interactives admin/SSH/backups, le booléen `false`, la priorité des options
SSH sur cloud-init, la réutilisation d'un groupe admin existant, la validation
Docker sans Python et l'inclusion des anciens chemins `/srv/app` dans les
sauvegardes. Les cibles DB devront préciser le projet Compose, notamment
`itc-cfa-opco-beta` ; le runtime le prend maintenant en charge.

Une tâche systemd **sur le poste opérateur** lance à 20 h
`scripts/backup-itc-migration-to-workstation.sh` et écrit une nouvelle copie
datée dans `~/backup/itc`. La tâche ne touche pas au VPS en écriture et ne
gèle pas les applications. Le poste doit rester allumé et connecté ; vérifier
le résultat avec `systemctl --user status itc-migration-backup-20261014.service`
et `journalctl --user -u itc-migration-backup-20261014.service`. Ne pas
assimiler cette copie à la capture finale synchronisée. Le timer ne lance
**ni** `do-release-upgrade` **ni** les déploiements : la mise à niveau Ubuntu
demande un suivi interactif.

Déroulé dans le terminal partagé, après contrôle de la tâche de 20 h :

1. Vérifier les variables et secrets des trois dépôts, les noms de domaine,
   les tags/digests d'images et les commits publiés. Les migrations du template
   et `server-setup` comportent encore des changements locaux non publiés au
   moment de la préparation ; ne déployer que les versions réellement validées.
   Vérifier l'accès à la console IONOS hors SSH, un second accès SSH sur le
   port 55122 et l'espace disque. Consigner l'heure de début d'indisponibilité.
2. Mettre les deux applications en maintenance, couper webhooks et tâches
   planifiées, arrêter `php`, `messenger-worker` et `scheduler-worker` dans
   les deux projets Compose tout en gardant les bases actives. Vérifier
   l'absence de nouvelles écritures. Relancer la sauvegarde depuis le poste :
   cette **seconde capture**, avec applications arrêtées, est le point commun
   de reprise pour les deux bases et les documents. Vérifier ses empreintes,
   restaurer les dumps isolément et contrôler les PDF. Garder l'ancien état
   disponible jusqu'à la recette.
3. Dans une session persistante (`tmux`/console), mettre Ubuntu 24.04 à jour,
   examiner les paquets et dépôts tiers, puis lancer `do-release-upgrade` vers
   26.04.1. Répondre aux questions sur SSH et les fichiers de configuration
   en comparant les différences ; redémarrer et confirmer version, SSH 55122,
   pare-feu, Docker, Compose, Caddy et volumes. Si la console hors bande ou la
   restauration ne sont pas prêtes, reporter cette étape.
4. Appliquer `server-setup` module par module sur le système rétabli, en
   préservant SSH et les anciennes stacks. Installer `server-release` et
   `server-api-config`, créer l'inventaire commun des API et les vues limitées
   des trois applications. Fermer l'exposition publique des ports PostgreSQL
   après validation de l'accès administrateur via SSH.
5. Déployer les trois stacks issues du template à partir de tags/digests
   vérifiés. Restaurer boost prod et créer data-suite production depuis le dump
   bêta final, puis restaurer uniquement le stockage documentaire actif. Poser
   `.migration-ready` après validation de ces données. Déployer HP-Oscar et
   fournir ses secrets/API ; la promotion Hyperplanning reste optionnelle.
6. Tester santé HTTP, Caddy/TLS, connexion et comptes SQL, lecture de PDF,
   parcours métier, API Oscar/Hyperplanning, accès depuis le client et jobs
   désactivés. Réactiver progressivement les workers et le trafic seulement
   après recette. Tester les nouvelles sauvegardes et noter les écarts.

L'upgrade du système et la bascule ne sont pas des étapes cron : elles peuvent
demander des décisions humaines et un retour par console. En cas d'échec avant
de nouvelles écritures, remettre les anciens Compose et routages en service ;
si l'OS ne démarre plus, reconstruire depuis les sauvegardes du poste sur un
VPS de remplacement. Cette voie de reprise est plus lente qu'une image IONOS.
