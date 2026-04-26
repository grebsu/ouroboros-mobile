#!/bin/bash

# Script para configurar o Android toolchain para desenvolvimento Flutter

echo "============================================================"
echo "   Configurando o Android Toolchain para Flutter"
echo "============================================================"
echo ""

# --- Passo 1: Obter o Caminho do Android SDK --- 
# O usuário já forneceu: /home/glebson/Android/Sdk
ANDROID_SDK_PATH="/home/glebson/Android/Sdk"

# Validar o caminho (somente se não for vazio)
if [ -z "$ANDROID_SDK_PATH" ]; then
    echo "ERRO: O caminho do Android SDK não pode ser vazio."
    exit 1
elif [ ! -d "$ANDROID_SDK_PATH" ]; then
    echo ""
    echo "ERRO: O caminho '$ANDROID_SDK_PATH' não parece ser um diretório válido."
    echo "Por favor, verifique o caminho do seu Android SDK."
    exit 1
fi

# Checar por subdiretórios essenciais e fornecer orientação
CMDLINE_TOOLS_PATH="$ANDROID_SDK_PATH/cmdline-tools"
CMDLINE_TOOLS_LATEST_PATH="$CMDLINE_TOOLS_PATH/latest"
PLATFORM_TOOLS_PATH="$ANDROID_SDK_PATH/platform-tools"

NEEDS_CMDLINE_TOOLS_INSTALL=false
if [ ! -d "$CMDLINE_TOOLS_PATH" ] || [ ! -d "$CMDLINE_TOOLS_LATEST_PATH" ]; then
    echo ""
    echo "AVISO: O diretório 'cmdline-tools/latest' não foi encontrado em '$ANDROID_SDK_PATH'."
    echo "Você precisará instalar as 'Android SDK Command-line Tools (latest)' manualmente." # Corrigido aqui
    echo "Instruções: Abra o Android Studio, vá em 'Settings/Preferences' > 'Appearance & Behavior' > 'System Settings' > 'Android SDK'."
    echo "Na aba 'SDK Tools', marque 'Android SDK Command-line Tools (latest)' e clique em 'Apply'."
    echo "Se você baixou as ferramentas separadamente, certifique-se de que elas estejam em '$CMDLINE_TOOLS_PATH/latest/' (ou na estrutura correta da sua versão)."
    NEEDS_CMDLINE_TOOLS_INSTALL=true
fi

if [ ! -d "$PLATFORM_TOOLS_PATH" ]; then
    echo "AVISO: O diretório 'platform-tools' não foi encontrado em '$ANDROID_SDK_PATH'."
    echo "Você precisará instalar as 'Android SDK Platform-Tools' via Android Studio ('SDK Tools' > 'Android SDK Platform-Tools')."
    echo ""
fi

# --- Passo 2: Atualizar .bashrc ---
BASHRC_FILE="$HOME/.bashrc"
echo "Verificando e atualizando '$BASHRC_FILE'..."

# Adicionar ANDROID_HOME
if grep -q "export ANDROID_HOME=" "$BASHRC_FILE"; then
    echo "ANDROID_HOME já está configurado em '$BASHRC_FILE'. Verificando o caminho..."
    if ! grep -q "export ANDROID_HOME="$ANDROID_SDK_PATH"" "$BASHRC_FILE"; then
        echo "Atualizando ANDROID_HOME para '$ANDROID_SDK_PATH' em '$BASHRC_FILE' (usando sed)..."
        sed -i "s|^export ANDROID_HOME=.*|export ANDROID_HOME="$ANDROID_SDK_PATH"|" "$BASHRC_FILE"
    else
        echo "Caminho ANDROID_HOME já está correto."
    fi
else
    echo "Adicionando ANDROID_HOME ao '$BASHRC_FILE'..."
    echo "" >> "$BASHRC_FILE"
    echo "# Android SDK Path" >> "$BASHRC_FILE"
    echo "export ANDROID_HOME="$ANDROID_SDK_PATH"" >> "$BASHRC_FILE"
fi

# Adicionar ao PATH se não estiver presente
CMDLINE_TOOLS_BIN_FOR_PATH="$CMDLINE_TOOLS_PATH/latest/bin" # Caminho a ser usado no export
PLATFORM_TOOLS_BIN_FOR_PATH="$PLATFORM_TOOLS_PATH"

# Adicionar cmdline-tools/latest/bin ao PATH se não estiver presente
if [ -d "$CMDLINE_TOOLS_LATEST_PATH" ] && ! grep -q "export PATH=.*$CMDLINE_TOOLS_BIN_FOR_PATH" "$BASHRC_FILE"; then
    echo "Adicionando Android cmdline-tools bin ao PATH em '$BASHRC_FILE' (usando sed para evitar duplicatas)..."
    if grep -q "$CMDLINE_TOOLS_BIN_FOR_PATH" "$BASHRC_FILE"; then
        # Se já existe mas não no formato esperado (ex: dentro de uma única export PATH=), vamos adicionar garantindo que não duplique
        sed -i "/export PATH=.*$CMDLINE_TOOLS_BIN_FOR_PATH/!s|\(export PATH="\$PATH:[^"]*\)"|\1:$CMDLINE_TOOLS_BIN_FOR_PATH"|" "$BASHRC_FILE"
    else
        echo "export PATH="\$PATH:$CMDLINE_TOOLS_BIN_FOR_PATH"" >> "$BASHRC_FILE"
    fi
else
    echo "Android cmdline-tools bin path já está no PATH ou o diretório não existe."
fi

# Adicionar platform-tools ao PATH se não estiver presente
if [ -d "$PLATFORM_TOOLS_PATH" ] && ! grep -q "export PATH=.*$PLATFORM_TOOLS_BIN_FOR_PATH" "$BASHRC_FILE"; then
    echo "Adicionando Android platform-tools bin ao PATH em '$BASHRC_FILE' (usando sed para evitar duplicatas)..."
    if grep -q "$PLATFORM_TOOLS_BIN_FOR_PATH" "$BASHRC_FILE"; then
        # Se já existe mas não no formato esperado, vamos adicionar garantindo que não duplique
        sed -i "/export PATH=.*$PLATFORM_TOOLS_BIN_FOR_FOR_PATH/!s|\(export PATH="\$PATH:[^"]*\)"|\1:$PLATFORM_TOOLS_BIN_FOR_PATH"|" "$BASHRC_FILE"
    else
        echo "export PATH="\$PATH:$PLATFORM_TOOLS_BIN_FOR_PATH"" >> "$BASHRC_FILE"
    fi
else
    echo "Android platform-tools bin path já está no PATH ou o diretório não existe."
fi


echo ""
echo ">>> Configurações de ambiente adicionadas/verificadas em '$BASHRC_FILE'."
echo ">>> Para aplicar as mudanças no terminal atual, rode: source ~/.bashrc"
echo ""

# --- Passo 3: Instruir o usuário a rodar os comandos do flutter ---
echo "============================================================"
echo "               Próximos Passos Manuais"
echo "============================================================"
echo ""
echo "1.  **Certifique-se de que os 'Android SDK Command-line Tools (latest)' e 'Android SDK Platform-Tools' estejam instalados via Android Studio**: "
echo "    - Abra o Android Studio."
echo "    - Vá em 'File' > 'Settings' (ou 'Preferences' no macOS)."
echo "    - Navegue até 'Appearance & Behavior' > 'System Settings' > 'Android SDK'."
echo "    - Na aba 'SDK Tools':"
echo "      - Marque 'Android SDK Command-line Tools (latest)' e clique em 'Apply' para instalar/atualizar."
echo "      - Marque 'Android SDK Platform-Tools' e clique em 'Apply' para instalar/atualizar."
echo ""
echo "2.  **Aplique as mudanças no seu terminal**: "
echo "    - No seu terminal, rode: source ~/.bashrc"
echo "    - (Opcional) Feche e reabra o terminal se o comando 'flutter' ainda não for reconhecido."
echo ""
echo "3.  **Aceite as licenças do Android**: "
echo "    - Rode no terminal: flutter doctor --android-licenses"
echo "    - Digite 'y' e pressione Enter para aceitar cada licença."
echo ""
echo "4.  **Verifique tudo novamente**: "
echo "    - Rode no terminal: flutter doctor"
echo ""
echo "Se o 'flutter doctor' ainda mostrar problemas com o Android toolchain, por favor, copie e cole a saída completa aqui."
echo "============================================================"

exit 0
