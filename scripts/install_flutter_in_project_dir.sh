#!/bin/bash

# Caminho onde o Flutter SDK será instalado
FLUTTER_INSTALL_PATH="/home/glebson/StudioProjects"
FLUTTER_BIN="$FLUTTER_INSTALL_PATH/flutter/bin"

echo "=== Iniciando instalação do Flutter em $FLUTTER_INSTALL_PATH ==="

# 1. Verificar e criar o diretório de instalação
if [ ! -d "$FLUTTER_INSTALL_PATH" ]; then
    echo "Criando diretório de instalação em $FLUTTER_INSTALL_PATH..."
    mkdir -p "$FLUTTER_INSTALL_PATH"
    if [ $? -ne 0 ]; then
        echo "ERRO: Não foi possível criar o diretório $FLUTTER_INSTALL_PATH. Verifique as permissões."
        exit 1
    fi
else
    echo "Diretório de instalação $FLUTTER_INSTALL_PATH já existe."
fi

# Mudar para o diretório de instalação
cd "$FLUTTER_INSTALL_PATH"

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

if ! grep -q "$FLUTTER_BIN" "$HOME/.bashrc"; then
    echo "Adicionando Flutter ao PATH no seu .bashrc..."
    echo "" >> "$HOME/.bashrc"
    echo "# Flutter SDK instalado em $FLUTTER_INSTALL_PATH" >> "$HOME/.bashrc"
    echo "export PATH="\$PATH:$FLUTTER_BIN"" >> "$HOME/.bashrc"
    echo "Configuração adicionada. Para aplicar, rode 'source ~/.bashrc' ou reinicie o terminal."
else
    echo "O caminho do Flutter ($FLUTTER_BIN) já existe no seu .bashrc."
fi

# 4. Configuração temporária para a sessão atual
export PATH="$PATH:$FLUTTER_BIN"

echo "=== Verificando instalação com flutter doctor ==="
flutter doctor

echo "=== Concluído! ==="
echo "DICA: Se o comando 'flutter' não funcionar no próximo terminal, rode: source ~/.bashrc"
