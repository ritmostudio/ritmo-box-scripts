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
  |  |  |  ||  |    |  |    |  |  \/  |  | \      /   V0.0.90
   ¯¯    ¯¯  ¯¯      ¯¯      ¯¯        ¯¯    ¯¯¯¯

"

# Validations
if ! command -v systemctl > /dev/null 2>&1; then
  echo "❌ Systemd not found, make sure you are running this script on a Linux machine"
  exit 1
fi

while [ -z "$username" ]; do
  echo "Branch: "
  read username
  if [ -z "$username" ]; then
    echo "You need to enter the branch credential."
  fi
done

while [ -z "$password" ]; do
  echo "Branch password: "
  read password
  if [ -z "$password" ]; then
    echo "You need to enter the branch password."
  fi
done

# ------------

# Set environment
for arg in "$@"; do
  case $arg in
    -e=*)
      environment="${arg#*=}"
      shift
      ;;
    -t=*)
      tailscale_token="${arg#*=}"
      shift
      ;;
  esac
done

if [ -z "$tailscale_token" ]; then
  echo "❌ Token not provided"
  exit 1
fi

if [ -z "$environment" ]; then
  api_url="https://api.ritmostudio.com"
  influx_bucket="playback"
else
  api_url="https://${environment}-api.ritmostudio.com"
  influx_bucket="${environment}-playback"
fi

# -----------

# API LOGIN
login_response=$(curl -s -X POST $api_url/auth/v1/player-login \
  -H "Content-Type: application/json" \
  -d "{\"credential\":\"$username\",\"password\":\"$password\"}")
if [ "$(type -t login_response)" = "string" ] && [ "$login_response" == "INVALID_LOGIN" ]; then
  echo "❌ Incorrect branch or password"
  exit 1
fi
access_token=$(echo $login_response | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
branch_id=$(echo $login_response | sed -n 's/.*"_id":"\([^"]*\)".*/\1/p')
if [ -z "$access_token" ]; then
  echo "❌ Failed to parse access token"
  exit 1
fi

# Crating folder for .env file
sudo mkdir -p /etc/ritmo
env_path=/etc/ritmo/.env

# Setting up api url and influx bucket in .env file
rm -f $env_path
touch $env_path
echo PORT=8082 >> $env_path
echo REACT_APP_API_URL=$api_url >> $env_path
echo REACT_APP_INFLUX_PLAYBACK_BUCKET=$influx_bucket >> $env_path
echo "✅ Environment set"

echo "RITMO_TOKEN=$access_token" >> $env_path
echo "✅ Access token created for $branch_id"

# -----------

# Tailscale
if ! command -v tailscale > /dev/null 2>&1; then
  echo "𓃑  Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh

  if ! command -v tailscale > /dev/null 2>&1; then
    echo "❌ Error installing Tailscale"
    exit 1
  fi

  echo "✅ Tailscale installed"

fi

sudo tailscale down
sudo tailscale up --authkey=$tailscale_token --hostname=$(echo "$branch_id" | sed 's/BRAN://')
echo "✅ Tailscale configured"

# -----------

# Random JWT secret
echo "JWT_SECRET=$(openssl rand -hex 32)" >> $env_path
echo "✅ JWT secret created"

# -----------

# Pulseaudio
if [ ! -f /etc/pulse/default.pa ]; then
  echo "🔊 Installing Pulseaudio"
  sudo apt update
  sudo apt -y install pulseaudio

  if [ ! -f /etc/pulse/default.pa ]; then
    echo "❌ Error installing Pulseaudio"
    exit 1
  fi

  echo "✅ Pulseaudio installed"
fi
if ! grep -q "load-module module-native-protocol-tcp auth-anonymous=1" /etc/pulse/default.pa; then
  sudo echo "load-module module-native-protocol-tcp auth-anonymous=1" >> /etc/pulse/default.pa
fi
echo "✅ Configured Pulseaudio server"

# -----------

# Permissions for LevelDB
sudo mkdir -p /usr/local/bin/ritmo/db
sudo chmod -R 777 /usr/local/bin/ritmo/db
echo "✅ Configured LevelDB"

# ------------

# Install docker
if ! command -v docker > /dev/null 2>&1; then

  echo "🐳 Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh

  # Post install
  sudo apt-get install -y uidmap
  dockerd-rootless-setuptool.sh install

  if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Error installing Docker"
    exit 1
  fi

  echo "✅ Docker installed"
else
  echo "✅ Docker already installed"
fi

if ! systemctl is-active --quiet docker; then
  # Iniciar Docker
  sudo systemctl start docker
  echo "✅ Docker started"
else 
  echo "✅ Docker running"
fi

# ------------

# Downloading startup script
startup_path=/usr/local/bin/ritmo/on-startup.sh
sudo curl -s https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main/on-startup.sh --output $startup_path
sudo chmod a+x $startup_path
# Downloading service file
service_path=/etc/systemd/system/ritmo-box.service
sudo curl -s https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main/service --output $service_path
sudo chmod 644 $service_path
sudo systemctl enable ritmo-box.service > /dev/null
echo "✅ Configured startup script"

# ------------

sudo ufw allow 8082/tcp
echo "✅ Port 8082 open"

# ------------

echo "✅ Setup completed"

# ------------

$startup_path sh
echo "✅ Ritmo BOX started! Go to box.ritmostudio.com to control the music"