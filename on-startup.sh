#!/bin/bash
echo "Starting Ritmo Box"

pulseaudio -k > /dev/null
pulseaudio --start
echo "✅ Pulseaudio server started"

docker compose -f /etc/ritmo/docker-compose.yaml down
docker compose -f /etc/ritmo/docker-compose.yaml pull
docker compose -f /etc/ritmo/docker-compose.yaml up
echo "✅ Pulseaudio server started"
