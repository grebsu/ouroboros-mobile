#!/bin/bash

# Caminho do cartão de memória informado pelo usuário
SD_PATH="/media/glebson/3ea6678d-d1a0-4779-9661-7ebbb415f905"
DEV_DIR="$SD_PATH/development"
FLUTTER_BIN="$DEV_DIR/flutter/bin"

echo "=== Iniciando instalação do Flutter no Cartão SD ==="

# 1. Verificar se o cartão está montado
if [ ! -d "$SD_PATH" ]; then
    echo "ERRO: O cartão não foi encontrado em $SD_PATH"
    echo "Verifique se o cartão está inserido e montado corretamente."
    exit 1
fi

# 2. Criar diretório de desenvolvimento
echo "Criando pasta de desenvolvimento em $DEV_DIR..."
mkdir -p "$DEV_DIR"
cd "$DEV_DIR"

# 3. Clonar o Flutter SDK (se ainda não existir)
if [ ! -d "flutter" ]; then
    echo "Clonando o repositório estável do Flutter (isso pode demorar...)"
    git clone https://github.com/flutter/flutter.git -b stable
else
    echo "Flutter já está clonado. Pulando para configuração..."
fi

# 4. Adicionar ao PATH no .bashrc se ainda não estiver lá
if ! grep -q "$FLUTTER_BIN" "$HOME/.bashrc"; then
    echo "Adicionando Flutter ao PATH no seu .bashrc..."
    echo "" >> "$HOME/.bashrc"
    echo "# Flutter SDK no Cartão SD" >> "$HOME/.bashrc"
    echo "export PATH=\"\$PATH:$FLUTTER_BIN\"" >> "$HOME/.bashrc"
    echo "Configuração adicionada. Você precisará rodar 'source ~/.bashrc' ou reiniciar o terminal."
else
    echo "O caminho do Flutter já existe no seu .bashrc."
fi

# 5. Configuração temporária para a sessão atual e execução do doctor
export PATH="$PATH:$FLUTTER_BIN"

echo "=== Verificando instalação com flutter doctor ==="
flutter doctor

echo "=== Concluído! ==="
echo "DICA: Se o comando 'flutter' não funcionar no próximo terminal, rode: source ~/.bashrc"
