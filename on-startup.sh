#!/bin/bash
echo "Starting Ritmo Box"

docker compose -f /etc/ritmo/docker-compose.yaml down
docker compose -f /etc/ritmo/docker-compose.yaml pull
docker compose -f /etc/ritmo/docker-compose.yaml up
echo "✅ Ritmo BOX started"
