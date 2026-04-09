#!/bin/bash

# Caminho recomendado para instalação do Flutter SDK
FLUTTER_INSTALL_DIR="$HOME/development"
FLUTTER_SDK_PATH="$FLUTTER_INSTALL_DIR/flutter"
FLUTTER_BIN="$FLUTTER_SDK_PATH/bin"

echo "=== Iniciando instalação do Flutter em $FLUTTER_SDK_PATH ==="

# 1. Criar diretório de desenvolvimento se não existir
if [ ! -d "$FLUTTER_INSTALL_DIR" ]; then
    echo "Criando diretório de desenvolvimento em $FLUTTER_INSTALL_DIR..."
    mkdir -p "$FLUTTER_INSTALL_DIR"
    if [ $? -ne 0 ]; then
        echo "ERRO: Não foi possível criar o diretório $FLUTTER_INSTALL_DIR. Verifique as permissões."
        exit 1
    fi
else
    echo "Diretório de desenvolvimento $FLUTTER_INSTALL_DIR já existe."
fi

# Mudar para o diretório de desenvolvimento
cd "$FLUTTER_INSTALL_DIR"

# 2. Clonar o Flutter SDK (se ainda não existir)
if [ ! -d "flutter" ]; then
    echo "Clonando o repositório estável do Flutter (isso pode demorar...)"
    # Verificar se o comando git existe
    if ! command -v git &> /dev/null
then
    echo "ERRO: O comando 'git' não foi encontrado. Por favor, instale o Git primeiro."
    exit 1
fi
    git clone https://github.com/flutter/flutter.git -b stable
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha ao clonar o repositório Flutter."
        exit 1
    fi
else
    echo "Flutter já está clonado. Pulando para configuração..."
fi

# 3. Adicionar ao PATH no .bashrc se ainda não estiver lá
# Criar .bashrc se não existir
if [ ! -f "$HOME/.bashrc" ]; then
    echo "Criando arquivo .bashrc em $HOME"
    touch "$HOME/.bashrc"
fi

# Verifica se a linha de exportação do PATH já existe no .bashrc
if ! grep -q "export PATH="\$PATH:$FLUTTER_BIN"" "$HOME/.bashrc"; then
    echo "Adicionando Flutter ao PATH no seu .bashrc..."
    echo "" >> "$HOME/.bashrc"
    echo "# Flutter SDK (instalado em $FLUTTER_SDK_PATH)" >> "$HOME/.bashrc"
    echo "export PATH="\$PATH:$FLUTTER_BIN"" >> "$HOME/.bashrc"
    echo "Configuração adicionada. Para aplicar as mudanças, rode 'source ~/.bashrc' ou reinicie o terminal."
else
    echo "O caminho do Flutter ($FLUTTER_BIN) já está configurado no seu .bashrc."
fi

# 4. Configuração temporária para a sessão atual (para rodar flutter doctor agora)
export PATH="$PATH:$FLUTTER_BIN"

echo "=== Verificando instalação com flutter doctor ==="
flutter doctor

echo "=== Instalação do Flutter concluída! ==="
echo "Para usar o comando 'flutter' em novos terminais, rode: source ~/.bashrc"
