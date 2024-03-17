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

# ------ ARGUMENTS ------
for arg in "$@"; do
  case $arg in
    -e=*)
      environment="${arg#*=}"
      shift
      ;;
  esac
done

if [ -z "$environment" ]; then
  api_url="https://api.ritmostudio.com"
  ts_url="https://ts.ritmostudio.com"
else
  api_url="https://${environment}-api.ritmostudio.com"
  ts_url="https://${environment}-ts.ritmostudio.com"
fi

# ----- ENV ------
sudo mkdir -p /etc/ritmo
env_path=/etc/ritmo/.env
sudo rm -f $env_path
sudo touch $env_path
sudo sh -c "echo PORT=8082 >> $env_path"
sudo sh -c "echo API_URL=$api_url >> $env_path"
sudo sh -c "echo JWT_SECRET=$(openssl rand -hex 32) >> $env_path"
echo "✅ Environment set"

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