# Sauvegardes locales et dernière copie distante

Les sauvegardes locales peuvent être activées avant de configurer le stockage
distant. Dans `/etc/server-setup/setup.conf` :

```bash
REMOTE_BACKUP_ENABLED="false"
RCLONE_REMOTE="gdrive"
LOCAL_RETENTION_COUNT="1"
REMOTE_RETENTION_COUNT="1"
```

Puis exécuter `sudo setup backup --non-interactive`. Le mode local est annoncé
explicitement ; aucune sauvegarde distante n'est revendiquée dans ce mode.
Les cibles PostgreSQL doivent déjà être présentes dans
`/etc/server-setup/backup/targets.d/`.

Configurer ensuite la remote `gdrive` avec
`sudo rclone config --config /etc/rclone/rclone.conf`, passer
`REMOTE_BACKUP_ENABLED="true"` dans `setup.conf`, puis relancer
`sudo setup backup --non-interactive`. L'accès à la remote est alors vérifié
avant l'activation du transfert.

Un nombre positif prévaut sur la rétention en jours, séparément pour les dumps
PostgreSQL et les archives fichiers. La valeur `1` conserve la dernière sauvegarde
réussie de chaque type. La valeur `0` conserve le comportement par ancienneté.
La copie distante est contrôlée avec `rclone check` avant suppression des versions
précédentes. Une erreur de transfert ou de contrôle préserve les copies précédentes.
Les dossiers sans nom d'horodatage géré par Server Setup ne sont jamais supprimés
par la politique de comptage.

La copie vers les postes d'administration ou du client est un transfert distinct.
Ne jamais transférer la clé SSH privée d'administration au poste du client ;
prévoir un accès de lecture dédié lors de son raccordement.

`sudo server-backup-export --archive` exporte les dernières sauvegardes complètes
DB et fichiers en empêchant leur rotation pendant la lecture. Le script poste
`scripts/pull-backup.sh` utilise une configuration locale : `BACKUP_HOST`,
`BACKUP_USER`, `BACKUP_PORT`, `BACKUP_KEY`, `BACKUP_KNOWN_HOSTS`, `BACKUP_MOUNT`
et `BACKUP_DEST`. Il refuse un disque non monté, vérifie les sommes de contrôle
et remplace `latest.tar.gz` seulement après validation de la nouvelle copie.
Le script nécessite Bash, Python 3.12+, SSH et les outils GNU usuels.
