[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<div align="center">
  <img src="logo/logo-marca-modo-escuro.png#gh-dark-mode-only" alt="Ouroboros Logo" width="400"/>
  <img src="logo/logo-marca.png#gh-light-mode-only" alt="Ouroboros Logo" width="400"/>
</div>

<h1 align="center">Ouroboros Mobile</h1>

<p align="center">
  <strong>Estudo inteligente e autônomo para todos.</strong>
  <br />
  Uma plataforma de estudos inteligente, gratuita e acessível, feita de estudante para estudante.
</p>

<p align="center">
  <img alt="Status" src="https://img.shields.io/badge/status-est%C3%A1vel-brightgreen">
  <img alt="Versão" src="https://img.shields.io/badge/vers%C3%A3o-1.1.2%20Hotfix-orange">
  <img alt="Plataforma" src="https://img.shields.io/badge/plataforma-Android%20%7C%20Linux%20%7C%20Windows-brightgreen">
  <img alt="Linguagem" src="https://img.shields.io/badge/feito%20com-Flutter-blue">
</p>

---

## 🐍 Uma Ferramenta com Missão Social

Olá! Meu nome é **Glebson**, e o Ouroboros Mobile é um pedaço da minha história.

O Ouroboros nasceu com uma **missão social**: democratizar o acesso a ferramentas de ensino de alta qualidade. Criado para ajudar estudantes **hipossuficientes**, pessoas que estudam com poucos recursos, mas com muita determinação, o app oferece recursos modernos e inteligentes de forma totalmente gratuita e segura.

Com o uso do **SQLCipher**, garantimos que seus dados de estudo permaneçam privados e protegidos localmente em seu dispositivo.

---

## 📦 Download e Instalação

### 🤖 Android (APK)
Baixe a versão estável mais recente diretamente:

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge&logo=android)](https://github.com/grebsu/ouroboros-mobile/releases/latest)

**Requisitos:** Android 5.0 (API 21) ou superior. Recomenda-se Android 10+ para melhor desempenho do sistema de arquivos criptografado.

### 🐧 Linux (64-bit)
Baixe a versão mais recente em formato `.deb` ou binário comprimido:

[![Download Linux](https://img.shields.io/badge/Download-Linux-blue?style=for-the-badge&logo=linux)](https://github.com/grebsu/ouroboros-mobile/releases/latest)

**Instalação (.deb):**
```bash
sudo dpkg -i ouroboros-mobile_*.deb
sudo apt install -f
```

### 🪟 Windows (64-bit)
Suporte oficial em fase beta. Baixe o instalador ou executável portátil:

[![Download Windows](https://img.shields.io/badge/Download-Windows-blue?style=for-the-badge&logo=windows)](https://github.com/grebsu/ouroboros-mobile/releases/latest)

**Requisitos:** Windows 10 ou superior (64-bit).

---

## ✨ Funcionalidades Principais

| Funcionalidade | Descrição |
| :--- | :--- |
| 📚 **Catálogo de Matérias Próprio** | Base de dados completa com matérias e tópicos prontos para uso. |
| 🖥️ **Sincronização Wi-Fi (mDNS)** | Estude no celular ou desktop com sincronização automática na mesma rede. |
| 🔄 **Ciclo de Estudos Personalizado** | Alocação inteligente do seu tempo baseada em disponibilidade e dificuldade das matérias. |
| 📊 **Estatísticas Detalhadas** | Gráficos intuitivos de progresso, consistência e horas líquidas. |
| 🔒 **Criptografia Local (SQLCipher)** | Seus dados são armazenados com segurança máxima AES-256. |

---

## 🆕 Novidades na Versão v1.1.2 Hotfix (2026-04-25)

### 🐛 Correções Críticas e Estabilidade
- **SQLCipher Nativo:** Substituição do motor de banco de dados por `sqflite_sqlcipher` oficial, garantindo estabilidade total no Android e Linux.
- **Resiliência Keystore:** Implementação de mecanismos de recuperação automática para evitar travamentos em dispositivos **Xiaomi/MIUI**.
- **Build Unificado:** O Linux agora utiliza a mesma lógica de segurança do Android, permitindo portabilidade total dos dados via Sync.
- **Feedback de Auth:** Melhores diagnósticos e mensagens visuais durante o fluxo de registro e login.

---

## 🗺️ Roadmap

### ✅ Concluído
- [x] Sincronização local via Wi-Fi (mDNS)
- [x] Banco de dados criptografado com SQLCipher (AES-256)
- [x] APK Estável para Android
- [x] Suporte Multiplataforma (Linux, Android, Windows)

### 🚧 Próximas Melhorias
- [ ] Ajustar criação de disciplina personalizada
- [ ] Automatizar seleção randômica de cores para disciplinas
- [ ] Implementar tópicos colapsáveis em modals de registro

### 🔜 Futuro
- [ ] Sincronização via nuvem (opcional)
- [ ] Notificações de revisão espaçada (Push)

---

## 💻 Desenvolvimento

### Compilar para Android (APK)
```bash
flutter build apk --release
```

### Compilar para Linux (.deb)
```bash
flutter build linux --release
# Utilize os ativos gerados em build/linux/x64/release/bundle
```

---

## ❤️ Apoie o Projeto

O Ouroboros Mobile é um projeto independente. Se ele te ajudou, considere fazer uma contribuição para manter o desenvolvimento ativo e os recursos sempre gratuitos.

<div align="center">
  <h3>💰 Faça sua contribuição via Pix!</h3>
  <img src="logo/qrcode-pix.png" alt="QR Code Pix" width="200"/>
  <p><strong>Chave Pix (email):</strong> glebson@example.com</p>
  <p>Qualquer valor ajuda a democratizar o estudo. ❤️</p>
</div>

---

## 📄 Licença

Ouroboros Mobile é um software livre sob a **GNU General Public License v3**.

---

<div align="center">
  <sub>Feito com 🐍 e ☕ por <strong>Glebson (grebsu)</strong></sub>
  <br />
  <sub>© 2025-2026</sub>
</div>
