#!/bin/bash

# Caminho para o arquivo .env
ENV_FILE=".env"

# Verifica se o arquivo .env existe
if [ -f "$ENV_FILE" ]; then
  # Lê o arquivo .env linha por linha
  while IFS= read -r line || [ -n "$line" ]; do
    # Ignora linhas que começam com # (comentários) ou estão vazias
    if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
      # Exporta a variável de ambiente
      export "$line"
      # Depuração: imprime a variável exportada
      echo "Variável exportada: $line"
    fi
  done < "$ENV_FILE"
else
  echo "Erro: arquivo $ENV_FILE não encontrado."
  exit 1
fi

# Verifica se a variável SUDO_PASSWORD está definida
if [ -z "$SUDO_PASSWORD" ]; then
  echo "Erro: SUDO_PASSWORD não está definido no arquivo .env"
  exit 1
fi

# Depuração: imprimir a senha para garantir que ela foi carregada
echo "Senha carregada do .env: $SUDO_PASSWORD"

# Função para verificar se um comando existe
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Função para instalar o k3d usando curl ou wget
install_k3d() {
  if command_exists curl; then
    echo "curl encontrado, instalando k3d..."
    echo "$SUDO_PASSWORD" | sudo -S curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo -S bash
  elif command_exists wget; then
    echo "wget encontrado, instalando k3d..."
    echo "$SUDO_PASSWORD" | sudo -S wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo -S bash
  else
    echo "Erro: nem curl nem wget foram encontrados. Por favor, instale curl ou wget e execute novamente."
    exit 1
  fi
}

# Executa a função de instalação do k3d
install_k3d
