# Module 80_monitoring

Commande : `sudo setup monitoring`

Installe Ember et Vector. Ember utilise l'API Caddy locale ; Vector collecte
journald, Docker et Symfony en JSON. Les endpoints sont configurés dans
`/etc/server-setup/monitoring/vector.env`.
