# Module 41_restore

Commande : `sudo setup restore`

Liste les backups locaux puis distants par date. Il restaure les dumps
PostgreSQL avec arrêt des applications, recréation de base, `pg_restore`,
redémarrage Compose et `pg_isready`.
