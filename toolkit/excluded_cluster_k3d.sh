#!/bin/bash
docker stop k3d-playground-serverlb k3d-playground-agent-1 k3d-playground-agent-0 k3d-playground-server-0 registry.localhost
docker rm k3d-playground-serverlb k3d-playground-agent-1 k3d-playground-agent-0 k3d-playground-server-0 registry.localhost