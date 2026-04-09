#!/bin/bash

echo "============================================================"
echo "          Configurando o Chrome para Desenvolvimento Web"
echo "============================================================"
echo ""

CHROME_EXECUTABLE_PATH=""

# Tentando encontrar o Chrome em locais comuns
echo "Procurando pelo executável do Google Chrome..."

if command -v google-chrome &> /dev/null; then
    CHROME_EXECUTABLE_PATH=$(command -v google-chrome)
    echo "Google Chrome encontrado em: $CHROME_EXECUTABLE_PATH"
elif [ -f "/usr/bin/google-chrome" ]; then
    CHROME_EXECUTABLE_PATH="/usr/bin/google-chrome"
    echo "Google Chrome encontrado em: /usr/bin/google-chrome"
elif [ -f "/opt/google/chrome/google-chrome" ]; then
    CHROME_EXECUTABLE_PATH="/opt/google/chrome/google-chrome"
    echo "Google Chrome encontrado em: /opt/google/chrome/google-chrome"
else
    echo "Google Chrome não encontrado em locais padrão."
    echo "Por favor, instale o Google Chrome se você pretende desenvolver para a web."
    echo "Você pode baixá-lo em: https://www.google.com/chrome/"
    echo ""
    echo "Se você já o tem, mas em um local diferente, o Flutter precisará do caminho completo."
    echo "Você pode definir manualmente no seu ~/.bashrc: export CHROME_EXECUTABLE="/caminho/para/seu/chrome""
fi

if [ -n "$CHROME_EXECUTABLE_PATH" ]; then
    echo ""
    echo "Deseja adicionar 'export CHROME_EXECUTABLE="$CHROME_EXECUTABLE_PATH"' ao seu ~/.bashrc?"
    read -p "Isso ajudará o Flutter a encontrar o Chrome. (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BASHRC_FILE="$HOME/.bashrc"
        if ! grep -q "export CHROME_EXECUTABLE=" "$BASHRC_FILE"; then
            echo "Adicionando CHROME_EXECUTABLE ao '$BASHRC_FILE'..."
            echo "" >> "$BASHRC_FILE"
            echo "# Chrome Executable Path for Flutter Web" >> "$BASHRC_FILE"
            echo "export CHROME_EXECUTABLE="$CHROME_EXECUTABLE_PATH"" >> "$BASHRC_FILE"
            echo "Configuração adicionada. Para aplicar, rode 'source ~/.bashrc' ou reinicie o terminal."
        else
            echo "CHROME_EXECUTABLE já está configurado no seu '$BASHRC_FILE'. Verificando o caminho..."
            if ! grep -q "export CHROME_EXECUTABLE="$CHROME_EXECUTABLE_PATH"" "$BASHRC_FILE"; then
                echo "Atualizando CHROME_EXECUTABLE para '$CHROME_EXECUTABLE_PATH' em '$BASHRC_FILE'..."
                sed -i "s|^export CHROME_EXECUTABLE=.*|export CHROME_EXECUTABLE="$CHROME_EXECUTABLE_PATH"|" "$BASHRC_FILE"
            else
                echo "Caminho CHROME_EXECUTABLE já está correto."
            fi
        fi
        # Configuração temporária para a sessão atual
        export CHROME_EXECUTABLE="$CHROME_EXECUTABLE_PATH"
    fi
fi

echo ""
echo ">>> Para aplicar as mudanças no terminal atual, rode: source ~/.bashrc"
echo ""
echo "=== Verificando instalação com flutter doctor ==="
flutter doctor

echo "============================================================"
echo "          Configuração do Chrome Concluída!"
echo "============================================================"

exit 0
