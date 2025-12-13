import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert'; // NEW IMPORT for json.encode, json.decode, utf8.decode
import 'dart:async'; // NEW IMPORT for TimeoutException
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http; // NEW IMPORT
import 'package:ouroboros_mobile/services/mdns_advertiser.dart'; // NEW IMPORT
import 'package:ouroboros_mobile/services/mdns_discovery_service.dart'; // NEW IMPORT
import 'package:ouroboros_mobile/services/sync_service.dart'; // NEW IMPORT
import 'package:ouroboros_mobile/models/backup_model.dart'; // NEW IMPORT


import 'package:ouroboros_mobile/widgets/create_plan_modal.dart';
import 'package:ouroboros_mobile/providers/subject_provider.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:ouroboros_mobile/widgets/filter_modal.dart';
import 'package:ouroboros_mobile/widgets/plan_selector.dart';
import 'package:ouroboros_mobile/widgets/floating_stopwatch_button.dart';
import 'package:ouroboros_mobile/widgets/pulsing_glowing_icon.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';

// Telas da BottomNavigationBar
import 'package:ouroboros_mobile/screens/plans_screen.dart';
import 'package:ouroboros_mobile/screens/planning_screen.dart';
import 'package:ouroboros_mobile/screens/revisions_screen.dart';
import 'package:ouroboros_mobile/screens/stats_screen.dart';
import 'package:ouroboros_mobile/screens/history_screen.dart';

// Telas do Drawer
import 'package:ouroboros_mobile/screens/home_screen.dart';
import 'package:ouroboros_mobile/screens/subjects_screen.dart';
import 'package:ouroboros_mobile/screens/edital_screen.dart';
import 'package:ouroboros_mobile/screens/simulados_screen.dart';
import 'package:ouroboros_mobile/screens/mentoria_screen.dart';
import 'package:ouroboros_mobile/screens/support_screen.dart';
import 'package:ouroboros_mobile/screens/backup_screen.dart';
import 'package:ouroboros_mobile/screens/simulados/add_edit_simulado_screen.dart';

import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';
import 'package:ouroboros_mobile/providers/reminders_provider.dart';
import 'package:ouroboros_mobile/providers/simulados_provider.dart';
import 'package:ouroboros_mobile/providers/navigation_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/screens/login_screen.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/screens/splash_screen.dart'; // Import the new splash screen
import 'package:ouroboros_mobile/services/database_service.dart'; // NEW IMPORT

final restartNotifier = ValueNotifier<int>(0);
final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>(); // NEW

void main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  // TODO: REMOVER ESTA LINHA EM PRODUÇÃO. APAGA O BANCO DE DADOS NA INICIALIZAÇÃO.
  await DatabaseService.instance.forceDeleteDatabase(); 
  await initializeDateFormatting('pt_BR', null); // Initialize date formatting for pt_BR

  // Adicionado para inicializar a plataforma do webview
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const RootWidget());
}

class RootWidget extends StatelessWidget {
  const RootWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: restartNotifier,
      builder: (context, value, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => AuthProvider()),
            ChangeNotifierProvider(create: (context) => NavigationProvider()),
            ChangeNotifierProvider(create: (context) => StopwatchProvider()),
            ChangeNotifierProxyProvider<AuthProvider, PlansProvider>(
              create: (context) => PlansProvider(authProvider: Provider.of<AuthProvider>(context, listen: false)),
              update: (context, auth, previous) => PlansProvider(authProvider: auth),
            ),
            ChangeNotifierProxyProvider2<AuthProvider, PlansProvider, AllSubjectsProvider>(
              create: (context) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final plans = Provider.of<PlansProvider>(context, listen: false);
                return AllSubjectsProvider(authProvider: auth, plansProvider: plans)..fetchData();
              },
              update: (context, auth, plans, previous) {
                if (previous == null) {
                  final newProvider = AllSubjectsProvider(authProvider: auth, plansProvider: plans);
                  newProvider.fetchData();
                  return newProvider;
                }
                
                if (plans.isLoading) {
                  return previous;
                }
                
                final hasAuthProviderChanged = previous.authProvider != auth;
                final hasPlansProviderChanged = previous.plansProvider != plans;
                
                if (hasAuthProviderChanged || hasPlansProviderChanged) {
                  previous.authProvider = auth;
                  previous.plansProvider = plans;
                  previous.fetchData();
                }
                
                return previous;
              },
            ),
            ChangeNotifierProxyProvider<AuthProvider, ActivePlanProvider>(
              create: (context) => ActivePlanProvider(authProvider: Provider.of<AuthProvider>(context, listen: false)),
              update: (context, auth, previous) => ActivePlanProvider(authProvider: auth),
            ),
            ChangeNotifierProxyProvider<AuthProvider, ReviewProvider>(
              create: (context) => ReviewProvider(authProvider: Provider.of<AuthProvider>(context, listen: false)),
              update: (context, auth, previous) => ReviewProvider(authProvider: auth),
            ),
            ChangeNotifierProvider(create: (context) => FilterProvider()),
            ChangeNotifierProxyProvider3<AuthProvider, ReviewProvider, FilterProvider, HistoryProvider>(
              create: (context) => HistoryProvider(
                Provider.of<ReviewProvider>(context, listen: false),
                Provider.of<FilterProvider>(context, listen: false),
                Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, reviewProvider, filterProvider, previousHistory) {
                // Sempre retorna uma nova instância ou atualiza a existente com as novas dependências
                return HistoryProvider(reviewProvider, filterProvider, auth);
              },
            ),
            ChangeNotifierProxyProvider<AuthProvider, SubjectProvider>(
              create: (context) => SubjectProvider(authProvider: Provider.of<AuthProvider>(context, listen: false)),
              update: (context, auth, previous) => SubjectProvider(authProvider: auth),
            ),
            ChangeNotifierProvider(create: (_) => MentoriaProvider()),
            ChangeNotifierProvider(create: (_) => RemindersProvider()),
            ChangeNotifierProvider(create: (_) => SimuladosProvider()), // Adicionado SimuladosProvider aqui
            ChangeNotifierProxyProvider3<AuthProvider, ActivePlanProvider, HistoryProvider, PlanningProvider>(
              create: (context) => PlanningProvider(
                mentoriaProvider: Provider.of<MentoriaProvider>(context, listen: false),
                authProvider: Provider.of<AuthProvider>(context, listen: false),
                historyProvider: Provider.of<HistoryProvider>(context, listen: false), // NEW
              ),
              update: (_, auth, activePlan, history, previous) => previous!..updateForPlan(activePlan.activePlanId), // Modified update signature
            ),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _tryAutoLoginFuture;
  // Removed: late StreamSubscription _authSubscription; // NEW

  // NEW: Sync Service instances
  static const int _syncPort = 5000;
  late MdnsAdvertiser _advertiser; // Changed to late and not final for initialization in initState
  // MDNSDiscoveryService _discover is not global, only used by SyncScreen
  final SyncService _sync = SyncService();
  final Uuid _uuid = Uuid();
  String _myDeviceId = ''; // To store device ID for sync


  @override
  void initState() {
    super.initState();
    _myDeviceId = _uuid.v4(); // Generate device ID on init before advertiser is created

    // Initialize _advertiser here after _myDeviceId is generated
    _advertiser = MdnsAdvertiser(
      instanceName: 'Ouroboros-${_myDeviceId.substring(0, 8)}', // Use first 8 chars for brevity
      serviceType: '_ouro._tcp.local',
      port: _syncPort,
    );

    _tryAutoLoginFuture = Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();

    // Listen to AuthProvider changes to start/stop sync services
    Provider.of<AuthProvider>(context, listen: false).addListener(_authListener); // Use the new method

    // Check initial login state
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.currentUser?.name != null) {
      _startSyncServices(authProvider.currentUser!.name!);
    }
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false).removeListener(_authListener); // Remove the listener
    _stopSyncServices(); // Ensure services are stopped on app dispose
    super.dispose();
  }

  void _authListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.currentUser?.name != null) {
      _startSyncServices(authProvider.currentUser!.name!);
    } else {
      _stopSyncServices();
    }
  }

  Future<void> _startSyncServices(String userId) async {
    print('[Global Sync] Starting sync services for user: $userId');
    // Check if server is already running to prevent "Port already in use" errors
    if (_sync.server == null) { // Accessing public getter
      await _sync.startServer(port: _syncPort, userId: userId);
    }
    // Check if advertiser is already running
    if (_advertiser.socket == null) { // Accessing public getter
      await _advertiser.start();
    }
  }

  Future<void> _stopSyncServices() async {
    print('[Global Sync] Stopping sync services.');
    _advertiser.stop(); // Removed await
    await _sync.stopServer();
  }

  // NEW: Quick Sync Function
  Future<void> _quickSync() async {
    // Show loading indicator
    snackbarKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Iniciando sincronização rápida...')),
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.name;
    if (userId == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não logado para sincronizar.')),
      );
      return;
    }

    try {
      // Server is already running globally, no need to start it here.

      // Get paired devices
      final pairedDevices = await _sync.getPairedDevices();
      if (pairedDevices.isEmpty) {
              snackbarKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Nenhum dispositivo pareado encontrado.')),
              );
                // Server is already running globally, no need to stop it here.
                return;      }
      
      // Assume the first paired device is the target
      final targetDevice = pairedDevices.entries.first.value as Map<String, dynamic>;
      final targetIp = targetDevice['ip'];
      final targetPort = targetDevice['port'];
      final targetToken = targetDevice['token'];
      final targetName = targetDevice['name'];

      if (targetIp == null || targetPort == null || targetToken == null) {
              snackbarKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Dados do dispositivo pareado incompletos.')),
              );
                // Server is already running globally, no need to stop it here.
                return;      }

      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Tentando sincronizar com $targetName ($targetIp)...')),
      );

      // 3. Initiate client-side sync logic (similar to SyncScreen's _syncNow)
      // This part will attempt to connect to the target device as a client.
      final uri = Uri.parse('http://$targetIp:$targetPort/sync');
      
      // 3.1. Export client's current data
      final clientBackupData = await DatabaseService.instance.exportBackupData(userId);
      final clientJsonData = json.encode(clientBackupData.toMap());

      // 3.2. Attempt to POST to target device, with a timeout
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $targetToken',
          'X-User-ID': userId,
        },
        body: clientJsonData,
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Tempo esgotado ao tentar conectar ao dispositivo pareado.');
      });



      switch (response.statusCode) {
        case 200:
          final mergedBackupData = BackupData.fromMap(json.decode(utf8.decode(response.bodyBytes)));
          await DatabaseService.instance.importMergedData(mergedBackupData, userId);
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Sincronização rápida concluída com sucesso!')),
          );
          // Restart app to reflect changes
          restartNotifier.value++; 
          break;
        case 403:
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Falha na sincronização: Token inválido. Recrie o pareamento.')),
          );
          break;
        case 409:
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Falha na sincronização: IDs de usuário não correspondem.')),
          );
          break;
        default:
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('Falha na sincronização: ${response.statusCode} - ${response.body}')),
          );
      }
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Erro durante a sincronização rápida: $e')),
      );
    } finally {
      // Server is already running globally, no need to stop it here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return MaterialApp(
          scaffoldMessengerKey: snackbarKey, // NEW
          title: 'Ouroboros',
          theme: ThemeData(
            primarySwatch: Colors.teal, // Changed to teal
            primaryColor: Colors.teal,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal, brightness: Brightness.light).copyWith(secondary: Colors.teal),
            scaffoldBackgroundColor: const Color(0xFFF9FAFB), // gray-50
            cardColor: Colors.white, // Set card color to white
            dialogBackgroundColor: Colors.white, // Explicitly set dialog background
            cardTheme: const CardThemeData(
              color: Colors.white, // Explicitly set card theme color
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.teal,
              selectionColor: Colors.teal.withOpacity(0.4),
              selectionHandleColor: Colors.teal,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF1F2937)), // gray-900
              bodyMedium: TextStyle(color: Color(0xFF1F2937)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF9FAFB), // gray-50
              foregroundColor: Color(0xFF1F2937), // gray-900
            ),
            inputDecorationTheme: InputDecorationTheme(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.teal, width: 2.0),
                borderRadius: BorderRadius.circular(8.0),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8.0),
                            ),            ),
                                      visualDensity: VisualDensity.adaptivePlatformDensity,
                                      dividerColor: Colors.grey.shade300, // Cor das linhas da tabela no modo claro
                                    ),          darkTheme: ThemeData(
            primarySwatch: Colors.teal, // Changed to teal
            primaryColor: Colors.teal,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal, brightness: Brightness.dark).copyWith(secondary: Colors.teal),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF101828), // Custom dark background color
            cardColor: const Color(0xFF1D2938), // Custom dark gray for cards in dark mode
            dialogBackgroundColor: const Color(0xFF1D2938), // Explicitly set dialog background for dark mode
            cardTheme: CardThemeData(
              color: const Color(0xFF1D2938), // Explicitly set card theme color
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.teal,
              selectionColor: Colors.teal.withOpacity(0.4),
              selectionHandleColor: Colors.teal,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFFF9FAFB)), // gray-50
              bodyMedium: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF101828), // Custom dark background color
              foregroundColor: Color(0xFFF9FAFB), // gray-50
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: ThemeMode.system, // Pode ser alterado para ThemeMode.light ou ThemeMode.dark
          home: authProvider.isLoggedIn
              ? HomePage(onQuickSync: _quickSync)
              : FutureBuilder(
                  future: _tryAutoLoginFuture,
                  builder: (ctx, authResultSnapshot) =>
                      authResultSnapshot.connectionState ==
                              ConnectionState.waiting
                          ? const SplashScreen()
                          : const LoginScreen(),
                ),
        );
      },
    );
  }
}

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

// ... (other imports)

class HomePage extends StatefulWidget {
  final Future<void> Function() onQuickSync; // NEW

  const HomePage({super.key, required this.onQuickSync}); // MODIFIED

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin { // Changed SingleTickerProviderStateMixin to TickerProviderStateMixin
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _syncRotationController; // NEW
  late Animation<double> _syncRotationAnimation;   // NEW

  void _handleGetRecommendation(BuildContext context) async {
    // Show loading indicator immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    // Get providers
    final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    // Ensure data is loaded. Assuming fetchData methods are awaitable.
    await allSubjectsProvider.fetchData();
    await historyProvider.fetchHistory();
    await planningProvider.loadData(); // This provider has loadData instead of fetchData

    // Dismiss loading indicator
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (planningProvider.studyCycle == null || planningProvider.studyCycle!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum ciclo de estudos ativo para sugerir.')),
        );
      }
      return;
    }

    final recommendation = planningProvider.getRecommendedSession(
      studyRecords: historyProvider.records,
      subjects: allSubjectsProvider.subjects,
      reviewRecords: Provider.of<ReviewProvider>(context, listen: false).allReviewRecords,
    );
    final recommendedTopic = recommendation['recommendedTopic'];
    final justification = recommendation['justification'];
    final nextSession = recommendation['nextSession'] as StudySession?;

    if (nextSession == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(justification ?? "Erro desconhecido na sugestão.")),
        );
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final initialRecord = StudyRecord(
      id: Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: activePlanProvider.activePlan?.id ?? '',
      date: DateTime.now().toIso8601String(),
      subject_id: nextSession.subjectId,
      topic_texts: [recommendedTopic?.topic_text ?? nextSession.subject], // Usar lista de textos
      topic_ids: [recommendedTopic?.id?.toString() ?? ''], // Usar lista de IDs, convertendo para String
      study_time: nextSession.duration * 60 * 1000,
      category: 'teoria',
      questions: {},
      review_periods: [],
      teoria_finalizada: false,
      count_in_planning: true,
      pages: [],
      videos: [],
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );

        if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => StudyRegisterModal(
          planId: initialRecord.plan_id,
          initialRecord: initialRecord, // Passa o registro inicial preenchido
          onSave: (newRecord) {
            historyProvider.addStudyRecord(newRecord);
            planningProvider.updateProgress(newRecord); // Adicionado
          },
        ),
      );
    }
  }

  bool _isDrawerOpen = false;
  bool _planningScreenEditMode = false;

  late List<Widget> _allScreens;
  late List<String> _allAppBarTitles;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _syncRotationController = AnimationController( // NEW
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _syncRotationAnimation = Tween<double>(begin: 0, end: 1).animate(_syncRotationController); // NEW

    _allScreens = <Widget>[
      // BottomNavigationBar items
      PlansScreen(),
      PlanningScreen(isEditMode: _planningScreenEditMode, onToggleEditMode: _togglePlanningScreenEditMode, onResetCycle: () => Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle()),
      RevisionsScreen(),
      StatsScreen(),
      HistoryScreen(),
      // Drawer items
      DashboardScreen(),
      SubjectsScreen(),
      EditalScreen(),
      SimuladosScreen(),
      MentoriaScreen(),
      SupportScreen(),
      BackupScreen(),
    ];

    _allAppBarTitles = <String>[
      // BottomNavigationBar titles
      'Planos',
      'Planejamento',
      'Revisões',
      'Estatísticas',
      'Histórico',
      // Drawer titles
      'Home',
      'Matérias',
      'Edital',
      'Simulados',
      'Mentoria Algorítmica',
      'Apoie o Projeto',
      'Backup',
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    _syncRotationController.dispose(); // NEW
    super.dispose();
  }

  void _startSyncAnimation() { // NEW method
    _syncRotationController.forward(from: 0.0);
  }

  void _togglePlanningScreenEditMode() {
    setState(() {
      _planningScreenEditMode = !_planningScreenEditMode;
      // Recria a lista de telas para que PlanningScreen seja recriada com o novo isEditMode
      _allScreens[1] = PlanningScreen(isEditMode: _planningScreenEditMode, onToggleEditMode: _togglePlanningScreenEditMode, onResetCycle: () => Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle());
    });
  }

  Future<void> _showStudyRegisterModal(BuildContext context) async {
    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final planningProvider = Provider.of<PlanningProvider>(context, listen: false);

    final planId = activePlanProvider.activePlan?.id;

    if (planId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum plano de estudo ativo selecionado.')),
      );
      return;
    }

    final initialRecord = StudyRecord(
      id: Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: planId,
      date: DateTime.now().toIso8601String(),
      subject_id: '', // Will be selected in the modal
      topic_texts: [], // Vazio, será selecionado no modal
      topic_ids: [],   // Vazio, será selecionado no modal
      study_time: 0,
      category: 'teoria',
      questions: {},
      review_periods: [],
      teoria_finalizada: false,
      count_in_planning: true,
      pages: [],
      videos: [],
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (modalCtx) => StudyRegisterModal(
          planId: initialRecord.plan_id,
          initialRecord: initialRecord,
          onSave: (newRecord) {
            historyProvider.addStudyRecord(newRecord);
            planningProvider.updateProgress(newRecord);
          },
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    context.read<NavigationProvider>().setIndex(index);
  }

  void _onDrawerItemTapped(int index) {
    context.read<NavigationProvider>().setIndex(index);
    Navigator.pop(context); // Fecha o Drawer
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final selectedIndex = navigationProvider.selectedIndex;

    return Consumer<PlanningProvider>(
      builder: (context, planningProvider, child) {
        final bool hasActiveCycle = planningProvider.studyCycle != null && planningProvider.studyCycle!.isNotEmpty;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => ScaleTransition(
                    scale: _scaleAnimation,
                    child: IconButton(
                      iconSize: 40, // Aumenta o tamanho total do botão
                      icon: Container(
                        padding: const EdgeInsets.all(2.0), // Aumenta o preenchimento
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D2938) : Colors.teal.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.teal,
                            width: 1,
                          )
                        ),
                        child: Image.asset(Theme.of(context).brightness == Brightness.dark ? 'logo/logo-modo-escuro.png' : 'logo/logo.png', height: 40, width: 40), // Aumenta o tamanho da imagem
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
                title: _isDrawerOpen ? const Text('') : Text(_allAppBarTitles.elementAt(selectedIndex)),
                actions: <Widget>[
                  if (selectedIndex == 1 && hasActiveCycle)
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow), // Novo ícone para iniciar estudo
                        label: const Text('Iniciar Estudo Sugerido'),
                        onPressed: () => _handleGetRecommendation(context),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 1 && hasActiveCycle)
                    IconButton(
                      icon: Icon(_planningScreenEditMode ? Icons.check : Icons.edit),
                      onPressed: _togglePlanningScreenEditMode,
                      tooltip: _planningScreenEditMode ? 'Concluir Edição' : 'Editar Ciclo',
                    ),
                  if (selectedIndex == 1 && hasActiveCycle)
                    IconButton(
                      icon: const Icon(Icons.delete), // Ícone de lixeira
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ConfirmationModal(
                              title: 'Apagar Ciclo',
                              message: 'Tem certeza que deseja apagar o ciclo de estudo atual? Esta ação é irreversível e todo o progresso será perdido.',
                              confirmText: 'Apagar',
                              onConfirm: () {
                                Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle();
                                Navigator.of(context).pop();
                              },
                              onClose: () => Navigator.of(context).pop(),
                            );
                          },
                        );
                      },
                      tooltip: 'Apagar Ciclo',
                    ),
                  if (selectedIndex == 0) // PlansScreen index
                    Flexible(
                      child: Builder(
                        builder: (context) => ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Criar Novo Plano'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return const CreatePlanModal();
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 5) // DashboardScreen index
                    Flexible(
                      child: Builder(
                        builder: (context) => ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Adicionar Estudo'),
                          onPressed: () => _showStudyRegisterModal(context),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 4) // HistoryScreen index
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end, // Alinha os botões à direita
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showStudyRegisterModal(context),
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Adicionar Estudo'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                                  final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
                                  return FilterModal(
                                    screen: FilterScreen.history,
                                    availableCategories: historyProvider.availableCategories,
                                    availableSubjects: allSubjectsProvider.subjects,
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Filtros'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8), // Add some spacing
                        ],
                      ),
                    ),
                  if (selectedIndex == 8) // SimuladosScreen index
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const AddEditSimuladoScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Novo Simulado'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 3) // StatsScreen index
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end, // Alinha os botões à direita
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showStudyRegisterModal(context),
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Adicionar Estudo'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                                  final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
                                  return FilterModal(
                                    screen: FilterScreen.stats,
                                    availableCategories: historyProvider.availableCategories,
                                    availableSubjects: allSubjectsProvider.subjects,
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Filtros'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8), // Add some spacing
                        ],
                      ),
                    ),
                  if (selectedIndex == 7) // EditalScreen index
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () { /* TODO: Implementar modal de registro de estudo */ },
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Adicionar Estudo'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 2) // RevisionsScreen index
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () => _showStudyRegisterModal(context),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Adicionar Estudo'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 9) // SupportScreen index
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () { /* TODO: Implementar compartilhamento */ },
                      tooltip: 'Compartilhar',
                    ),
                ],
              ),
              body: _allScreens.elementAt(selectedIndex),
              onDrawerChanged: (isOpened) {
                setState(() {
                  _isDrawerOpen = isOpened;
                });
              },
              drawer: Drawer(
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D2938) : Colors.teal, // Cor de fundo dos cards no modo escuro
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: <Widget>[
                            Container(
                              height: 120, // Altura menor
                              padding: const EdgeInsets.all(16.0),
                              child: Image.asset(Theme.of(context).brightness == Brightness.dark ? 'logo/logo-marca-modo-escuro.png' : 'logo/logo-marca.png'),
                            ),
                            Container(
                              decoration: selectedIndex == 5
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.home, color: selectedIndex == 5 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Home', style: TextStyle(color: selectedIndex == 5 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(5), // Index da HomeScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 6
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.book, color: selectedIndex == 6 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Matérias', style: TextStyle(color: selectedIndex == 6 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(6), // Index da SubjectsScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 7
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.description, color: selectedIndex == 7 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Edital', style: TextStyle(color: selectedIndex == 7 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(7), // Index da EditalScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 8
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.quiz, color: selectedIndex == 8 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Simulados', style: TextStyle(color: selectedIndex == 8 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(8), // Index da SimuladosScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 9
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.psychology, color: selectedIndex == 9 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Mentoria Algorítmica', style: TextStyle(color: selectedIndex == 9 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(9), // Index da MentoriaScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 10
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: PulsingGlowingIcon(icon: Icons.favorite, color: Colors.amber),
                                title: Text('Apoie o Projeto', style: TextStyle(color: selectedIndex == 10 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(10), // Index da SupportScreen em _allScreens
                              ),
                            ),
                            Container(
                              decoration: selectedIndex == 11
                                  ? BoxDecoration(
                                      color: Colors.white.withOpacity(0.2), // Highlight color
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: ListTile(
                                leading: Icon(Icons.backup, color: selectedIndex == 11 ? Colors.white : Colors.white.withOpacity(0.7)),
                                title: Text('Backup', style: TextStyle(color: selectedIndex == 11 ? Colors.white : Colors.white.withOpacity(0.7))),
                                onTap: () => _onDrawerItemTapped(11), // Index da BackupScreen em _allScreens
                              ),
                            ),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) {
                                return ListTile(
                                  leading: Icon(Icons.logout, color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.white),
                                  title: Text('Sair (${auth.currentUser!.name})', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.white)),
                                  onTap: () {
                                    auth.logout();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D2938) : Colors.teal, // Cor de fundo dos cards no modo escuro
                      child: ListTile(
                        leading: Container( // NEW: Container for circular background
                          padding: const EdgeInsets.all(8.0), // Adjust padding as needed
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.teal.withOpacity(0.2), // Light teal background for the circle
                          ),
                          child: IconButton(
                            icon: RotationTransition(
                              turns: _syncRotationAnimation,
                              child: const Icon(Icons.sync, color: Colors.teal),
                            ),
                            onPressed: () {
                              _startSyncAnimation();
                              widget.onQuickSync();
                            },
                          ),
                        ),
                        title: PlanSelector(),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor, // Move background color here for rounded corners
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)), // Rounded top corners
                  border: const Border(
                    top: BorderSide(color: Colors.teal, width: 1.0), // Teal border at the top
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, -3), // Shadow above the bar
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent, // Make BottomNavigationBar transparent
                  elevation: 0, // Remove default elevation
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: Icon(Icons.assignment),
                      label: 'Planos',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_today),
                      label: 'Planejamento',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.rate_review),
                      label: 'Revisões',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart),
                      label: 'Estatísticas',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.history),
                      label: 'Histórico',
                    ),
                  ],
                  currentIndex: selectedIndex < 5 ? selectedIndex : 0,
                  selectedItemColor: selectedIndex < 5 ? Colors.teal : Colors.grey,
                  unselectedItemColor: Colors.grey,
                  onTap: _onItemTapped,
                  type: BottomNavigationBarType.fixed,
                ),
              ),
            ),
            const FloatingStopwatchButton(),
          ],
        );
      },
    );
  }
}