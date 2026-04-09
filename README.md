[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<div align="center">
  <img src="logo/logo-marca-modo-escuro.png#gh-dark-mode-only" alt="Ouroboros Logo" width="400"/>
  <img src="logo/logo-marca.png#gh-light-mode-only" alt="Ouroboros Logo" width="400"/>
</div>

<h1 align="center">Ouroboros</h1>

<p align="center">
  <strong>Estudo inteligente e autônomo para todos.</strong>
  <br />
  Uma plataforma de estudos inteligente, gratuita e acessível, feita de estudante para estudante.
</p>

<p align="center">
  <img alt="Status" src="https://img.shields.io/badge/status-em%20desenvolvimento-yellow">
  <img alt="Plataforma" src="https://img.shields.io/badge/plataforma-Multiplataforma-brightgreen">
  <img alt="Linguagem" src="https://img.shields.io/badge/feito%20com-Flutter-blue">
</p>

---

## 🐍 Uma Ferramenta com Missão Social

Olá! Meu nome é **Glebson**, e o Ouroboros é um pedaço da minha história.

Eu sempre acreditei que organização, estratégia e tecnologia não deveriam ser um privilégio. Por isso, o Ouroboros nasceu com uma **missão social**: democratizar o acesso a ferramentas de ensino de alta qualidade.

Ele foi criado para ajudar estudantes **hipossuficientes**, pessoas que estudam com poucos recursos, mas com muita determinação. E, principalmente, para ajudar quem — assim como eu — **não tem condições de pagar por assinaturas caras de plataformas de estudo**. A meta sempre foi entregar recursos modernos e inteligentes de forma acessível para todos.

Com a nova versão multiplataforma (Desktop e Android), essa missão fica ainda mais forte.

## ✨ Funcionalidades Principais

Cada funcionalidade foi pensada para resolver um problema real do dia a dia de quem estuda para concursos.

| Funcionalidade | Descrição |
| :--- | :--- |
| 📚 **Catálogo de Matérias Próprio** | Acesse uma base de dados completa com matérias e tópicos, permitindo que você inicie seus estudos sem depender de fontes externas. |
| 🖥️ **Sincronização Wi-Fi** | Estude no celular ou no desktop. Seus dados são sincronizados automaticamente entre dispositivos na mesma rede Wi-Fi, garantindo continuidade. |
| 🔄 **Ciclo de Estudos Personalizado** | Com base no seu tempo disponível e na dificuldade de cada matéria, o app cria um ciclo de estudos equilibrado, garantindo que nada fique para trás. |
| 🧠 **Mentoria Algorítmica** | Foque nos tópicos onde mais errou ou naqueles que deixou de lado. O algoritmo analisa seu histórico para recomendar o que faz mais sentido estudar. |
| 📊 **Estatísticas Detalhadas** | Visualize seu progresso com gráficos intuitivos. Acompanhe sua consistência, horas líquidas, desempenho por matéria e evolução. |
| 📝 **Registro Completo de Atividades** | Anote cada detalhe: tempo de estudo, questões (certas/erradas), páginas lidas, videoaulas assistidas e o status de finalização da teoria de cada tópico. |
| 🎯 **Módulo de Simulados** | Registre e analise seus simulados de forma completa, matéria por matéria, para ter uma visão clara do seu desempenho em um cenário de prova. |

## 🚀 O Futuro do Projeto

Esta versão do Ouroboros, construída em Flutter, **substitui a antiga versão para desktop** e unifica a experiência entre celular e computador. A **sincronização via Wi-Fi já é uma realidade**, permitindo que você mantenha seus dados atualizados entre todos os seus dispositivos.

Eu sou o único desenvolvedor do Ouroboros e, além de cuidar do projeto sozinho, eu também sou **concurseiro**. Estou entrando em uma fase em que vou precisar estudar bastante para um concurso que venho me preparando há muito tempo. Então o desenvolvimento continua, mas em um **ritmo mais humano, mais realista**.

Mesmo assim, cada atualização será feita com o mesmo cuidado e a mesma dedicação de sempre.

## 🆕 Novidades na Versão v1.1.0 (2026-01-19)

Esta atualização foca em aprimorar a estabilidade, a precisão do seu planejamento e a clareza visual, corrigindo bugs importantes e refatorando sistemas internos.

*   **Persistência e Integridade do Ciclo de Estudos Aprimoradas:**
    *   Corrigido um bug crítico onde o progresso do ciclo de estudos podia ser perdido ou dados de ciclos antigos eram indevidamente carregados após a reinicialização do aplicativo ou a criação de um novo ciclo.
    *   Agora, cada ciclo de estudos possui um identificador único (`cycleId`), garantindo que os registros de estudo sejam corretamente vinculados ao seu ciclo correspondente. A lógica de filtragem e migração do banco de dados foi atualizada para suportar esta nova abordagem, proporcionando maior confiabilidade e consistência aos seus dados de progresso.

*   **Gráfico de Rosca (Donut Chart) do Planejamento Totalmente Reformulado:**
    *   O gráfico na tela de planejamento foi redesenhado para uma visualização mais clara e intuitiva do seu progresso.
    *   **Design de Anel Duplo:**
        *   O **anel interno** exibe a composição completa do seu ciclo de estudos, com as fatias de cada sessão em suas cores originais. Sessões já concluídas neste anel são agora renderizadas em um tom de cinza, indicando que foram estudadas sem perder a noção da matéria.
        *   O **anel externo** representa o progresso total acumulado no seu ciclo como um único arco contínuo na cor Teal. Esta nova representação elimina os "buracos" visuais que ocorriam quando sessões eram puladas, garantindo uma progressão suave e em sentido horário.

*   **Correção na Sobrescrita de Dados de Vídeos/Aulas no Registro de Estudos:**
    *   Resolvido um bug no modal de registro de estudos onde informações de vídeo/aulas eram incorretamente sobrescritas ou perdidas ao alternar entre múltiplos tópicos em um mesmo registro. A gestão interna dos campos de entrada foi refatorada para garantir a integridade dos dados para cada tópico.

*   **Atualização da Versão:**
    *   A versão do aplicativo foi atualizada para `1.1.0+1`.

## ❤️ Apoie o Projeto

O Ouroboros é um projeto totalmente independente, feito por uma única pessoa... eu. Se você gostou da proposta, se o app te ajudou de alguma forma, ou se você acredita nessa missão de democratizar o acesso ao estudo, considere apoiar o projeto.

Esse tipo de apoio realmente ajuda. Mantém o projeto vivo, incentiva novas atualizações e me dá fôlego para continuar construindo ferramentas gratuitas para quem mais precisa.

<div align="center">
  <h3>Faça sua contribuição via Pix!</h3>
  <img src="logo/qrcode-pix.png" alt="QR Code Pix" width="200"/>
  <p>Qualquer valor já faz uma grande diferença.</p>
</div>

Se você puder ajudar, de coração, muito obrigado. Se não puder, muito obrigado do mesmo jeito — só de você estar aqui, apoiando a ideia, já é enorme pra mim.

## Licença

Ouroboros Mobile é um software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da **GNU General Public License** versão 3 ou posterior.

Veja o arquivo [LICENSE](LICENSE) para detalhes.

© 2025 Glebson (grebsu)
