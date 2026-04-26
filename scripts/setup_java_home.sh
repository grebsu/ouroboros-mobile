#!/bin/bash

# Script para configurar JAVA_HOME para OpenJDK 17 no Linux

echo "============================================================"
echo "          Configurando JAVA_HOME para OpenJDK 17"
echo "============================================================"
echo ""

# Tenta encontrar o caminho do OpenJDK 17
JAVA_PATH=$(update-alternatives --query java | grep 'Value: /usr/lib/jvm/java-17-openjdk-amd64/bin/java' | awk '{print $2}' | sed 's#/bin/java##')

if [ -z "$JAVA_PATH" ]; then
    # Se não encontrar via update-alternatives (ou a saída for diferente), tenta um caminho padrão
    echo "Não foi possível encontrar OpenJDK 17 via update-alternatives. Tentando caminho padrão..."
    if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
        JAVA_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
    elif [ -d "/usr/lib/jvm/default-java" ]; then
        # Last resort: if default-java points to 17
        echo "Verificando se /usr/lib/jvm/default-java aponta para OpenJDK 17..."
        if readlink -f /usr/lib/jvm/default-java | grep -q "java-17-openjdk"; then
            JAVA_PATH="/usr/lib/jvm/default-java"
        fi
    fi
fi

if [ -z "$JAVA_PATH" ]; then
    echo "ERRO: Não foi possível localizar a instalação do OpenJDK 17."
    echo "Por favor, certifique-se de que o OpenJDK 17 esteja instalado (ex: sudo apt install openjdk-17-jdk)."
    echo "Você pode precisar definir manualmente JAVA_HOME no seu .bashrc para o caminho correto."
    exit 1
fi

echo "OpenJDK 17 encontrado em: $JAVA_PATH"

# --- Atualizar .bashrc ---
BASHRC_FILE="$HOME/.bashrc"
echo "Verificando e atualizando '$BASHRC_FILE'..."

# Adicionar/Atualizar JAVA_HOME
if grep -q "export JAVA_HOME=" "$BASHRC_FILE"; then
    echo "JAVA_HOME já está configurado em '$BASHRC_FILE'. Verificando o caminho..."
    if ! grep -q "export JAVA_HOME="$JAVA_PATH"" "$BASHRC_FILE"; then
        echo "Atualizando JAVA_HOME para '$JAVA_PATH' em '$BASHRC_FILE'..."
        sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME="$JAVA_PATH"|" "$BASHRC_FILE"
    else
        echo "Caminho JAVA_HOME já está correto."
    fi
else
    echo "Adicionando JAVA_HOME ao '$BASHRC_FILE'..."
    echo "" >> "$BASHRC_FILE"
    echo "# Java Home for Android SDK" >> "$BASHRC_FILE"
    echo "export JAVA_HOME="$JAVA_PATH"" >> "$BASHRC_FILE"
fi

# Adicionar JAVA_HOME/bin ao PATH se não estiver presente
JAVA_BIN_PATH="$JAVA_PATH/bin"
if ! grep -q "export PATH=.*$JAVA_BIN_PATH" "$BASHRC_FILE"; then
    echo "Adicionando Java bin ao PATH em '$BASHRC_FILE'..."
    echo "export PATH="\$PATH:$JAVA_BIN_PATH"" >> "$BASHRC_FILE"
else
    echo "Caminho Java bin já está no PATH."
fi

echo ""
echo ">>> Configurações de ambiente adicionadas/verificadas em '$BASHRC_FILE'."
echo ">>> Para aplicar as mudanças no terminal atual, rode: source ~/.bashrc"
echo ""

# --- Próximos passos ---
echo "============================================================"
echo "                 Próximos Passos Essenciais"
echo "============================================================"
echo ""
echo "1.  **Instale o OpenJDK 17 se ainda não o fez:**"
echo "    - Rode: sudo apt install openjdk-17-jdk"
echo "2.  **Aplique as mudanças no seu terminal ATUAL:**"
echo "    - Rode: source ~/.bashrc"
echo "    - (Opcional) Feche e reabra o terminal se o comando 'java' não for reconhecido."
echo "3.  **Verifique a instalação do Java:**"
echo "    - Rode: java -version"
echo "    - Rode: javac -version"
echo "4.  **Aceite as licenças do Android (se ainda não o fez):**"
echo "    - Rode: flutter doctor --android-licenses"
echo "5.  **Execute o Flutter Doctor novamente para verificar o ambiente completo:**"
echo "    - Rode: flutter doctor"
echo ""
echo "Se encontrar algum problema, por favor, copie e cole a saída completa aqui."
echo "============================================================"

exit 0
