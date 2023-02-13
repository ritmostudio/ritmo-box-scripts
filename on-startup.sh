#!/bin/bash
echo "Starting Ritmo Box"

echo "Dwonloading Ritmo Node Player image" 
docker pull lucassaid/ritmo-node-player || true

if docker ps -a | grep ritmo-node-player &> /dev/null; then
  echo "Stopping Ritmo Node Player"
  docker stop ritmo-node-player
  docker rm ritmo-node-player
fi

docker run \
  -v /run/user/1000/pulse:/run/user/1000/pulse \
  -e PULSE_SERVER=unix:/run/user/1000/pulse/native \
  -u 1000:1000 \
  --env-file .env \
  -p 8082:8082 \
  -d \
  -v ~/node-player-db:/home/node-player-db \
  -e REACT_APP_DB_PREFIX=/home/node-player-db/ \
  --restart always \
  --name ritmo-node-player \
  lucassaid/ritmo-node-player
