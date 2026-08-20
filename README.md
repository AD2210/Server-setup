# Server Setup

Server Setup automatise l'installation et la maintenance de serveurs Ubuntu
Server LTS à partir d'un VPS vierge.

Le dépôt fournit un orchestrateur unique :

```bash
sudo setup <module>
```

Les détails de chaque module sont documentés dans
[docs/modules](docs/modules/README.md).

## Prérequis

- Ubuntu Server LTS 22.04, 24.04 ou 26.04 ;
- accès SSH avec un utilisateur disposant de `sudo` ;
- accès Internet ;
- clé SSH ;
- Git installé sur le VPS.

Ne transférez jamais une clé privée sur le serveur.

## Installation depuis un VPS vierge

### 1. Préparer la connexion

Depuis la machine d'administration, générer une clé si nécessaire :

```bash
ssh-keygen -t ed25519
```

Enregistrer la clé publique auprès du fournisseur VPS, puis se connecter :

```bash
ssh [USER]@[IP] -i [SSH_KEY]
```

Exemple :

```bash
ssh ubuntu@192.0.2.10 -i ~/.ssh/id_ed25519
```

### 2. Préparer le VPS

Définir son hostname et installer Git :

```bash
sudo hostnamectl set-hostname [HOSTNAME]
sudo apt update
sudo apt install -y git
```

### 3. Installer le dépôt

Le dépôt est installé dans `/opt/Server-setup` :

```bash
cd /opt
sudo git clone https://github.com/AD2210/Server-setup.git
sudo chown -R root:root /opt/Server-setup
sudo chmod 755 /opt/Server-setup
sudo chmod +x /opt/Server-setup/bin/setup
sudo ln -sfn /opt/Server-setup/bin/setup /usr/local/bin/setup
```

Vérifier l'installation :

```bash
setup --help
```

### 4. Préparer la configuration

Pour un fonctionnement unattended, créer les fichiers de configuration :

```bash
sudo install -d -m 700 /etc/server-setup
sudo cp /opt/Server-setup/config/setup.example.conf \
    /etc/server-setup/setup.conf
sudo cp /opt/Server-setup/config/secrets.example.conf \
    /etc/server-setup/secrets.conf
sudo chmod 600 /etc/server-setup/secrets.conf
sudo chown root:root /etc/server-setup/secrets.conf
```

Modifier les valeurs avant l'exécution. Les secrets ne doivent pas être
commités dans Git.

Les configurations spécialisées sont disponibles dans `config/` :

- `restore.example.conf` pour une restauration unattended ;
- `backup/targets.d/` pour les cibles PostgreSQL ;
- `vector/` pour le monitoring ;
- `setup.ghcr.example.conf` comme fragment GHCR à fusionner dans `setup.conf`.

### 5. Installation recommandée

Exécuter les modules séparément afin de contrôler chaque étape :

```bash
sudo setup system
sudo setup security
```

Tester ensuite une nouvelle connexion SSH avec l'utilisateur administrateur,
puis poursuivre :

```bash
sudo setup docker
sudo setup reverse-proxy
sudo setup backup
sudo setup monitoring
sudo setup updates
sudo setup logrotate
sudo setup reboot
sudo setup finalize
```

Le module de suppression du compte initial doit être exécuté uniquement après
validation de la nouvelle session :

```bash
sudo setup security-deluser
```

Les opérations de restauration sont lancées à la demande :

```bash
sudo setup restore
```

### Installation complète

Pour exécuter les modules installables dans l'ordre :

```bash
sudo setup all \
    --config /etc/server-setup/setup.conf \
    --secrets /etc/server-setup/secrets.conf \
    --non-interactive
```

`setup all` exclut volontairement `restore` et `security-deluser`, qui
nécessitent une décision ou une validation séparée.

## Modes d'exécution

Le mode interactif est le comportement par défaut :

```bash
sudo setup backup
```

Le mode unattended utilise une configuration et un fichier de secrets :

```bash
sudo setup all \
    --config /etc/server-setup/setup.conf \
    --secrets /etc/server-setup/secrets.conf \
    --non-interactive
```

Les assistants rclone, les credentials provider et les cibles PostgreSQL
structurées doivent être préparés avant une exécution unattended.

## Caddy et déploiements applicatifs

Server Setup installe uniquement le socle serveur Caddy :

```text
/etc/caddy/
├── Caddyfile
├── acces.log
├── snippets/
└── apps/
```

Les fichiers d'endpoints applicatifs sont déposés dans `/etc/caddy/apps/` par
la CD, puis Caddy est rechargé. Server Setup ne génère pas les endpoints
applicatifs.

## Documentation

- [Documentation des modules](docs/modules/README.md)
- [Mode unattended](docs/UNATTENDED.md)
- [QA et linters](docs/QA.md)
- [Checklist de test E2E](docs/E2E.md)
- [Gestion GHCR et releases](docs/GHCR_RELEASES.md)

## QA locale

Le contrôle complet est exécuté par GitHub Actions. En local, les contrôles
disponibles peuvent être lancés ainsi :

```bash
QA_ALLOW_MISSING_TOOLS=true qa/lint.sh
```

La CI utilise `qa/lint.sh` en mode strict.

## Structure du dépôt

```text
bin/       orchestrateur setup
lib/       bibliothèques communes
config/    templates et exemples de configuration
modules/   modules d'installation et de maintenance
docs/      documentation détaillée
qa/        contrôles qualité
```
