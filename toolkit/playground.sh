#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

action=${1:-up}
if [ "$#" -gt 0 ]; then shift; fi
case "$action" in
  up)
    for tool in docker k3d kubectl helm tilt python3; do
      command -v "$tool" >/dev/null || { echo "Ferramenta ausente: $tool" >&2; exit 1; }
    done
    python3 toolkit/discover_projects.py projects.json >/dev/null
    docker info >/dev/null
    # Falhas de acesso ao Docker não devem ser confundidas com cluster ausente.
    clusters=$(k3d cluster list -o json)
    if python3 -c 'import json,sys; sys.exit(0 if any(c["name"] == "playground" for c in json.load(sys.stdin)) else 1)' <<< "$clusters"; then
      k3d cluster start playground
    else
      k3d cluster create playground --config toolkit/cluster.yaml
    fi
    k3d kubeconfig merge playground --kubeconfig-switch-context
    kubectl --context k3d-playground wait --for=condition=Ready nodes --all --timeout=120s
    exec tilt up --context k3d-playground -- "$@"
    ;;
  down) exec tilt down --context k3d-playground -- "$@" ;;
  stop) exec k3d cluster stop playground ;;
  *) echo "Uso: bash toolkit/playground.sh {up [apps/serviços...]|down [apps/serviços...]|stop}" >&2; exit 1 ;;
esac
