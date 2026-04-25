# Guia do Desenvolvedor - Ouroboros Mobile

Este guia tem como objetivo fornecer informações essenciais para desenvolvedores que desejam entender, configurar e contribuir para o projeto Ouroboros Mobile.

## 1. Introdução

O Ouroboros Mobile é um aplicativo Flutter projetado para auxiliar estudantes na organização e otimização de seus estudos. Ele oferece funcionalidades como planejamento de estudos, acompanhamento de progresso, revisões programadas, simulados, e sincronização de dados entre dispositivos.

## 2. Configuração do Ambiente

### 2.1. Pré-requisitos

Certifique-se de ter instalado:
- Flutter SDK
- Dart SDK
- Um editor de código (VS Code, Android Studio) com os plugins do Flutter e Dart.
- Para desenvolvimento em Linux Desktop, as seguintes dependências são necessárias:
  ```bash
  sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsqlcipher1 libsqlcipher-dev libsecret-1-dev libjsoncpp-dev
  ```

### 2.2. Configuração do SQLCipher (Linux)

O projeto utiliza **SQLCipher** para criptografia do banco de dados SQLite no Linux via FFI. A inicialização é feita no arquivo `lib/sqlcipher_init.dart`.

*   **Dependência:** É necessário ter o pacote `libsqlcipher1` instalado no sistema.
*   **Carregamento Dinâmico:** O app tenta carregar `libsqlcipher.so` dos diretórios padrão do sistema. Se falhar, utiliza um fallback para o caminho comum no Ubuntu/Debian (`/usr/lib/x86_64-linux-gnu/libsqlcipher.so`).
*   **Chave de Criptografia:** A chave é gerada na primeira execução e armazenada com segurança usando `flutter_secure_storage` (que utiliza o **Libsecret** no Linux).

### 2.3. Clonando o Repositório

```bash
git clone <URL_DO_REPOSITORIO>
cd ouroboros-mobile
```

### 2.3. Instalando Dependências

```bash
flutter pub get
```

### 2.4. Executando o Aplicativo

Para rodar em desenvolvimento:
```bash
flutter run
```

Para rodar em outros dispositivos (como Chrome ou Android Emulator):
```bash
flutter run -d chrome
# ou
flutter run -d <id_do_dispositivo_android>
```

## 3. Estrutura do Projeto

A estrutura do código é organizada para facilitar a manutenção e a escalabilidade.

### 3.1. Diretório `lib/`

O diretório `lib/` contém a maior parte do código fonte do aplicativo.

*   **`main.dart`**: Ponto de entrada principal da aplicação. Inicializa o Flutter, configura os Providers globais, define o tema e a rota inicial.
*   **`data/`**: Contém a lógica de acesso a dados de baixo nível.
    *   **`database/`**: Define o schema e as migrações do banco de dados (ex: `schema_v3.dart`, `migration_v2_to_v3.dart`).
    *   **`repositories/`**: Implementa o padrão Repository para abstrair o acesso aos dados (ex: `study_repository.dart`).
*   **`models/`**: Define as estruturas de dados (classes Dart) que representam as entidades do aplicativo.
    *   **`data_models.dart`**: Modelos principais como `StudyRecord`, `Plan`, `Topic`, `Subject`.
    *   **`backup_model.dart`**: Modelos para exportação/importação de dados.
    *   **`loading_state.dart`**: Modelos para representar estados de carregamento.
*   **`providers/`**: Contém as classes que gerenciam o estado da aplicação, utilizando o pacote `provider`. Cada arquivo geralmente representa um domínio de estado (ex: `AuthProvider`, `PlansProvider`, `StopwatchProvider`).
*   **`screens/`**: Cada arquivo representa uma tela completa da aplicação. Telas acessíveis pela `BottomNavigationBar` e pelo `Drawer` estão organizadas aqui ou em subdiretórios.
*   **`services/`**: Implementa funcionalidades de backend ou de utilidade, como `DatabaseService` (acesso a banco de dados SQLite), `SyncService` (sincronização de dados P2P via mDNS), `MdnsAdvertiser`/`MdnsDiscoveryService`.
*   **`widgets/`**: Contém componentes de UI reutilizáveis.
    *   **`charts/`**: Widgets de gráficos especializados (ex: `category_hours_chart.dart`, `evolucao_tempo_chart.dart`).
    *   **`simulados/`**: Widgets específicos para a área de simulados (ex: `simulado_card.dart`, `simulado_line_chart.dart`).
    *   **Raiz de `widgets/`**: Modais, seções e componentes genéricos (ex: `FloatingStopwatchButton`, `DonutChart`, `StudyRegisterModal`).

### 3.2. Outros Diretórios

*   **`android/`**, **`ios/`**, **`linux/`**, **`macos/`**, **`web/`**, **`windows/`**: Contêm as configurações específicas de cada plataforma para aplicações Flutter.
*   **`assets/`**: Arquivos estáticos como imagens, fontes, dados JSON (ex: `assets/data/materias_com_assuntos.json`).
*   **`test/`**: Contém os testes unitários e de widget do projeto.

## 4. Ponto de Entrada (`main.dart`)

O arquivo `lib/main.dart` é o ponto de partida da aplicação Flutter.

### 4.1. Inicialização

*   `WidgetsFlutterBinding.ensureInitialized()`: Garante que os bindings do Flutter estejam inicializados antes de qualquer chamada nativa.
*   `sqfliteFfiInit()` e `databaseFactory = databaseFactoryFfi`: Configuração para usar o SQLite em desktops (Linux, Windows, macOS).
*   `InAppWebViewController.setWebContentsDebuggingEnabled(true)`: Habilita a depuração para webviews em Android.
*   `initializeDateFormatting('pt_BR', null)`: Define a formatação de datas e horas para o português do Brasil.
*   **`runApp(const RootWidget())`**: Inicia a árvore de widgets da aplicação com o `RootWidget`.

### 4.2. `RootWidget` e Gerenciamento de Estado Global

O `RootWidget` utiliza `MultiProvider` para configurar todos os `ChangeNotifierProvider`s e `ChangeNotifierProxyProvider`s que gerenciam o estado global da aplicação. Isso garante que os providers estejam acessíveis em toda a árvore de widgets.

**Principais Providers Configurados:**
*   `AuthProvider`: Gerencia o estado de autenticação do usuário.
*   `NavigationProvider`: Controla a navegação entre as telas principais (BottomNavigationBar e Drawer).
*   `StopwatchProvider`: Gerencia o estado do cronômetro.
*   `PlansProvider`: Carrega e gerencia os planos de estudo do usuário.
*   `AllSubjectsProvider`: Fornece dados sobre todas as matérias e seus assuntos, dependendo de `AuthProvider` e `PlansProvider`.
*   `ActivePlanProvider`: Gerencia o plano de estudo atualmente ativo.
*   `ReviewProvider`: Gerencia o estado das revisões.
*   `FilterProvider`: Gerencia os filtros aplicados em diferentes partes do app.
*   `HistoryProvider`: Carrega e gerencia o histórico de estudos, dependendo de `ReviewProvider`, `FilterProvider` e `AuthProvider`.
*   `SubjectProvider`: Provavelmente para gerenciar detalhes de matérias específicas.
*   `MentoriaProvider`: Gerencia o estado relacionado à mentoria.
*   `RemindersProvider`: Gerencia lembretes.
*   `SimuladosProvider`: Gerencia o estado dos simulados.
*   `PlanningProvider`: Gerencia o planejamento de estudos e ciclos de estudo, com dependências de `MentoriaProvider`, `AuthProvider` e `HistoryProvider`.

**Nota:** `ChangeNotifierProxyProvider` é usado para criar providers que dependem de outros providers já existentes. O método `update` é chamado quando as dependências mudam.

### 4.3. `MyApp` (Widget Principal da Aplicação)

`MyApp` é um `StatefulWidget` que gerencia o ciclo de vida da aplicação e a lógica de auto-login.

*   **Serviços de Sincronização:** `SyncService`, `MdnsAdvertiser` e `MdnsDiscoveryService` são configurados e iniciados/parados com base no estado de login do `AuthProvider`. O `MdnsAdvertiser` anuncia a presença do dispositivo na rede local para permitir a sincronização P2P. O `SyncService` gerencia a comunicação.
*   **`_tryAutoLoginFuture`**: Tenta realizar um login automático quando o aplicativo inicia.
*   **`snackbarKey`**: Uma `GlobalKey` para exibir `SnackBar`s globalmente.
*   **`ThemeData`**: Define os temas claro e escuro do aplicativo, com cores personalizadas (teal, tons de cinza e azul escuro).
*   **Rota Inicial**: Renderiza `HomePage` se o usuário estiver logado, ou `LoginScreen`/`SplashScreen` caso contrário, com base no resultado do auto-login.
*   **`HomePage`**: O widget principal que contém a `Scaffold`, `AppBar`, `Drawer`, `BottomNavigationBar`, e o `FloatingStopwatchButton`. Ele gerencia a navegação entre as diferentes seções do app.
*   **`FloatingStopwatchButton`**: Um widget flutuante para iniciar o cronômetro, posicionado de forma que possa ser arrastado.

---

## 5. Gerenciamento de Estado (Providers)

Os `ChangeNotifier`s são usados para gerenciar o estado da aplicação. Abaixo, uma descrição de cada provider encontrado no diretório `lib/providers/`:

### 5.1. `active_plan_provider.dart`

*   **Propósito:** Gerencia qual plano de estudo está ativo no momento.
*   **Dependências:** `AuthProvider` (para obter o ID do usuário).
*   **Funcionalidades:**
    *   Carrega o `activePlanId` salvo (provavelmente no `SharedPreferences` ou similar).
    *   Define e salva o plano ativo.
    *   Carrega os planos disponíveis usando `PlansProvider`.
    *   Define o primeiro plano como ativo se nenhum estiver selecionado.
    *   Fornece o `activePlan` completo para que outros widgets possam acessá-lo.

### 5.2. `all_subjects_provider.dart`

*   **Propósito:** Carrega e gerencia todos os dados relacionados a matérias (disciplinas) e seus assuntos.
*   **Dependências:** `AuthProvider`, `PlansProvider`.
*   **Funcionalidades:**
    *   Busca dados de matérias e assuntos, possivelmente associados aos planos ativos.
    *   Mantém uma lista de todas as matérias disponíveis.
    *   Pode ter lógica para recarregar dados quando `AuthProvider` ou `PlansProvider` mudam.

### 5.3. `auth_provider.dart`

*   **Propósito:** Gerencia o estado de autenticação do usuário (login, logout, auto-login).
*   **Dependências:** Nenhuma direta para inicialização, mas é uma dependência chave para muitos outros providers e telas.
*   **Funcionalidades:**
    *   Armazena informações do usuário atual (`currentUser`).
    *   Implementa `tryAutoLogin()` para tentar autenticar o usuário automaticamente na inicialização.
    *   Métodos `login()` e `logout()`.
    *   Mantém o estado `isLoggedIn`.
    *   É listener para `_authListener` em `MyApp` para iniciar/parar serviços de sincronização.

### 5.4. `filter_provider.dart`

*   **Propósito:** Gerencia os filtros aplicados em diferentes partes da aplicação, como nas telas de Histórico ou Estatísticas.
*   **Dependências:** Nenhuma.
*   **Funcionalidades:**
    *   Armazena os critérios de filtro selecionados (categorias, assuntos, datas).
    *   Notifica os listeners (geralmente providers que exibem dados filtrados) quando os filtros são alterados.

### 5.5. `history_provider.dart`

*   **Propósito:** Carrega e gerencia o histórico de estudos do usuário.
*   **Dependências:** `ReviewProvider`, `FilterProvider`, `AuthProvider`.
*   **Funcionalidades:**
    *   Busca registros de estudo do banco de dados.
    *   Aplica filtros definidos pelo `FilterProvider`.
    *   Carrega dados relacionados a revisões através do `ReviewProvider`.
    *   Fornece a lista de `StudyRecord`s para exibição.
    *   Possui métodos para adicionar novos `StudyRecord`s.

### 5.6. `navigation_provider.dart`

*   **Propósito:** Gerencia o índice da tela selecionada na `BottomNavigationBar` ou no `Drawer`.
*   **Dependências:** Nenhuma.
*   **Funcionalidades:**
    *   Mantém o `selectedIndex` atual.
    *   Método `setIndex(int index)` para atualizar o índice.

### 5.7. `planning_provider.dart`

*   **Propósito:** Gerencia o planejamento de estudos, incluindo ciclos de estudo, sessões recomendadas e progresso.
*   **Dependências:** `MentoriaProvider`, `AuthProvider`, `HistoryProvider`.
*   **Funcionalidades:**
    *   Carrega e salva ciclos de estudo.
    *   Calcula sessões de estudo recomendadas com base no histórico, matérias e revisões (`getRecommendedSession`).
    *   Atualiza o progresso do estudo após a conclusão de uma sessão.
    *   Resetta o ciclo de estudo atual.
    *   Provavelmente interage com `ActivePlanProvider` para associar planejamentos a planos específicos.

### 5.8. `plans_provider.dart`

*   **Propósito:** Carrega e gerencia todos os planos de estudo de um usuário.
*   **Dependências:** `AuthProvider`.
*   **Funcionalidades:**
    *   Busca planos de estudo do usuário (provavelmente do banco de dados).
    *   Mantém uma lista de `Plan`s.
    *   Pode ter métodos para adicionar, remover ou atualizar planos.

### 5.9. `reminders_provider.dart`

*   **Propósito:** Gerencia lembretes para estudos ou revisões.
*   **Dependências:** Nenhuma explícita no construtor, mas pode interagir com `HistoryProvider` ou `ReviewProvider`.
*   **Funcionalidades:**
    *   Lida com a criação, exclusão e listagem de lembretes.

### 5.10. `review_provider.dart`

*   **Propósito:** Gerencia o agendamento e o acompanhamento de revisões de conteúdo.
*   **Dependências:** `AuthProvider`.
*   **Funcionalidades:**
    *   Calcula as próximas datas de revisão com base em algoritmos (ex: Spaced Repetition).
    *   Carrega e salva os registros de revisão.
    *   Fornece dados para a tela de Revisões.

### 5.11. `simulados_provider.dart`

*   **Propósito:** Gerencia o estado relacionado aos simulados (criação, execução, resultados).
*   **Dependências:** Nenhuma explícita no construtor.
*   **Funcionalidades:**
    *   Armazena e gerencia os dados dos simulados.
    *   Pode lidar com a lógica de início e fim de um simulado.

### 5.12. `stopwatch_provider.dart`

*   **Propósito:** Gerencia o estado e a lógica do cronômetro flutuante.
*   **Dependências:** Nenhuma explícita no construtor, mas `main.dart` o inicializa com um `planId`.
*   **Funcionalidades:**
    *   Controle do cronômetro (iniciar, parar, resetar).
    *   Formatação do tempo decorrido (`result`).
    *   Armazena o contexto do cronômetro (ex: `planId`, `subjectId`, `topic`).
    *   Gerencia se o cronômetro está ativo.

### 5.13. `subject_provider.dart`

*   **Propósito:** Provavelmente para gerenciar detalhes de uma matéria específica ou buscar dados relacionados a ela.
*   **Dependências:** `AuthProvider`.
*   **Funcionalidades:**
    *   Pode buscar dados detalhados de uma matéria.
    *   Pode ser usado para editar informações de uma matéria.

---

## 6. Serviços

O diretório `services/` contém a lógica de infraestrutura e utilidades do aplicativo.

### 6.1. `database_service.dart`

*   **Propósito:** Gerencia todas as interações com o banco de dados SQLite do aplicativo.
*   **Dependências:** `sqflite_common_ffi` (para desktop), `uuid`.
*   **Funcionalidades:**
    *   Inicialização e configuração do banco de dados.
    *   Criação de tabelas (se não existirem).
    *   Operações CRUD (Create, Read, Update, Delete) para todas as entidades do aplicativo (Planos, Matérias, Histórico, Revisões, etc.).
    *   Métodos para exportar e importar dados de backup.
    *   Lógica para forçar a exclusão do banco de dados (útil para desenvolvimento/teste).

### 6.2. `mdns_advertiser.dart`

*   **Propósito:** Anuncia a presença do dispositivo na rede local usando Multicast DNS (mDNS), permitindo que outros dispositivos na mesma rede descubram e se conectem a este dispositivo para sincronização.
*   **Dependências:** Pacote `mdns_plugin` (assumido).
*   **Funcionalidades:**
    *   Inicia um serviço mDNS com um nome de instância, tipo de serviço e porta específicos.
    *   Responsável por tornar o dispositivo "visível" na rede para o `SyncService`.

### 6.3. `mdns_discovery_service.dart`

*   **Propósito:** Descobre outros dispositivos na rede local que estão anunciando serviços mDNS compatíveis (usado para sincronização).
*   **Dependências:** Pacote `mdns_plugin` (assumido).
*   **Funcionalidades:**
    *   Escaneia a rede em busca de serviços anunciados.
    *   Retorna uma lista de dispositivos descobertos que podem ser usados para sincronização.

### 6.4. `scraping_service.dart`

*   **Propósito:** Responsável por extrair informações de fontes externas, possivelmente para popular dados de matérias ou editais.
*   **Dependências:** Pacote `http` (para requisições web).
*   **Funcionalidades:**
    *   Implementa a lógica para fazer requisições HTTP a URLs específicas.
    *   Processa o conteúdo HTML/JSON retornado para extrair dados relevantes.

### 6.5. `sync_service.dart`

*   **Propósito:** Gerencia a comunicação de sincronização de dados entre dispositivos na rede local.
*   **Dependências:** `http` (para requisições HTTP), `DatabaseService`, `AuthProvider`, `mdns_discovery_service` (implícito para encontrar dispositivos).
*   **Funcionalidades:**
    *   Inicia um servidor HTTP local para receber dados de outros dispositivos.
    *   Exporta os dados do dispositivo local para serem enviados a outros.
    *   Importa dados recebidos de outros dispositivos, mesclando-os com os dados locais.
    *   Gerencia o pareamento de dispositivos.
    *   Lida com o processo de sincronização em si, incluindo autenticação (tokens).

---

## 7. Telas (Screens)

O diretório `screens/` contém os widgets que representam as telas completas da aplicação.

*   **`backup_screen.dart`**: Tela para gerenciar backups do aplicativo, permitindo ao usuário exportar, importar ou restaurar dados.
*   **`cycle_creation_screen.dart`**: Tela complexa para a criação e edição detalhada de ciclos de estudo, onde o usuário define matérias, tópicos, pesos e distribuição de tempo.
*   **`edital_screen.dart`**: Tela para visualizar e gerenciar informações relacionadas a editais (especificações de concursos, vestibulares, etc.), possivelmente com funcionalidades de parsing ou organização de conteúdo.
*   **`history_screen.dart`**: Exibe o histórico detalhado de todas as sessões de estudo registradas, com opções de filtragem e visualização.
*   **`home_screen.dart`**: A tela principal ou "dashboard" do aplicativo, que provavelmente oferece um resumo do progresso, planos ativos e acessos rápidos às principais funcionalidades. (Nota: O `main.dart` a refere como `DashboardScreen` em alguns contextos de navegação).
*   **`login_screen.dart`**: Tela de autenticação onde o usuário pode fazer login em sua conta.
*   **`mentoria_screen.dart`**: Tela dedicada à funcionalidade de mentoria algorítmica, oferecendo insights e sugestões personalizadas de estudo.
*   **`plan_detail_screen.dart`**: Exibe os detalhes de um plano de estudo específico, incluindo matérias associadas, progresso geral e outras configurações do plano.
*   **`planning_screen.dart`**: A tela principal para visualização e gerenciamento do planejamento de estudos, onde os ciclos de estudo são apresentados e podem ser ajustados.
*   **`plans_screen.dart`**: Lista todos os planos de estudo que o usuário criou ou aos quais está associado, permitindo a seleção de um plano ativo.
*   **`register_screen.dart`**: Tela de registro de novos usuários para criar uma conta no aplicativo.
*   **`revisions_screen.dart`**: Exibe e gerencia as tarefas de revisão agendadas, com base nos algoritmos de repetição espaçada.
*   **`simulados_screen.dart`**: A tela principal para gerenciar e iniciar simulados, permitindo ao usuário testar seus conhecimentos.
*   **`splash_screen.dart`**: Uma tela de carregamento ou introdução exibida durante a inicialização do aplicativo, enquanto recursos são carregados ou o auto-login é processado.
*   **`stats_screen.dart`**: Exibe estatísticas detalhadas e gráficos sobre o desempenho do usuário, progresso ao longo do tempo e áreas de foco.
*   **`subject_detail_screen.dart`**: Tela para visualizar e gerenciar os detalhes de uma matéria específica, incluindo tópicos, anotações, etc.
*   **`subjects_screen.dart`**: Uma lista de todas as matérias/disciplinas gerenciadas pelo usuário, com opções para adicionar, editar ou remover.
*   **`support_screen.dart`**: Tela que oferece informações de suporte ao usuário, FAQs ou formas de contato para assistência.
*   **`sync_screen.dart`**: Tela específica para gerenciar a sincronização de dados entre dispositivos, exibindo dispositivos pareados e status de sincronização.
*   **`simulados/add_edit_simulado_screen.dart`**: Componente ou tela auxiliar para a interface de adição ou edição de um simulado específico.

---

## 8. Widgets Reutilizáveis (Widgets)

O diretório `widgets/` contém componentes de UI reutilizáveis em diversas partes da aplicação.

*   **`add_subject_modal.dart`**: Modal para adicionar uma nova matéria.
*   **`catalog_import_loading_screen.dart`**: Tela de carregamento para importação de catálogo.
*   **`confirmation_modal.dart`**: Modal genérico para pedir confirmação ao usuário.
*   **`create_plan_modal.dart`**: Modal para criar um novo plano de estudo.
*   **`custom_plan_selector.dart`**: Widget para selecionar um plano personalizado.
*   **`daily_study_section.dart`**: Seção que exibe o estudo diário.
*   **`donut_chart.dart`**: Widget de gráfico em formato de rosca.
*   **`filter_modal.dart`**: Modal para aplicar filtros.
*   **`floating_stopwatch_button.dart`**: Botão flutuante para iniciar/parar o cronômetro.
*   **`import_guide_modal.dart`**: Modal com instruções de importação.
*   **`import_subject_modal.dart`**: Modal para importar matérias.
*   **`last_activities_section.dart`**: Seção que mostra as últimas atividades.
*   **`multi_select_dropdown.dart`**: Dropdown com seleção múltipla.
*   **`number_picker_wheel.dart`**: Widget de seleção de número em formato de roda.
*   **`performance_table.dart`**: Tabela para exibir desempenho.
*   **`plan_selector.dart`**: Widget para selecionar um plano.
*   **`planning_section.dart`**: Seção dentro da tela de planejamento.
*   **`pulsing_glowing_icon.dart`**: Ícone com efeito de pulsação/brilho.
*   **`reminders_section.dart`**: Seção para exibir lembretes.
*   **`revisions_section.dart`**: Seção para exibir tarefas de revisão.
*   **`stopwatch_modal.dart`**: Modal que contém a interface do cronômetro.
*   **`study_consistency_grid.dart`**: Grid para visualizar consistência de estudo.
*   **`study_guide_loading_screen.dart`**: Tela de carregamento para guias de estudo.
*   **`study_register_modal.dart`**: Modal para registrar uma sessão de estudo.
*   **`study_session_list.dart`**: Lista de sessões de estudo.
*   **`topic_performance_table.dart`**: Tabela para desempenho por tópico.
*   **`topic_weights_modal.dart`**: Modal para configurar pesos de tópicos.
*   **`weekly_bar_chart.dart`**: Widget de gráfico de barras semanal.
*   **`charts/`**: Subdiretório para widgets de gráficos.
*   **`simulados/`**: Subdiretório para widgets relacionados a simulados.

---

## 9. Testes

O projeto utiliza o framework de testes padrão do Flutter.

### 9.1. Tipos de Testes
*   **Testes Unitários:** Testam unidades lógicas isoladas (ex: `test/study_repository_test.dart`).
*   **Testes de Widget:** Testam a UI e interações de widgets individuais.
*   **Testes de Integração:** Testam fluxos completos da aplicação (podem ser adicionados no diretório `integration_test/`).

### 9.2. Executando os Testes
Para rodar todos os testes:
```bash
flutter test
```
Para rodar com cobertura:
```bash
flutter test --coverage
```

---

## 10. CI/CD (GitHub Actions)

O projeto possui um workflow de Integração Contínua configurado em `.github/workflows/flutter_ci.yml`.

### 10.1. Passos do Pipeline
1.  **Checkout:** Clona o repositório.
2.  **Setup Flutter:** Instala a versão específica do Flutter (atualmente 3.24.0).
3.  **Install Dependencies:** Executa `flutter pub get`.
4.  **Verify Formatting:** Garante que o código segue o padrão `dart format`.
5.  **Analyze Project:** Executa `flutter analyze` com flags fatais para infos e warnings.
6.  **Run Tests:** Executa a suíte de testes e gera relatório de cobertura.
7.  **Build APK:** Gera um APK de debug como artefato para verificação rápida.

---

## 11. Padrões de Código e Linting

O projeto segue regras rigorosas de análise estática para manter a qualidade e consistência.

*   **Configuração:** Localizada em `analysis_options.yaml`.
*   **Base:** Utiliza o pacote `very_good_analysis`.
*   **Regras Customizadas:** Inclui regras para evitar chamadas dinâmicas, garantir fechamento de sinks, ordenar diretivas e usar parâmetros `super`.
*   **Execução Manual:**
    ```bash
    flutter analyze
    ```

---

## 12. Tematização e UI

A identidade visual é centralizada no `ThemeData` dentro do `lib/main.dart`.

*   **Cores Principais:** Teal (`Colors.teal`), tons de cinza escuro para modo dark e superfícies.
*   **Fontes:** Utiliza as fontes padrão do Material Design 3.
*   **Responsividade:** O app é ajustado para funcionar em Mobile, Web e Desktop (Linux), com ajustes específicos de layout para telas maiores.

---

## 13. Scripts de Utilidade

Existem vários scripts shell na raiz para facilitar o setup do ambiente:

*   **`install_linux_dev_tools.sh`**: Instala dependências de sistema para desenvolvimento no Linux.
*   **`setup_java_home.sh`**: Configura o ambiente Java para builds Android.
*   **`install_flutter_recommended.sh`**: Script para instalação do Flutter em diretório específico.
*   **`setup_android_toolchain.sh`**: Auxilia na configuração do SDK Android.
