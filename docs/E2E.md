# Checklist de test E2E

Cette checklist doit être exécutée sur une Ubuntu de test avec une sauvegarde
réelle et une application de démonstration.

## Préparation

- [ ] vérifier Ubuntu LTS, accès SSH et sudo ;
- [ ] vérifier l'installation de Server Setup ;
- [ ] préparer le fichier `setup.conf` ;
- [ ] préparer le fichier de secrets avec les credentials nécessaires ;
- [ ] vérifier que les fichiers rclone et les cibles PostgreSQL sont présents ;
- [ ] conserver une session SSH de secours pendant les tests sécurité/Caddy.

## Installation

- [ ] exécuter `sudo setup system` ;
- [ ] exécuter `sudo setup security` ;
- [ ] vérifier une nouvelle connexion SSH ;
- [ ] exécuter `sudo setup docker` ;
- [ ] exécuter `sudo setup reverse-proxy` ;
- [ ] vérifier `/etc/caddy/Caddyfile`, `snippets/` et `apps/` ;
- [ ] exécuter `sudo setup backup` ;
- [ ] exécuter `sudo setup monitoring` ;
- [ ] exécuter `sudo setup finalize`.

## Caddy et CD

- [ ] déposer un fichier applicatif dans `/etc/caddy/apps/` ;
- [ ] exécuter `caddy validate` ;
- [ ] recharger Caddy ;
- [ ] vérifier l'accès HTTP/HTTPS ;
- [ ] vérifier `/etc/caddy/acces.log` ;
- [ ] remplacer le fichier applicatif par une version CD ;
- [ ] vérifier que le reload charge la nouvelle version.

## Backup et restore

- [ ] déclencher un backup PostgreSQL ;
- [ ] vérifier `COMPLETE`, `SHA256SUMS` et la date du backup ;
- [ ] vérifier la présence locale et distante ;
- [ ] restaurer une base de test ;
- [ ] vérifier l'arrêt des applications ;
- [ ] vérifier la recréation de la base et les données ;
- [ ] vérifier `pg_isready` et les healthchecks Compose ;
- [ ] restaurer une release depuis un snapshot fichier.

## Monitoring

- [ ] vérifier qu'Ember atteint l'API Caddy locale ;
- [ ] vérifier les métriques Caddy ;
- [ ] renseigner les endpoints et credentials Vector ;
- [ ] vérifier les headers d'authentification ;
- [ ] vérifier les événements journald, Docker et Symfony ;
- [ ] vérifier l'enveloppe JSON reçue par l'application monitoring ;
- [ ] vérifier l'absence de doublons côté application.

## Disaster recovery

- [ ] simuler la récupération des fichiers de configuration ;
- [ ] restaurer rclone, backup.conf et les cibles DB ;
- [ ] exécuter le workflow restore ;
- [ ] restaurer les fichiers applicatifs ;
- [ ] restaurer la release ;
- [ ] vérifier Caddy, Docker, PostgreSQL, Vector et Ember.
