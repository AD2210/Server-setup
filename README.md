# Server Setup
0) commencer par généré une clé ssh ou utiliser celle déjà en place pour l'accès serveur


0) se connecter à l'instance vierge :
ssh [User]@[Ip] -p [Port] -i [Ssh_Key]
par défaut l'option port pointe sur 22, elle est facultative

1) maj et instalation git pour récupéré la config rapide :
sudo hostnamectl set-hostname [nom]
sudo apt update && apt install -y git

cd /opt

sudo git clone https://github.com/AD2210/Server-setup.git

sudo chown -R root:root /opt/Server-setup
sudo chmod 755 /opt/Server-setup

cd Server-setup

chmod +x bin/setup

sudo ln -sfn /opt/Server-setup/bin/setup /usr/local/bin/setup

sudo setup system

Usage:
setup all
