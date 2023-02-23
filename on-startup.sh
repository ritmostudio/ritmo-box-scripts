#!/bin/bash
echo "Starting Ritmo Box"

echo "Dwonloading Ritmo Node Player image" 
docker pull lucassaid/ritmo-node-player || true

docker ps -aq | xargs docker stop | xargs docker rm

docker run \
  -v /run/user/1000/pulse:/run/user/1000/pulse \
  -e PULSE_SERVER=tcp:172.17.0.1 \
  -u 1000:1000 \
  --env-file /etc/ritmo/.env \
  -p 8082:8082 \
  -d \
  -v /usr/local/bin/ritmo/db:/usr/local/bin/ritmo/db \
  -e REACT_APP_DB_PREFIX=/usr/local/bin/ritmo/db/ \
  --restart on-failure \
  lucassaid/ritmo-node-player
