#!/bin/bash

# Script para rodar o Ouroboros Mobile no Linux com suporte a SQLCipher
# Requer que a biblioteca libsqlcipher.so tenha sido compilada e esteja em /usr/local/lib/libsqlite3.so

export LD_PRELOAD=/usr/local/lib/libsqlite3.so
echo "🚀 Iniciando Ouroboros com SQLCipher (LD_PRELOAD)..."
flutter run -d linux
