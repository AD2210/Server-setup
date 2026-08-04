# Server Setup
0) se connecter à l'instance vierge :
ssh [User]@[Ip] -p [Port] 
par défaut l'option port pointe sur 22, elle est facultative

1) maj et instalation git pour récupéré la config rapide :
sudo apt update && apt install -y git

git clone https://github.com/AD2210/Server-setup.git

cd Server-setup

chmod +x bin/setup

sudo ln -s $(pwd)/bin/setup /usr/local/bin/setup

setup system

Usage:
setup all
