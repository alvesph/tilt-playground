#!/bin/sh

docker system prune -f
docker images --format '{{.Repository}}:{{.Tag}}' | grep 'localhost:5000/k3d-registry.localhost_5000_' | xargs -r docker rmi -f
