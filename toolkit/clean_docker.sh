#!/bin/sh

docker system prune -f
docker images --format '{{.Repository}}:{{.Tag}}' | grep 'localhost:5006/k3d-registry.localhost_5006_' | xargs -r docker rmi -f
