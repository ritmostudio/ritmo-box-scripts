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
  |  |  |  ||  |    |  |    |  |  \/  |  | \      /
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

# -----------

# Get put-urls token
put_urls_token=$(curl -s -X POST http://192.168.20.101:8081/auth/get-put-urls-token \
  -H "Content-Type: application/json" \
  -d "{\"credential\":\"$username\",\"password\":\"$password\"}")
if [ -z "$put_urls_token" ] || [ "$put_urls_token" == "INVALID_LOGIN" ]; then
  echo "❌ Invalid login, please try again"
  exit 1
fi

# Get environment
for arg in "$@"; do
  case $arg in
    -e=*)
      environment="${arg#*=}"
      shift
      ;;
    *)
      # Process other arguments
      ;;
  esac
done

sudo mkdir -p /etc/ritmo

env_path=/etc/ritmo/.env

# Setting up api url and influx bucket in .env file
rm -f $env_path
touch $env_path
if [ -z "$environment" ]; then
  api_subdomain="api"
  influx_bucket="playback"
else
  api_subdomain="${environment}-api"
  influx_bucket="${environment}-playback"
fi
echo PORT=8082 >> $env_path
echo REACT_APP_API_URL=https://$api_subdomain.ritmostudio.com >> $env_path
echo REACT_APP_INFLUX_PLAYBACK_BUCKET=$influx_bucket >> $env_path
echo "✅ Environment set"

# Setting up put-urls token in .env file
echo "PUT_URLS_TOKEN=$put_urls_token" >> $env_path
echo "✅ Put-urls token created"

# -----------

# API LOGIN
login_response=$(curl -s -X POST https://$api_subdomain.ritmostudio.com/auth/v1/player-login \
  -H "Content-Type: application/json" \
  -d "{\"credential\":\"$username\",\"password\":\"$password\"}")
access_token=$(echo $login_response | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
if [ -z "$access_token" ]; then
  echo "❌ Failed to parse access token"
  exit 1
fi
echo "RITMO_TOKEN=$access_token" >> $env_path
echo "✅ Access token created"

# -----------

echo "JWT_SECRET=$(openssl rand -hex 32)" >> $env_path
echo "✅ JWT secret created"

# -----------

if [ ! -f /etc/pulse/default.pa ]; then
  echo "❌ Pulseaudio server not found"
  exit 1
fi
if ! grep -q "load-module module-native-protocol-tcp auth-anonymous=1" /etc/pulse/default.pa; then
  echo "load-module module-native-protocol-tcp auth-anonymous=1" >> /etc/pulse/default.pa
fi
echo "✅ Configured Pulseaudio server"

# -----------

# echo "Setting permissions to LevelDB"
mkdir -p /usr/local/bin/ritmo/node-player-db
sudo chmod 777 /usr/local/bin/ritmo/node-player-db
echo "✅ Configured LevelDB"

# ------------

# Install docker
if ! command -v docker > /dev/null 2>&1; then
  curl https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main/docker-install.sh --output ~/docker-install.sh
  sh ./docker-install.sh
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
sudo systemctl enable ritmo-box.service
echo "✅ Configured startup script"

echo "✅ Setup completed! restarting in 2 seconds..."
# sleep 2
# sudo reboot now