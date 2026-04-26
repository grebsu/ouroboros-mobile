#!/bin/bash
set -e

echo "🚀 Iniciando a instalação do GitHub CLI..."

# Garante que dependências básicas existam
sudo apt update
sudo apt install -y wget curl

# Adiciona o repositório oficial
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Atualiza e instala
sudo apt update
sudo apt install gh -y

echo "✅ GitHub CLI instalado com sucesso!"
echo "👉 Agora, por favor, execute 'gh auth login' no seu terminal para se autenticar."
