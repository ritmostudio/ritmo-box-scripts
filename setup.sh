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
  |  |  |  ||  |    |  |    |  |  \/  |  | \      /   V0.1.8
   ¯¯    ¯¯  ¯¯      ¯¯      ¯¯        ¯¯    ¯¯¯¯

"

# ------ VALIDATIONS ------
if ! command -v systemctl > /dev/null 2>&1; then
  echo "❌ Systemd not found, make sure you are running this script on a Linux machine"
  exit 1
fi

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
sudo sed -i '/^load-module module-native-protocol-unix/d' /etc/pulse/default.pa
pulse_auth_line="load-module module-native-protocol-unix auth-anonymous=1"
if ! grep -q "$pulse_auth_line" /etc/pulse/default.pa; then
  sudo sh -c "echo $pulse_auth_line >> /etc/pulse/default.pa"
fi

# Select default audio device
pulse_set_sink_line="set-default-sink 2"
if ! grep -q "$pulse_set_sink_line" /etc/pulse/default.pa; then
  sudo sh -c "echo $pulse_set_sink_line >> /etc/pulse/default.pa"
fi

# pulseaudio folder permissions
sudo chmod -R 777 /run/user/1000/pulse/native
echo "✅ Pulseaudio set up"

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
# enable for UI
# sudo ufw allow 80/tcp 
echo "✅ Setup completed"

# ------ INIT ------
$startup_path sh
echo "✅ Ritmo BOX started!"
