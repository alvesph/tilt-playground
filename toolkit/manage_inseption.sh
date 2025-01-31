#!/bin/bash

ACTION=$1

clean_docker() {
  echo "Limpando Docker..."
  docker system prune -f
  docker images --format '{{.Repository}}:{{.Tag}}' | grep 'localhost:5006/k3d-registry.localhost_5006_' | xargs -r docker rmi -f
}

create_cluster() {
  CLUSTER_NAME="playground"

  # Verifica se o cluster já existe
  if k3d cluster list "$CLUSTER_NAME" &>/dev/null; then
    echo "Cluster '$CLUSTER_NAME' já existe."
  else
    echo "Criando cluster '$CLUSTER_NAME'..."
    k3d cluster create "$CLUSTER_NAME" --config ./toolkit/cluster.yaml
  fi
}

exclude_cluster() {
  echo "Excluindo Cluster..."
  docker stop k3d-playground-serverlb k3d-playground-agent-1 k3d-playground-agent-0 k3d-playground-server-0 registry.localhost
  docker rm k3d-playground-serverlb k3d-playground-agent-1 k3d-playground-agent-0 k3d-playground-server-0 registry.localhost
}

# Verifica qual ação rodar com base no parâmetro
case $ACTION in
  "clean_docker")
    clean_docker
    ;;
  "create_cluster")
    create_cluster
    ;;
  "exclude_cluster")
    exclude_cluster
    ;;
  *)
    echo "Ação inválida. Use: clean_docker, create_cluster ou exclude_cluster."
    exit 1
    ;;
esac
