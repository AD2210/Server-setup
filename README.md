# Server Setup

Outils d'installation, de configuration et de maintenance pour serveurs **Ubuntu Server LTS**.

Le projet permet de partir d'une instance VPS vierge et de configurer progressivement le serveur via une commande unique :

```bash
sudo setup <module>
```

Les scripts sont conçus pour être exécutés via l'orchestrateur `setup`, qui assure notamment les contrôles de privilèges, du système et de l'environnement avant l'exécution des modules.

---

# 1. Prérequis

## Serveur

* Ubuntu Server LTS
* accès SSH à un utilisateur disposant de `sudo`
* accès Internet
* Git

Le projet est prévu pour Ubuntu Server LTS uniquement.

## Clé SSH

Avant la première connexion, utiliser une clé SSH existante ou en générer une nouvelle depuis la machine d'administration :

```bash
ssh-keygen -t ed25519
```

Par exemple :

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

La clé publique doit être enregistrée auprès du fournisseur VPS ou ajoutée au serveur.

Ne jamais transférer la clé privée sur le serveur.

---

# 2. Connexion à l'instance vierge

Connexion standard :

```bash
ssh [USER]@[IP] -i [SSH_KEY]
```

Exemple :

```bash
ssh ubuntu@192.0.2.10 -i ~/.ssh/id_ed25519
```

Si un port SSH spécifique est utilisé :

```bash
ssh [USER]@[IP] -p [PORT] -i [SSH_KEY]
```

Exemple :

```bash
ssh ubuntu@192.0.2.10 -p 22 -i ~/.ssh/id_ed25519
```

Le port SSH par défaut est `22`. L'option `-p` est donc facultative tant que le serveur utilise ce port.

---

# 3. Préparation minimale du VPS

## Définir le hostname

```bash
sudo hostnamectl set-hostname [HOSTNAME]
```

Exemple :

```bash
sudo hostnamectl set-hostname vps-monitoring
```

Vérification :

```bash
hostnamectl
```

## Installer Git

Mettre à jour l'index APT puis installer Git :

```bash
sudo apt update
sudo apt install -y git
```

---

# 4. Installation de Server Setup

Le projet est installé dans :

```text
/opt/Server-setup
```

Se placer dans `/opt` :

```bash
cd /opt
```

Cloner le dépôt :

```bash
sudo git clone https://github.com/AD2210/Server-setup.git
```

Appliquer les droits :

```bash
sudo chown -R root:root /opt/Server-setup
sudo chmod 755 /opt/Server-setup
sudo chmod +x /opt/Server-setup/bin/setup
```

Créer la commande globale `setup` :

```bash
sudo ln -sfn /opt/Server-setup/bin/setup /usr/local/bin/setup
```

Vérifier :

```bash
setup
```

À partir de cette étape, tous les modules sont exécutés avec :

```bash
sudo setup <module>
```

---

# 5. Installation complète

Pour lancer l'ensemble des modules disponibles dans l'ordre prévu :

```bash
sudo setup all
```

Pour une première installation, il est néanmoins recommandé d'exécuter les modules individuellement afin de contrôler chaque étape :

```bash
sudo setup system
sudo setup security
sudo setup docker
sudo setup reverse-proxy
sudo setup backup
```

Cette méthode facilite les tests et permet de valider la configuration du serveur étape par étape.

---

# 6. Modules

## system

```bash
sudo setup system
```

Prépare le système de base.

Le module assure notamment :

* validation Ubuntu Server LTS ;
* mise à jour du système ;
* installation des paquets système requis ;
* préparation de l'environnement utilisé par les autres modules.

Les contrôles globaux de système et de privilèges sont effectués par l'orchestrateur `setup` afin d'éviter leur duplication dans chaque module.

---

## security

```bash
sudo setup security
```

Configure les éléments de sécurité du serveur.

Le module permet notamment de :

* créer l'utilisateur administrateur définitif ;
* lui attribuer les privilèges nécessaires ;
* conserver la clé SSH déjà utilisée pour l'accès initial ;
* préparer l'accès SSH sécurisé ;
* désactiver les accès SSH qui ne doivent plus être utilisés ;
* préparer la suppression de l'utilisateur initial fourni par le provider.

L'utilisateur administrateur est destiné aux opérations de :

* configuration ;
* administration ;
* déploiement ;
* accès SSH.

Le workflow est prévu pour fonctionner principalement par clé SSH afin de faciliter l'administration automatisée.

### Changement de session

L'utilisateur initial du provider peut encore posséder la session SSH active ayant lancé `setup security`.

Il ne peut donc pas toujours être supprimé immédiatement.

Après la configuration de l'utilisateur administrateur :

1. conserver la session SSH actuelle ouverte ;
2. ouvrir un second terminal ;
3. tester la connexion avec le nouvel utilisateur ;
4. vérifier son accès `sudo` ;
5. seulement ensuite supprimer l'utilisateur initial.

Exemple :

```bash
ssh [ADMIN_USER]@[IP] -i [SSH_KEY]
```

Puis :

```bash
sudo setup security-deluser
```

---

## security-deluser

```bash
sudo setup security-deluser
```

Supprime l'utilisateur initial du fournisseur VPS une fois la migration vers l'utilisateur administrateur validée.

Exemples d'utilisateurs initiaux :

```text
OVH   → ubuntu
IONOS → root / utilisateur fourni par l'image
```

Ce module doit être exécuté depuis la **nouvelle session administrateur**, et non depuis une session appartenant à l'utilisateur que l'on souhaite supprimer.

Avant son exécution, vérifier impérativement :

```bash
whoami
sudo -v
```

et tester une seconde connexion SSH.

---

## docker

```bash
sudo setup docker
```

Installe et configure Docker pour l'hébergement des applications.

Les applications sont organisées sous :

```text
/srv/apps
```

Une application suit typiquement la structure :

```text
/srv/apps/app1/
├── compose.yaml
├── .env
└── ...
```

Les volumes applicatifs sont gérés par Docker et les fichiers Compose propres à chaque application.

Les variantes Compose supportées par les outils du projet peuvent notamment inclure :

```text
compose.yaml
compose.yml
docker-compose.yaml
docker-compose.yml
compose.prod.yaml
compose.override.yml
...
```

Le projet ne fournit volontairement pas de template applicatif universel : les fichiers Compose restent sous la responsabilité de chaque application et de son pipeline de déploiement.

---

## reverse-proxy

```bash
sudo setup reverse-proxy
```

Configure une nouvelle application derrière Caddy.

Le Caddyfile global est centralisé dans :

```text
/etc/caddy/Caddyfile
```

Cette centralisation permet notamment :

* d'avoir une vue globale des domaines ;
* d'identifier les ports HTTP déjà utilisés ;
* d'éviter les collisions ;
* de gérer plusieurs endpoints pour une même application.

Le module demande :

* le nom de l'application ;
* un ou plusieurs domaines ;
* le port associé à chaque endpoint ;
* le service concerné.

Une application peut ainsi exposer plusieurs endpoints.

Exemple :

```text
app1
├── app.example.com → frontend → port 3000
└── api.example.com → backend  → port 8000
```

Le module contrôle notamment :

* les domaines déjà présents ;
* les ports déjà utilisés dans Caddy ;
* les doublons saisis pendant la configuration ;
* la présence de `/srv/apps` ;
* l'existence éventuelle du dossier applicatif ;
* la validité du Caddyfile avant application.

Les plages conseillées sont présentées à titre indicatif :

```text
Frontend : 3000-3999
API      : 8000-8999
Divers   : 9000+
```

Le module valide la nouvelle configuration Caddy avant son activation et évite de conserver une configuration invalide en cas d'échec.

Les ports PostgreSQL éventuellement détectés dans les environnements applicatifs sont affichés uniquement comme aide à l'administration et à la prévention des collisions. Ils ne sont pas publiés par le script.

---

# 7. Backup

```bash
sudo setup backup
```

Le module configure la stratégie de sauvegarde du serveur.

Il est découpé en étapes indépendantes afin de ne créer que les services réellement nécessaires.

## Workflow

L'ordre de configuration est :

```text
1. Dépendances
2. Configuration rclone
3. Sélection de la remote
4. Configuration PostgreSQL
5. Configuration des snapshots serveur
6. Politique de sauvegarde et timers
7. Installation des runtimes
8. Configuration systemd
9. Vérification finale
```

---

## Stockage distant avec rclone

Les sauvegardes distantes utilisent `rclone`.

Une remote existante peut être conservée.

Si aucune remote n'est disponible, l'assistant de configuration rclone est lancé.

La configuration est stockée sous :

```text
/etc/rclone/rclone.conf
```

avec des permissions réservées à `root`.

La remote sélectionnée est ensuite utilisée par les différents runtimes de sauvegarde.

Google Drive peut notamment être utilisé comme destination.

---

## Sauvegardes PostgreSQL

Le module demande :

```text
Configurer les sauvegardes PostgreSQL ? y/N
```

Si PostgreSQL n'est pas utilisé :

```text
DB_BACKUP_ENABLED=false
```

et aucun timer PostgreSQL n'est créé.

Plusieurs bases peuvent être configurées sur un même serveur.

Les cibles sont stockées sous :

```text
/etc/server-setup/backup/targets.d/
```

Une cible contient les informations nécessaires pour identifier :

* l'application ;
* son fichier Compose ;
* le service PostgreSQL ;
* les variables d'environnement utilisées par PostgreSQL.

Les mots de passe PostgreSQL ne sont pas dupliqués dans la configuration de backup.

Le runtime récupère les valeurs nécessaires depuis l'environnement du conteneur.

Les dumps sont réalisés avec `pg_dump`.

---

## Snapshots serveur

Les modes disponibles sont :

```text
none
logical
provider
both
```

### none

Aucun snapshot serveur.

```text
FILES_BACKUP_ENABLED=false
PROVIDER_BACKUP_ENABLED=false
```

### logical

Snapshot logique du serveur uniquement.

```text
FILES_BACKUP_ENABLED=true
PROVIDER_BACKUP_ENABLED=false
```

Le snapshot logique permet de sauvegarder les éléments nécessaires à la reconstruction du serveur, notamment :

```text
/etc
/opt/Server-setup
/srv/apps
```

Les caches, logs et données régénérables peuvent être exclus de l'archive.

### provider

Snapshot du VPS via le fournisseur uniquement.

```text
FILES_BACKUP_ENABLED=false
PROVIDER_BACKUP_ENABLED=true
```

### both

Combine snapshot logique et snapshot fournisseur.

```text
FILES_BACKUP_ENABLED=true
PROVIDER_BACKUP_ENABLED=true
```

---

## Providers snapshot

Les adaptateurs actuellement prévus sont :

```text
manual
ovh
ionos
```

### manual

Le snapshot est géré manuellement depuis le panel du fournisseur.

### OVHcloud

Le provider OVH utilise l'API OVHcloud.

Il nécessite :

```text
Application Key
Application Secret
Consumer Key
```

Pour les comptes européens, l'endpoint utilisé par défaut est :

```text
ovh-eu
```

La configuration est stockée sous :

```text
/etc/server-setup/backup/providers/ovh.conf
```

avec accès réservé à `root`.

Attention : la création de snapshots VPS via OVH nécessite que l'option Snapshot correspondante soit activée sur le VPS. Cette option peut être payante selon l'offre.

Si elle n'est pas utilisée, sélectionner `logical` ou `none` plutôt que d'activer le provider OVH.

### IONOS

Le support est prévu dans l'architecture mais l'adaptateur doit être finalisé avant utilisation en production.

---

# 8. Timers de sauvegarde

Les timers sont créés **uniquement pour les fonctionnalités activées**.

PostgreSQL :

```text
server-setup-backup-db.timer
```

Snapshot logique :

```text
server-setup-backup-files.timer
```

Snapshot provider :

```text
server-setup-backup-provider.timer
```

Exemple :

```bash
systemctl list-timers --all | grep server-setup
```

Si aucune base PostgreSQL n'est configurée, le timer DB n'est pas créé.

Si aucun snapshot logique n'est configuré, le timer fichiers n'est pas créé.

Si aucun provider n'est configuré, le timer provider n'est pas créé.

Les choix sont persistés dans :

```text
/etc/server-setup/backup/backup.conf
```

notamment via :

```text
DB_BACKUP_ENABLED
FILES_BACKUP_ENABLED
PROVIDER_BACKUP_ENABLED
PROVIDER_NAME
```

---

# 9. Test manuel des sauvegardes

Il est recommandé de tester chaque service activé avant de considérer la configuration terminée.

## PostgreSQL

```bash
sudo systemctl start server-setup-backup-db.service
```

Puis :

```bash
sudo systemctl status server-setup-backup-db.service
```

## Snapshot logique

```bash
sudo systemctl start server-setup-backup-files.service
```

Puis :

```bash
sudo systemctl status server-setup-backup-files.service
```

## Snapshot provider

Uniquement lorsqu'un provider fonctionnel est configuré :

```bash
sudo systemctl start server-setup-backup-provider.service
```

Puis :

```bash
sudo systemctl status server-setup-backup-provider.service
```

En cas d'erreur :

```bash
sudo journalctl -u server-setup-backup-provider.service -n 100 --no-pager
```

Le même principe peut être appliqué aux autres services de backup.

---

# 10. Services systemd

Lister les timers Server Setup :

```bash
systemctl list-timers --all | grep server-setup
```

Lister les services :

```bash
systemctl list-units --all | grep server-setup
```

Inspecter une unité :

```bash
systemctl status [UNIT]
```

Consulter ses logs :

```bash
journalctl -u [UNIT] -n 100 --no-pager
```

---

# 11. Caddy

Le fichier principal est :

```text
/etc/caddy/Caddyfile
```

Vérifier manuellement la configuration :

```bash
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Formater le fichier :

```bash
sudo caddy fmt --overwrite /etc/caddy/Caddyfile
```

Recharger Caddy :

```bash
sudo systemctl reload caddy
```

État du service :

```bash
sudo systemctl status caddy
```

Logs :

```bash
sudo journalctl -u caddy -n 100 --no-pager
```

Ports HTTP/HTTPS :

```bash
sudo ss -tlnp | grep -E ':(80|443)\\b'
```

---

# 12. Docker

Vérifier Docker :

```bash
sudo systemctl status docker
```

Version :

```bash
docker --version
docker compose version
```

Conteneurs actifs :

```bash
docker ps
```

Tous les conteneurs :

```bash
docker ps -a
```

Applications :

```text
/srv/apps/
```

Exemple d'exploitation :

```bash
cd /srv/apps/app1
docker compose ps
docker compose logs
```

---

# 13. Arborescence générale

Les principaux emplacements utilisés par Server Setup sont :

```text
/opt/Server-setup/
    dépôt et scripts d'installation

/usr/local/bin/setup
    point d'entrée global

/usr/local/lib/server-setup/
    runtimes installés

/etc/server-setup/
    configuration persistante

/etc/rclone/
    configuration rclone

/etc/caddy/Caddyfile
    reverse proxy global

/srv/apps/
    applications Docker

/var/lib/server-setup/
    états et environnements internes

/var/backups/server-setup/
    sauvegardes locales temporaires
```

---

# 14. Mise à jour de Server Setup

Le dépôt étant installé sous `/opt/Server-setup` :

```bash
cd /opt/Server-setup
sudo git pull
```

Les fichiers du dépôt restent détenus par `root`.

Après une mise à jour, vérifier si un module concerné doit être relancé pour réinstaller son runtime ou sa configuration :

```bash
sudo setup [MODULE]
```

Ne pas supposer qu'un `git pull` met automatiquement à jour les copies déjà installées sous `/usr/local/lib/server-setup`.

---

# 15. Diagnostic

## Vérification rapide

```bash
hostnamectl
```

```bash
systemctl --failed
```

```bash
systemctl list-timers --all | grep server-setup
```

```bash
docker ps
```

```bash
sudo systemctl status caddy
```

```bash
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

## Ports écoutés

```bash
sudo ss -tlnp
```

## Logs systemd

Pour une unité :

```bash
sudo journalctl -u [SERVICE] -n 100 --no-pager
```

Pour suivre les logs :

```bash
sudo journalctl -u [SERVICE] -f
```

---

# 16. Sécurité

Quelques règles importantes :

* ne jamais stocker de clé SSH privée dans le dépôt ;
* ne jamais versionner les `.env` applicatifs ;
* ne jamais versionner les credentials rclone ;
* ne jamais versionner les credentials API provider ;
* conserver les configurations sensibles accessibles uniquement à `root` ;
* tester la connexion du nouvel utilisateur avant de supprimer l'utilisateur initial ;
* conserver une session SSH fonctionnelle pendant les modifications SSH ;
* vérifier les sauvegardes par restauration, pas uniquement par présence des fichiers.

Les fichiers contenant des secrets doivent généralement utiliser :

```bash
chmod 600 [FILE]
```

et appartenir à :

```text
root:root
```

---

# 17. Déploiement des applications

Les applications sont déployées indépendamment de Server Setup.

Structure cible :

```text
/srv/apps/[APP]/
```

Le fichier Compose reste à la racine de l'application.

Exemple :

```text
/srv/apps/my-app/
├── compose.yaml
├── .env
└── ...
```

Les mises à jour applicatives peuvent être envoyées vers le serveur par le pipeline CI/CD, notamment via SCP/SSH.

Server Setup configure l'infrastructure du serveur mais ne remplace pas le pipeline de déploiement propre à l'application.

---

# 18. Monitoring / Healthcheck

Le monitoring et les healthchecks sont prévus sous la forme d'une stack adjacente dédiée.

Cette partie est actuellement maintenue séparément et sera intégrée à Server Setup une fois son fonctionnement finalisé.

Le futur module devra pouvoir s'intégrer à l'orchestrateur sans dupliquer les responsabilités des applications ou des services de backup.

---

# 19. Maintenance serveur

Server Setup prévoit également les fonctions de maintenance suivantes :

* rotation des logs ;
* mises à jour APT automatiques ;
* redémarrage périodique ;
* contrôles de finalisation ;
* monitoring / healthcheck.

La configuration exacte dépend de la version courante du dépôt et des modules activés.

Les tâches périodiques doivent rester gérées par systemd afin de pouvoir être contrôlées avec :

```bash
systemctl list-timers --all
```

---

# 20. Procédure recommandée sur un VPS vierge

Résumé complet :

```bash
# Depuis la machine d'administration
ssh-keygen -t ed25519

# Connexion au VPS
ssh [USER]@[IP] -i [SSH_KEY]

# Hostname
sudo hostnamectl set-hostname [HOSTNAME]

# Bootstrap minimum
sudo apt update
sudo apt install -y git

# Installation Server Setup
cd /opt
sudo git clone https://github.com/AD2210/Server-setup.git
sudo chown -R root:root /opt/Server-setup
sudo chmod 755 /opt/Server-setup
sudo chmod +x /opt/Server-setup/bin/setup
sudo ln -sfn /opt/Server-setup/bin/setup /usr/local/bin/setup

# Système
sudo setup system

# Sécurité / création administrateur
sudo setup security
```

À ce stade, ouvrir une **nouvelle session SSH avec le nouvel utilisateur administrateur**.

Puis :

```bash
# Suppression éventuelle de l'utilisateur initial
sudo setup security-deluser

# Docker
sudo setup docker

# Reverse proxy / application
sudo setup reverse-proxy

# Sauvegardes
sudo setup backup
```

Enfin :

```bash
systemctl --failed
systemctl list-timers --all | grep server-setup
docker ps
sudo systemctl status caddy
```

Tester manuellement chaque sauvegarde activée avant la mise en production.

---

# 21. Principe du projet

Server Setup cherche à conserver une séparation claire des responsabilités :

```text
setup
    ↓
contrôles globaux / orchestration
    ↓
modules
    ↓
étapes à responsabilité unique
    ↓
configuration persistante
    +
runtimes système
    ↓
systemd
```

Les modules doivent rester :

* lisibles ;
* idempotents autant que possible ;
* silencieux sur les commandes internes ;
* explicites dans leurs logs ;
* découpés par responsabilité ;
* réexécutables sans détruire une configuration valide ;
* indépendants des secrets applicatifs lorsque cela est possible.

L'objectif est de pouvoir reconstruire rapidement un serveur Ubuntu LTS tout en conservant une configuration compréhensible et maintenable.

