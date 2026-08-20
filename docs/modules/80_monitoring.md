# Module 80_monitoring

Commande : `sudo setup monitoring`

Installe Ember et Vector. Ember utilise l'API Caddy locale ; Vector collecte
journald, Docker et Symfony en JSON. Les endpoints sont configurés dans
`/etc/server-setup/monitoring/vector.env`.

Chaque événement est envoyé dans une enveloppe JSON avec l'instance serveur,
le type de log, l'heure UTC et le contenu original. Le champ application est
ajouté lorsqu'il peut être déduit. Les headers `X-Client-ID` et
`X-Client-Secret` proviennent du fichier de secrets.
