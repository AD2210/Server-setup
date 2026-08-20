# GHCR / Releases Docker

Compose doit utiliser `.env.prod.local` explicitement :

```bash
docker compose --env-file .env.prod.local up -d
```

Exemple :

```yaml
services:
  api:
    image: "${API_IMAGE}:${API_SHA_CURRENT}"
```

Initialisation :

```bash
server-release init app1 api ghcr.io/org/api
```

Enregistrement d'une release :

```bash
server-release record app1 api "$GITHUB_SHA"
```

État :

```dotenv
API_IMAGE=ghcr.io/org/api
API_SHA_CURRENT=abcdef
API_SHA_PREVIOUS=123456
```

Affichage :

```bash
server-release show app1
```

Restauration :
- le module `sudo setup restore` liste les snapshots fichier disponibles ;
- l'utilisateur sélectionne le snapshot par date ;
- le `.env.prod.local` contenu dans le snapshot est utilisé temporairement ;
- `.env.prod.local` présent sur le serveur n'est pas modifié ;
- Compose tire puis démarre les images correspondant au snapshot sélectionné.
