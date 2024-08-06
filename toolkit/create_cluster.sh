#!/bin/bash

CLUSTER_NAME="playground"

# Verifica se o cluster já existe
if k3d cluster list "$CLUSTER_NAME" &>/dev/null; then
  echo "Cluster '$CLUSTER_NAME' já existe."
else
  echo "Criando cluster '$CLUSTER_NAME'..."
  k3d cluster create "$CLUSTER_NAME" --config ./toolkit/cluster.yaml
fi