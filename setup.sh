#!/bin/bash
echo "
   ______    __  __________  ___      ___    ____
  |       \ |  ||          ||   \    /   | /      \ 
  |  .¯¯.  ╷|  |'---.  .---'|            |╷  .--.  ╷
  |  |  |  ╵|  |    |  |    |    '  '    ||  |  |  |
  |   ¯¯  / |  |    |  |    |     \/     ||  |  |  |
  ❬   .  ❬  ❬  ❬    ❬  ❬    ❬  |\    /|  ❬❬  ❬  ❬  ❬
  |  | \  \ |  |    |  |    |  |      |  ||  |  |  |
  |  |  '  '|  |    |  |    |  | '  ' |  |'  '--'  '
  |  |  |  ||  |    |  |    |  |  \/  |  | \      /   V0.1.6
   ¯¯    ¯¯  ¯¯      ¯¯      ¯¯        ¯¯    ¯¯¯¯

"

# ------ VALIDATIONS ------
if ! command -v systemctl > /dev/null 2>&1; then
  echo "❌ Systemd not found, make sure you are running this script on a Linux machine"
  exit 1
fi

# ----- DOCKER -------
if ! command -v docker > /dev/null 2>&1; then
  echo "🐳 Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  sudo rm -f get-docker.sh
  # Post install
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y uidmap
  export FORCE_ROOTLESS_INSTALL=1
  dockerd-rootless-setuptool.sh install
  if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Error installing Docker"
    exit 1
  fi
  echo "✅ Docker installed"
fi
if ! systemctl is-active --quiet docker; then
  sudo systemctl start docker
  echo "✅ Docker started"
else 
  echo "✅ Docker running"
fi

# ------ RITMO SERVICE ------
# Download startup script and docker-compose
sudo mkdir -p /etc/ritmo
ritmo_scripts_path=https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main
startup_path=/usr/local/bin/ritmo/on-startup.sh
sudo curl -s $ritmo_scripts_path/on-startup.sh -o $startup_path
sudo curl -s $ritmo_scripts_path/docker-compose.yaml -o /etc/ritmo/docker-compose.yaml
sudo chmod a+x $startup_path
# Download service file
service_path=/etc/systemd/system/ritmo-box.service
sudo curl -s $ritmo_scripts_path/service -o $service_path
sudo chmod 644 $service_path
sudo systemctl enable ritmo-box.service > /dev/null
echo "✅ Startup script set up"

# ------ PORTS ------
sudo ufw allow 8082/tcp
# sudo ufw allow 80/tcp
echo "✅ Setup completed"

# ------ INIT ------
$startup_path sh
echo "✅ Ritmo BOX started!"