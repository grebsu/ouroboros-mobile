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
  <img alt="Status" src="https://img.shields.io/badge/status-em%20desenvolvimento-yellow">
  <img alt="Plataforma" src="https://img.shields.io/badge/plataforma-Android%20%7C%20Linux%20%7C%20Windows-brightgreen">
  <img alt="Linguagem" src="https://img.shields.io/badge/feito%20com-Flutter-blue">
  <img alt="Android" src="https://img.shields.io/badge/Android-APK-brightgreen">
  <img alt="Flatpak" src="https://img.shields.io/badge/Flatpak-Em%20breve-4a86e8">
</p>

---

## 🐍 Uma Ferramenta com Missão Social

Olá! Meu nome é **Glebson**, e o Ouroboros Mobile é um pedaço da minha história.

Eu sempre acreditei que organização, estratégia e tecnologia não deveriam ser um privilégio. Por isso, o Ouroboros nasceu com uma **missão social**: democratizar o acesso a ferramentas de ensino de alta qualidade. Com seu **banco de dados seguro e criptografado com SQLCipher**, garantimos a privacidade dos seus dados.

Ele foi criado para ajudar estudantes **hipossuficientes**, pessoas que estudam com poucos recursos, mas com muita determinação. E, principalmente, para ajudar quem — assim como eu — **não tem condições de pagar por assinaturas caras de plataformas de estudo**. A meta sempre foi entregar recursos modernos e inteligentes de forma acessível para todos.

Com a versão multiplataforma (Android, Linux e Windows), essa missão fica ainda mais forte.

## 📦 Download e Instalação

### 🤖 Android (APK)
Baixe a versão mais recente diretamente:

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge&logo=android)](https://github.com/grebsu/ouroboros-mobile/releases/latest)

```bash
# Ou via terminal com wget
wget https://github.com/grebsu/ouroboros-mobile/releases/latest/download/ouroboros-mobile.apk
adb install ouroboros-mobile.apk
```

**Requisitos:** Android 5.0 (API 21) ou superior

### 🐧 Linux

#### Flatpak (Recomendado)
```bash
flatpak install flathub com.ouroboros.mobile
```

#### Pacote .deb (Ubuntu/Debian/Zorin)
```bash
# Baixe o .deb da página de releases
sudo dpkg -i ouroboros-mobile_1.1.1_amd64.deb
sudo apt install -f  # Resolve dependências
```

#### Dependências manuais (se necessário)
```bash
# Ubuntu/Debian
sudo apt install libsqlcipher1 libjsoncpp25 libsecret-1-0

# Fedora
sudo dnf install sqlcipher jsoncpp libsecret

# Arch Linux
sudo pacman -S sqlcipher jsoncpp libsecret
```

### 🪟 Windows
Baixe o instalador `.exe` na [página de releases](https://github.com/grebsu/ouroboros-mobile/releases).

---

## 💻 Desenvolvimento

### Pré-requisitos
```bash
flutter 3.27+
dart 3.6+
```

### Build para Android (APK)
```bash
git clone https://github.com/grebsu/ouroboros-mobile.git
cd ouroboros-mobile
flutter pub get
flutter build apk --release
# APK gerado em: build/app/outputs/flutter-apk/app-release.apk
```

### Build para Linux (.deb)
```bash
flutter build linux --release
# Construa o pacote .deb manualmente ou via script
```

### Build Flatpak
```bash
cd flatpak
flatpak-builder --force-clean build-dir com.ouroboros.mobile.yml
```

### 📖 Guia para Desenvolvedores

Para instruções detalhadas de desenvolvimento, incluindo:
- Configuração do ambiente de desenvolvimento
- Estrutura do projeto
- Adicionando novas funcionalidades
- Convenções de código
- Processo de Pull Request

Consulte o **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)**.

---

## ✨ Funcionalidades Principais

Cada funcionalidade foi pensada para resolver um problema real do dia a dia de quem estuda para concursos.

| Funcionalidade | Descrição |
| :--- | :--- |
| 📚 **Catálogo de Matérias Próprio** | Base de dados completa com matérias e tópicos prontos para uso. |
| 🖥️ **Sincronização Wi-Fi (mDNS)** | Estude no celular ou desktop com sincronização automática na mesma rede. |
| 🔄 **Ciclo de Estudos Personalizado** | Alocação inteligente do seu tempo baseada em disponibilidade e dificuldade das matérias. |
| 🧠 **Mentoria Algorítmica** | Recomendações personalizadas baseadas no seu histórico de erros e lacunas. |
| 📊 **Estatísticas Detalhadas** | Gráficos intuitivos de progresso, consistência, horas líquidas e desempenho. |
| 📝 **Registro Completo de Atividades** | Anote tempo de estudo, questões, páginas lidas, videoaulas e teoria concluída. |
| 🎯 **Módulo de Simulados** | Análise detalhada de simulados, matéria por matéria. |
| 🔒 **Criptografia Local (SQLCipher)** | Seus dados são armazenados com segurança máxima no seu dispositivo. |

---

## 🆕 Novidades na Versão v1.1.1 (2026-04-18)

### ✨ Adições
- **APK disponível para Android** com suporte nativo
- **Flatpak** publicado no Flathub (pendente aprovação)
- **Pacote .deb** para distribuições Linux baseadas em Debian
- Suporte nativo ao SQLCipher via FFI no Linux
- Busca dinâmica da biblioteca `libsqlcipher.so` no sistema

### 🐛 Correções
- Persistência de usuários corrigida (não são mais perdidos após restart)
- Prevenção de registros duplicados com mesmo nome de usuário
- Migração do sistema de login de memória para banco SQLite persistente

### 🔧 Empacotamento Profissional
- Instalador `.deb` com gerenciamento automático de dependências
- Estrutura organizada para distribuição em lojas (Flathub, Snap Store futuramente)

---

## Versão Anterior - v1.1.0 (2026-01-19)

### 🔒 Estabilidade e Visual
- **Ciclo de Estudos:** Identificador único (`cycleId`) para evitar perda de progresso
- **Gráfico de Rosca:** Novo design de anel duplo com progressão suave
- **Registro de Estudos:** Corrigida sobrescrita de dados de vídeos/aulas ao alternar tópicos

---

Aqui está a seção corrigida:

## 🗺️ Roadmap

### ✅ Concluído (ou quase...)
- [x] Sincronização local via Wi-Fi (mDNS)
- [x] Banco de dados criptografado com SQLCipher
- [x] APK para Android
- [x] Pacote .deb para Linux
- [x] Submissão ao Flathub
- [ ] Executável para Windows


### 🚧 Próximas Melhorias
- [ ] Ajustar criação de disciplina
- [ ] Automatizar seleção randômica de cores para disciplinas
- [ ] Implementar tópicos colapsáveis em modals
- [ ] Ajuste fino do layout visual de páginas específicas

### 🔜 Futuro
- [ ] Sincronização via nuvem
- [ ] Widgets Android
- [ ] Notificações de revisão espaçada
```
---

## 💻 Desenvolvimento

### Pré-requisitos
```bash
flutter 3.27+
dart 3.6+
```

### Build para Android (APK)
```bash
git clone https://github.com/grebsu/ouroboros-mobile.git
cd ouroboros-mobile
flutter pub get
flutter build apk --release
# APK gerado em: build/app/outputs/flutter-apk/app-release.apk
```

### Build para Linux (.deb)
```bash
flutter build linux --release
# Construa o pacote .deb manualmente ou via script
```

### Build Flatpak
```bash
cd flatpak
flatpak-builder --force-clean build-dir com.ouroboros.mobile.yml
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para:

1. Reportar bugs via [Issues](https://github.com/grebsu/ouroboros-mobile/issues)
2. Sugerir melhorias nas [Discussões](https://github.com/grebsu/ouroboros-mobile/discussions)
3. Enviar Pull Requests (consulte o estilo de código antes)

---

## 🐛 Reportar Problemas

Ao reportar um bug, inclua:
- Versão do app
- Sistema operacional e versão
- Passos para reproduzir o erro
- Logs ou screenshots (se possível)

---

## ❤️ Apoie o Projeto

O Ouroboros Mobile é um projeto totalmente independente, feito por uma única pessoa... eu. Se você gostou da proposta, se o app te ajudou de alguma forma, ou se você acredita nessa missão de democratizar o acesso ao estudo, considere apoiar o projeto.

Esse tipo de apoio realmente ajuda. Mantém o projeto vivo, incentiva novas atualizações e me dá fôlego para continuar construindo ferramentas gratuitas para quem mais precisa.

<div align="center">
  <h3>💰 Faça sua contribuição via Pix!</h3>
  <img src="logo/qrcode-pix.png" alt="QR Code Pix" width="200"/>
  <p><strong>Chave Pix (email):</strong> glebson@example.com</p>
  <p>Qualquer valor já faz uma grande diferença. ❤️</p>
</div>

Se você puder ajudar, de coração, muito obrigado. Se não puder, muito obrigado do mesmo jeito — só de você estar aqui, apoiando a ideia, já é enorme pra mim.

---

## 📄 Licença

Ouroboros Mobile é um software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da **GNU General Public License** versão 3 ou posterior.

Veja o arquivo [LICENSE](LICENSE) para detalhes.

---

<div align="center">
  <sub>Feito com 🐍 e ☕ por <strong>Glebson (grebsu)</strong></sub>
  <br />
  <sub>© 2025-2026</sub>
</div>
