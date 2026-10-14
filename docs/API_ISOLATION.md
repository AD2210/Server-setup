# Distribution isolee des API ITC

`server-api-config` appartient au module Docker de `server-setup`. Il lit un
inventaire local par client et environnement, puis produit uniquement les
variables utiles a l'application cible. Les fichiers d'inventaire ne sont ni
copies dans les conteneurs ni envoyes par GitHub Actions.
Le runtime et ses tests sont en Bash, comme `server-release` ; il ne depend pas
d'un module Python.

## Inventaire sur le serveur

Creer, hors depot, les deux fichiers suivants (exemple `itc/preprod`) :

```text
/etc/server-setup/api-config/itc/preprod/oscar.env
/etc/server-setup/api-config/itc/preprod/hyperplanning.env
```

Chaque fichier doit appartenir a root et avoir les droits `0600`. Les lignes
doivent etre au format `NOM=valeur`, sans guillemets et sans retour a la ligne
dans la valeur. `#` en debut de ligne est un commentaire. Aucun `source` shell
n'est effectue ; les caracteres `$`, `!`, `#` et `=` restent litteraux.

`oscar.env` accepte : `OSCAR_BASE_URL`, `OSCAR_API_VERSION`,
`OSCAR_OAUTH_GRANT`, `OSCAR_CLIENT_ID`, `OSCAR_CLIENT_SECRET`, `OSCAR_USERNAME`,
`OSCAR_PASSWORD`, `OSCAR_TENANT_KEY`. Les six champs hors version et grant sont
obligatoires. Garder Oscar V3 et le grant `password` tant que V4 n'est pas
specifiee et testee.

`hyperplanning.env` accepte : `HYPERPLANNING_WSDL`,
`HYPERPLANNING_SOAP_BASE_URL`, `HYPERPLANNING_LOGIN`,
`HYPERPLANNING_PASSWORD`, `HYPERPLANNING_ACTIVE_SCHOOL_YEAR`. Les cinq
champs sont obligatoires. Le WSDL et la base SOAP doivent viser la meme
publication annuelle : port 81 pour 2026-2027, puis port 80 pour 2027-2028.
La bascule reste manuelle.

## Production des vues

Apres installation ou mise a jour de `server-setup`, lancer en root avant
chaque premiere release et apres chaque rotation :

```bash
server-api-config itc preprod boost /srv/apps/boost-preprod
server-api-config itc preprod data-suite /srv/apps/data-suite-preprod
server-api-config itc preprod connector /srv/apps/hp-oscar-preprod
```

Adapter les chemins a `APP_PATH` de chaque application, puis repeter pour
`prod`. Le programme cree atomiquement `APP_PATH/.env.api.local` avec les droits
`0600` et le proprietaire du repertoire applicatif. La vue boost contient
seulement les cles Oscar adaptees aux noms `OSCAR_API_*`; celle de data-suite
contient seulement Hyperplanning ; celle du connecteur contient les deux.
Une erreur d'inventaire conserve la version precedente du fichier de sortie.

### Vues sans secrets et vaults Symfony

Sur le VPS ITC réinstallé, `/etc/server-setup/api-config/.public-only` (root,
0600) active les vues publiques : les clés `*_PASSWORD` et `*_CLIENT_SECRET`
ne sont plus écrites dans `.env.api.local`. Leurs valeurs sont chiffrées dans
le vault de chaque application, selon la même séparation Oscar/Hyperplanning.
Les inventaires source restent privés et réservés à root. Une rotation doit
mettre à jour les secrets chiffrés des vaults concernés avant de recréer les
conteneurs ; le rendu public seul ne chiffre pas de nouvelles valeurs.

Faire ensuite recreer les conteneurs applicatifs et leurs workers pour charger
la nouvelle configuration. Le deploiement du connecteur refuse explicitement
un fichier absent ou illisible. Pour boost et data-suite, verifier le fichier
avant de lancer leur workflow CD actuel. Aucun log de rendu ne contient les
valeurs.

Une rotation des identifiants Oscar doit aussi invalider les anciens
identifiants cote Oscar. Les secrets retires du `.env` versionne de boost
existent encore dans son historique Git ; traiter cet historique selon la
politique de conservation du depot apres rotation.
