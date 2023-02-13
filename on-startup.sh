#!/bin/bash
echo "Starting Ritmo Box"

echo "Dwonloading Ritmo Node Player image" 
docker pull lucassaid/ritmo-node-player || true

docker ps -aq | xargs docker stop | xargs docker rm

levelDB_path=/usr/local/bin/ritmo/db

docker run \
  -v /run/user/1000/pulse:/run/user/1000/pulse \
  -e PULSE_SERVER=unix:/run/user/1000/pulse/native \
  -u 1000:1000 \
  --env-file /etc/ritmo/.env \
  -p 8082:8082 \
  -d \
  -v $levelDB_path:$levelDB_path \
  -e REACT_APP_DB_PREFIX=$levelDB_path/ \
  --restart always \
  lucassaid/ritmo-node-player
