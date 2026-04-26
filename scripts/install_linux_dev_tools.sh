#!/bin/bash

echo "============================================================"
echo "          Instalando Ferramentas de Desenvolvimento Linux"
echo "============================================================"
echo ""

echo "Atualizando a lista de pacotes..."
sudo apt update || { echo "ERRO: Falha ao atualizar a lista de pacotes."; exit 1; }

echo "Instalando CMake, ninja-build e libgtk-3-dev..."
sudo apt install -y cmake ninja-build libgtk-3-dev || { echo "ERRO: Falha ao instalar um ou mais pacotes. Verifique os logs acima."; exit 1; }

echo ""
echo "============================================================"
echo "      Instalação das Ferramentas Linux Concluída!"
echo "============================================================"
echo ""
echo "Agora, vamos verificar o status do Flutter novamente."

exit 0
