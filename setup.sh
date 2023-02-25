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
  |  |  |  ||  |    |  |    |  |  \/  |  | \      /   V0.0.92
   ¯¯    ¯¯  ¯¯      ¯¯      ¯¯        ¯¯    ¯¯¯¯

"

# ------ VALIDATIONS ------
if ! command -v systemctl > /dev/null 2>&1; then
  echo "❌ Systemd not found, make sure you are running this script on a Linux machine"
  exit 1
fi

# ------ RITMO CREDENTIALS ------
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
  influx_bucket="playback"
else
  api_url="https://${environment}-api.ritmostudio.com"
  influx_bucket="${environment}-playback"
fi

# ----- API LOGIN ------
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

# ----- ENV ------
sudo rm -f $env_path
sudo touch $env_path
sudo sh -c "echo PORT=8082 >> $env_path"
sudo sh -c "echo REACT_APP_API_URL=$api_url >> $env_path"
sudo sh -c "echo REACT_APP_INFLUX_PLAYBACK_BUCKET=$influx_bucket >> $env_path"
sudo sh -c "echo RITMO_TOKEN=$access_token >> $env_path"
sudo sh -c "echo JWT_SECRET=$(openssl rand -hex 32) >> $env_path"
echo "✅ Environment set"

# ----- PULSEAUDIO ------
if [ ! -f /etc/pulse/default.pa ]; then
  echo "🔊 Installing Pulseaudio"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install pulseaudio pulseaudio-utils alsa-utils
  if [ ! -f /etc/pulse/default.pa ]; then
    echo "❌ Error installing Pulseaudio"
    exit 1
  fi
  echo "✅ Pulseaudio installed"
fi

# allowing anonymous connections
sed -i '' '/^load-module module-native-protocol-unix/d' /etc/pulse/default.pa
pulse_auth_line="load-module module-native-protocol-unix auth-anonymous=1"
if ! grep -q $pulse_auth_line /etc/pulse/default.pa; then
  sudo sh -c "$pulse_auth_line >> /etc/pulse/default.pa"
fi

# Select default audio device
sudo sh -c "echo 'set-default-sink 0' >> /etc/pulse/default.pa"

pulseaudio -k > /dev/null
pulseaudio -D
echo "✅ Pulseaudio server started"

# ----- LEVEL DB ------
sudo mkdir -p /usr/local/bin/ritmo/db
sudo chmod -R 777 /usr/local/bin/ritmo/db
echo "✅ Configured LevelDB"

# ----- DOCKER -------
if ! command -v docker > /dev/null 2>&1; then
  echo "🐳 Installing Docker"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  sudo rm -f get-docker.sh
  # Post install
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y uidmap
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
# Downloading startup script
startup_path=/usr/local/bin/ritmo/on-startup.sh
sudo curl -s https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main/on-startup.sh -o $startup_path
sudo chmod a+x $startup_path
# Downloading service file
service_path=/etc/systemd/system/ritmo-box.service
sudo curl -s https://raw.githubusercontent.com/ritmostudio/ritmo-box-scripts/main/service -o $service_path
sudo chmod 644 $service_path
sudo systemctl enable ritmo-box.service > /dev/null
echo "✅ Configured startup script"

# ------ PORTS ------
sudo ufw allow 8082/tcp
echo "✅ Setup completed"

# ------ INIT ------
$startup_path sh
echo "✅ Ritmo BOX started! Go to box.ritmostudio.com to control the music"