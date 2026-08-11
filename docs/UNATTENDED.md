# Mode non interactif

## Objectif

Le mode unattended permet de rejouer Server Setup sur une instance vierge sans
avoir à répondre manuellement aux prompts.

Le mode interactif reste le comportement par défaut.

## Exécution

```bash
sudo setup all \
  --config /etc/server-setup/setup.conf \
  --secrets /etc/server-setup/secrets.conf \
  --non-interactive
```

## Principe

Chaque saisie utilisateur reçoit progressivement une clé de configuration.

Exemple interactif existant :

```bash
ADMIN_USER=$(ask_input "Nom de l'utilisateur administrateur" "admin")
```

Version compatible unattended :

```bash
ADMIN_USER=$(ask_input \
    "Nom de l'utilisateur administrateur" \
    "admin" \
    "ADMIN_USER"
)
```

Pour les booléens :

```bash
if confirm \
    "Fermer l'ancien port SSH ?" \
    "CLOSE_OLD_SSH_PORT" \
    "false"; then

    ...
fi
```

## Règle importante

Un prompt critique qui ne doit pas prendre de décision implicite utilise :

```bash
confirm_required "Supprimer l'utilisateur ?" "DELETE_INITIAL_USER"
```

En `--non-interactive`, l'absence de cette clé provoquera une erreur.

## Secrets

Les secrets doivent rester séparés de la configuration générale.

```text
/etc/server-setup/setup.conf
/etc/server-setup/secrets.conf
```

Permissions recommandées :

```bash
sudo chown root:root /etc/server-setup/secrets.conf
sudo chmod 600 /etc/server-setup/secrets.conf
```

## Configurations structurées

Les valeurs simples sont adaptées au fichier principal :

- utilisateur admin ;
- port SSH ;
- timers ;
- rétention ;
- activation/désactivation de fonctions.

Les objets multiples doivent utiliser des fichiers dédiés.

Exemples :

```text
/etc/server-setup/apps.d/
/etc/server-setup/backup/targets.d/
```

Une application pourrait ainsi utiliser :

```text
/etc/server-setup/apps.d/my-app.conf
```

et une base :

```text
/etc/server-setup/backup/targets.d/my-app-db.conf
```

Cela évite d'introduire des pseudo-tableaux complexes dans `setup.conf`.

## Migration des modules

Le socle fourni dans cette branche n'oblige pas à migrer tous les modules en une
fois.

Tant qu'un module utilise :

```bash
ask_input "Question" "défaut"
```

il reste parfaitement interactif.

Pour le rendre compatible unattended, ajouter simplement la clé :

```bash
ask_input "Question" "défaut" "MA_CLE"
```

Même principe pour `confirm`.

Cette migration peut donc être faite module par module.
