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

Un exemple de cible PostgreSQL est fourni dans le dépôt :

```text
config/backup/targets.d/app-db.conf.example
```

Lorsque `DB_BACKUP_ENABLED="true"` est défini, les cibles doivent être
préinstallées dans `/etc/server-setup/backup/targets.d/`. Le module ne lance
pas d'assistant interactif dans ce mode.

De même, une remote rclone doit être préparée dans
`/etc/rclone/rclone.conf`. Utilisez `RCLONE_REMOTE` et
`RCLONE_KEEP_EXISTING="true"` dans la configuration unattended.

Cela évite d'introduire des pseudo-tableaux complexes dans `setup.conf`.

La restauration utilise un fichier dédié, par exemple
`config/restore.example.conf`, afin de ne pas mélanger ses choix avec la
configuration générale du serveur.

Le module monitoring borne l'installation et l'initialisation d'Ember afin
d'éviter un blocage silencieux en unattended :

```bash
EMBER_INSTALL_TIMEOUT="300"
EMBER_INIT_TIMEOUT="60"
```

## Compatibilité des modules

Les paramètres simples des modules utilisent maintenant une clé de configuration.
Un prompt résiduel sans clé est volontairement limité au mode interactif ou à
une configuration structurée dédiée. Tant qu'un module utilise :

```bash
ask_input "Question" "défaut"
```

il reste interactif et doit recevoir une configuration dédiée avant d'être
utilisé en unattended.

Pour le rendre compatible unattended, ajouter simplement la clé :

```bash
ask_input "Question" "défaut" "MA_CLE"
```

Même principe pour `confirm`.

Cette migration peut donc être faite module par module.
