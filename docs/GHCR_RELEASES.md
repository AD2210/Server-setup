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
- `current` recharge le dernier SHA connu ;
- `previous` recharge le SHA précédent via un env temporaire ;
- `.env.prod.local` n'est pas modifié pendant le rollback.
