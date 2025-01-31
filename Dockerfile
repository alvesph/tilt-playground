# Etapa 1: Base Ubuntu e instalação de pacotes necessários
FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Adiciona a chave GPG do Docker e repositório oficial
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Instala Docker
RUN apt-get update && apt-get install -y docker-ce \
    && rm -rf /var/lib/apt/lists/*

# Instala Tilt
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# Instala K3D
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Instala Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Instala kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

# Etapa 2: Criação da imagem final mais leve
FROM ubuntu:20.04

# Copia os binários instalados na etapa builder
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/bin/docker /usr/bin/docker

# Define diretório de trabalho
WORKDIR /app

COPY ./services /app/services
COPY ./applications /app/applications
COPY ./Tiltfile /app/Tiltfile

# Script de inicialização que roda tilt up e exibe a mensagem
CMD ["bash", "-c", "tilt up && echo 'Acesse a aplicação em http://localhost:10350'"]
