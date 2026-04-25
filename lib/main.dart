/*
 * Ouroboros Mobile - Estudo inteligente e autônomo
 * Copyright (C) 2025 Glebson (grebsu)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Imports ordenados: 'dart:' primeiro, depois 'package:', depois relativos (nenhum aqui)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:ouroboros_mobile/models/backup_model.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/navigation_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/reminders_provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/simulados_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/providers/subject_provider.dart';
import 'package:ouroboros_mobile/screens/backup_screen.dart';
import 'package:ouroboros_mobile/screens/edital_screen.dart';
import 'package:ouroboros_mobile/screens/history_screen.dart';
import 'package:ouroboros_mobile/screens/home_screen.dart';
import 'package:ouroboros_mobile/screens/login_screen.dart';
import 'package:ouroboros_mobile/screens/mentoria_screen.dart';
import 'package:ouroboros_mobile/screens/planning_screen.dart';
import 'package:ouroboros_mobile/screens/plans_screen.dart';
import 'package:ouroboros_mobile/screens/revisions_screen.dart';
import 'package:ouroboros_mobile/screens/simulados_screen.dart';
import 'package:ouroboros_mobile/screens/simulados/add_edit_simulado_screen.dart';
import 'package:ouroboros_mobile/screens/splash_screen.dart';
import 'package:ouroboros_mobile/screens/stats_screen.dart';
import 'package:ouroboros_mobile/screens/subjects_screen.dart';
import 'package:ouroboros_mobile/screens/support_screen.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/services/mdns_advertiser.dart';
import 'package:ouroboros_mobile/services/mdns_discovery_service.dart';
import 'package:ouroboros_mobile/services/sync_service.dart';
import 'package:ouroboros_mobile/sqlcipher_init.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';
import 'package:ouroboros_mobile/widgets/create_plan_modal.dart';
import 'package:ouroboros_mobile/widgets/filter_modal.dart';
import 'package:ouroboros_mobile/widgets/floating_stopwatch_button.dart';
import 'package:ouroboros_mobile/widgets/plan_selector.dart';
import 'package:ouroboros_mobile/widgets/pulsing_glowing_icon.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:ouroboros_mobile/sqlcipher_init.dart';

final restartNotifier = ValueNotifier<int>(0);
final GlobalKey<ScaffoldMessengerState> snackbarKey =
GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initSqlCipher();

  await initializeDateFormatting(
    'pt_BR',
    null,
  );

  // Inicializações específicas de plataforma (apenas fora da web)
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
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
              create: (context) => PlansProvider(
                authProvider: Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, previous) =>
                  PlansProvider(authProvider: auth),
            ),
            ChangeNotifierProxyProvider2<AuthProvider, PlansProvider,
                AllSubjectsProvider>(
              create: (context) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final plans = Provider.of<PlansProvider>(
                  context,
                  listen: false,
                );
                return AllSubjectsProvider(
                  authProvider: auth,
                  plansProvider: plans,
                )..fetchData();
              },
              update: (context, auth, plans, previous) {
                if (previous == null) {
                  final newProvider = AllSubjectsProvider(
                    authProvider: auth,
                    plansProvider: plans,
                  );
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
              create: (context) => ActivePlanProvider(
                authProvider: Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, previous) =>
                  ActivePlanProvider(authProvider: auth),
            ),
            ChangeNotifierProxyProvider<AuthProvider, ReviewProvider>(
              create: (context) => ReviewProvider(
                authProvider: Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, previous) =>
                  ReviewProvider(authProvider: auth),
            ),
            ChangeNotifierProvider(create: (context) => FilterProvider()),
            ChangeNotifierProxyProvider3<AuthProvider, ReviewProvider,
                FilterProvider, HistoryProvider>(
              create: (context) => HistoryProvider(
                Provider.of<ReviewProvider>(context, listen: false),
                Provider.of<FilterProvider>(context, listen: false),
                Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, reviewProvider, filterProvider,
                  previousHistory) {
                return HistoryProvider(
                  reviewProvider,
                  filterProvider,
                  auth,
                );
              },
            ),
            ChangeNotifierProxyProvider<AuthProvider, SubjectProvider>(
              create: (context) => SubjectProvider(
                authProvider: Provider.of<AuthProvider>(context, listen: false),
              ),
              update: (context, auth, previous) =>
                  SubjectProvider(authProvider: auth),
            ),
            ChangeNotifierProvider(create: (_) => MentoriaProvider()),
            ChangeNotifierProvider(create: (_) => RemindersProvider()),
            ChangeNotifierProvider(
              create: (_) => SimuladosProvider(),
            ),
            ChangeNotifierProxyProvider3<AuthProvider, ActivePlanProvider,
                HistoryProvider, PlanningProvider>(
              create: (context) => PlanningProvider(
                mentoriaProvider:
                Provider.of<MentoriaProvider>(context, listen: false),
                authProvider:
                Provider.of<AuthProvider>(context, listen: false),
                historyProvider:
                Provider.of<HistoryProvider>(context, listen: false),
              ),
              update: (_, auth, activePlan, history, previous) =>
              previous!..updateForPlan(activePlan.activePlanId),
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
  static const int _syncPort = 5000;
  late MdnsAdvertiser _advertiser;
  final SyncService _sync = SyncService();
  final Uuid _uuid = Uuid();
  String _myDeviceId = '';

  @override
  void initState() {
    super.initState();
    _myDeviceId = _uuid.v4();

    _advertiser = MdnsAdvertiser(
      instanceName: 'Ouroboros-${_myDeviceId.substring(0, 8)}',
      serviceType: '_ouro._tcp.local',
      port: _syncPort,
    );

    _tryAutoLoginFuture =
        Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();

    Provider.of<AuthProvider>(context, listen: false)
        .addListener(_authListener);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.currentUser?.username != null) {
      _startSyncServices(authProvider.currentUser!.username);
    }
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false).removeListener(_authListener);
    _stopSyncServices();
    super.dispose();
  }

  void _authListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn && authProvider.currentUser?.username != null) {
      _startSyncServices(authProvider.currentUser!.username);
    } else {
      _stopSyncServices();
    }
  }

  Future<void> _startSyncServices(String userId) async {
    debugPrint('[Global Sync] Starting sync services for user: $userId');
    if (_sync.server == null) {
      await _sync.startServer(port: _syncPort, userId: userId);
    }
    if (_advertiser.socket == null) {
      await _advertiser.start();
    }
  }

  Future<void> _stopSyncServices() async {
    debugPrint('[Global Sync] Stopping sync services.');
    _advertiser.stop();
    await _sync.stopServer();
  }

  Future<void> _quickSync() async {
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
      final pairedDevices = await _sync.getPairedDevices();
      if (pairedDevices.isEmpty) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Nenhum dispositivo pareado encontrado.')),
        );
        return;
      }

      final targetDevice = pairedDevices.entries.first.value as Map<String, dynamic>;
      final targetIp = targetDevice['ip'];
      final targetPort = targetDevice['port'];
      final targetToken = targetDevice['token'];
      final targetName = targetDevice['name'];

      if (targetIp == null || targetPort == null || targetToken == null) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Dados do dispositivo pareado incompletos.')),
        );
        return;
      }

      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Tentando sincronizar com $targetName ($targetIp)...')),
      );

      final uri = Uri.parse('http://$targetIp:$targetPort/sync');
      final clientBackupData = await DatabaseService.instance.exportBackupData(userId);
      final clientJsonData = json.encode(clientBackupData.toMap());

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $targetToken',
          'X-User-ID': userId,
        },
        body: clientJsonData,
      )
          .timeout(const Duration(seconds: 30));

      switch (response.statusCode) {
        case 200:
          final mergedBackupData = BackupData.fromMap(
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
          );
          await DatabaseService.instance.importMergedData(mergedBackupData, userId);
          final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
          final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
          await historyProvider.fetchHistory();
          await planningProvider.loadData();
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Sincronização concluída e dados atualizados!')),
          );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return MaterialApp(
          scaffoldMessengerKey: snackbarKey,
          title: 'Ouroboros',
          theme: ThemeData(
            primarySwatch: Colors.teal,
            primaryColor: Colors.teal,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.teal,
              brightness: Brightness.light,
            ).copyWith(secondary: Colors.teal),
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
            cardColor: Colors.white,
            dialogBackgroundColor: Colors.white,
            cardTheme: const CardThemeData(color: Colors.white),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.teal,
              selectionColor: Colors.teal.withOpacity(0.4),
              selectionHandleColor: Colors.teal,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF1F2937)),
              bodyMedium: TextStyle(color: Color(0xFF1F2937)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF9FAFB),
              foregroundColor: Color(0xFF1F2937),
            ),
            inputDecorationTheme: InputDecorationTheme(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8.0),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            dividerColor: Colors.grey.shade300,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            primaryColor: Colors.teal,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.teal,
              brightness: Brightness.dark,
            ).copyWith(secondary: Colors.teal),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF101828),
            cardColor: const Color(0xFF1D2938),
            dialogBackgroundColor: const Color(0xFF1D2938),
            cardTheme: const CardThemeData(color: Color(0xFF1D2938)),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.teal,
              selectionColor: Colors.teal.withOpacity(0.4),
              selectionHandleColor: Colors.teal,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFFF9FAFB)),
              bodyMedium: TextStyle(color: Color(0xFFF9FAFB)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF101828),
              foregroundColor: Color(0xFFF9FAFB),
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          themeMode: ThemeMode.system,
          home: authProvider.isLoggedIn
              ? HomePage(onQuickSync: _quickSync)
              : FutureBuilder(
            future: _tryAutoLoginFuture,
            builder: (ctx, authResultSnapshot) =>
            authResultSnapshot.connectionState == ConnectionState.waiting
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
  for (final dynamic strength in strengths) {
    final double strengthValue = strength as double;
    final double ds = 0.5 - strengthValue;
    swatch[(strengthValue * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

class HomePage extends StatefulWidget {
  final Future<void> Function() onQuickSync;

  const HomePage({super.key, required this.onQuickSync});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _syncRotationController;
  late Animation<double> _syncRotationAnimation;

  void _handleGetRecommendation(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
      const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    await allSubjectsProvider.fetchData();
    await historyProvider.fetchHistory();
    await planningProvider.loadData();

    if (context.mounted) Navigator.of(context).pop();

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
          SnackBar(content: Text((justification as String?) ?? "Erro desconhecido na sugestão.")),
        );
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final initialRecord = StudyRecord(
      id: const Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: activePlanProvider.activePlan?.id ?? '',
      date: DateTime.now().toIso8601String(),
      subject_id: nextSession.subjectId,
      topicsProgress: [
        TopicProgress(
          topicId: recommendedTopic?.id?.toString() ?? '',
          topicText: (recommendedTopic?.topic_text as String?) ?? nextSession.subject,
        ),
      ],
      study_time: nextSession.duration * 60 * 1000,
      category: 'teoria',
      review_periods: [],
      count_in_planning: true,
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => StudyRegisterModal(
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

    _syncRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _syncRotationAnimation = Tween<double>(begin: 0, end: 1).animate(_syncRotationController);

    _allScreens = <Widget>[
      PlansScreen(),
      PlanningScreen(
        isEditMode: _planningScreenEditMode,
        onToggleEditMode: _togglePlanningScreenEditMode,
        onResetCycle: () =>
            Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle(),
      ),
      RevisionsScreen(),
      StatsScreen(),
      HistoryScreen(),
      DashboardScreen(),
      SubjectsScreen(),
      EditalScreen(),
      SimuladosScreen(),
      MentoriaScreen(),
      SupportScreen(),
      BackupScreen(),
    ];

    _allAppBarTitles = <String>[
      'Planos',
      'Planejamento',
      'Revisões',
      'Estatísticas',
      'Histórico',
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
    _syncRotationController.dispose();
    super.dispose();
  }

  void _startSyncAnimation() {
    _syncRotationController.forward(from: 0.0);
  }

  void _togglePlanningScreenEditMode() {
    setState(() {
      _planningScreenEditMode = !_planningScreenEditMode;
      _allScreens[1] = PlanningScreen(
        isEditMode: _planningScreenEditMode,
        onToggleEditMode: _togglePlanningScreenEditMode,
        onResetCycle: () =>
            Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle(),
      );
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
      id: const Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: planId,
      date: DateTime.now().toIso8601String(),
      subject_id: '',
      topicsProgress: [],
      study_time: 0,
      category: 'teoria',
      review_periods: [],
      count_in_planning: true,
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final selectedIndex = navigationProvider.selectedIndex;

    return Consumer<PlanningProvider>(
      builder: (context, planningProvider, child) {
        final bool hasActiveCycle =
            planningProvider.studyCycle != null && planningProvider.studyCycle!.isNotEmpty;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                leading: Builder(
                  builder: (context) => ScaleTransition(
                    scale: _scaleAnimation,
                    child: IconButton(
                      iconSize: 40,
                      icon: Container(
                        padding: const EdgeInsets.all(2.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1D2938)
                              : Colors.teal.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.teal, width: 1),
                        ),
                        child: Image.asset(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'logo/logo-modo-escuro.png'
                              : 'logo/logo.png',
                          height: 40,
                          width: 40,
                        ),
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
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar Estudo Sugerido'),
                        onPressed: () => _handleGetRecommendation(context),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => ConfirmationModal(
                            title: 'Apagar Ciclo',
                            message:
                            'Tem certeza que deseja apagar o ciclo de estudo atual? Esta ação é irreversível e todo o progresso será perdido.',
                            confirmText: 'Apagar',
                            onConfirm: () {
                              Provider.of<PlanningProvider>(context, listen: false).resetStudyCycle();
                              Navigator.of(context).pop();
                            },
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        );
                      },
                      tooltip: 'Apagar Ciclo',
                    ),
                  if (selectedIndex == 0)
                    Flexible(
                      child: Builder(
                        builder: (context) => ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Criar Novo Plano'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) => const CreatePlanModal(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 5)
                    Flexible(
                      child: Builder(
                        builder: (context) => ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Adicionar Estudo'),
                          onPressed: () => _showStudyRegisterModal(context),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == 4)
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showStudyRegisterModal(context),
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Adicionar Estudo'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final historyProvider =
                                  Provider.of<HistoryProvider>(context, listen: false);
                                  final allSubjectsProvider =
                                  Provider.of<AllSubjectsProvider>(context, listen: false);
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  if (selectedIndex == 8)
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (ctx) => const AddEditSimuladoScreen()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Novo Simulado'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  if (selectedIndex == 3)
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showStudyRegisterModal(context),
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Adicionar Estudo'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final historyProvider =
                                  Provider.of<HistoryProvider>(context, listen: false);
                                  final allSubjectsProvider =
                                  Provider.of<AllSubjectsProvider>(context, listen: false);
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  if (selectedIndex == 7)
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Adicionar Estudo'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  if (selectedIndex == 2)
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () => _showStudyRegisterModal(context),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Adicionar Estudo'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  if (selectedIndex == 9)
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {},
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1D2938)
                            : Colors.teal,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: <Widget>[
                            Container(
                              height: 120,
                              padding: const EdgeInsets.all(16.0),
                              child: Image.asset(
                                Theme.of(context).brightness == Brightness.dark
                                    ? 'logo/logo-marca-modo-escuro.png'
                                    : 'logo/logo-marca.png',
                              ),
                            ),
                            _buildDrawerItem(
                              context,
                              index: 5,
                              icon: Icons.home,
                              label: 'Home',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 6,
                              icon: Icons.book,
                              label: 'Matérias',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 7,
                              icon: Icons.description,
                              label: 'Edital',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 8,
                              icon: Icons.quiz,
                              label: 'Simulados',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 9,
                              icon: Icons.psychology,
                              label: 'Mentoria Algorítmica',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 10,
                              icon: Icons.favorite,
                              label: 'Apoie o Projeto',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                              isPulsing: true,
                            ),
                            _buildDrawerItem(
                              context,
                              index: 11,
                              icon: Icons.backup,
                              label: 'Backup',
                              selectedIndex: selectedIndex,
                              onTap: _onDrawerItemTapped,
                            ),
                            Consumer<AuthProvider>(
                              builder: (context, auth, child) => ListTile(
                                leading: const Icon(Icons.logout, color: Colors.white),
                                title: Text(
                                  'Sair (${auth.currentUser!.username})',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () => auth.logout(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1D2938)
                          : Colors.teal,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.teal.withOpacity(0.2),
                          ),
                          child: IconButton(
                            icon: RotationTransition(
                              turns: _syncRotationAnimation,
                              child: const Icon(Icons.sync, color: Colors.white),
                            ),
                            onPressed: () {
                              _startSyncAnimation();
                              widget.onQuickSync();
                            },
                          ),
                        ),
                        title: const PlanSelector(),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
                  border: const Border(top: BorderSide(color: Colors.teal, width: 1.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Planos'),
                    BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Planejamento'),
                    BottomNavigationBarItem(icon: Icon(Icons.rate_review), label: 'Revisões'),
                    BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estatísticas'),
                    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
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

  Widget _buildDrawerItem(
      BuildContext context, {
        required int index,
        required IconData icon,
        required String label,
        required int selectedIndex,
        required void Function(int) onTap,
        bool isPulsing = false,
      }) {
    final isSelected = selectedIndex == index;
    return Container(
      decoration: isSelected
          ? BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      )
          : null,
      child: ListTile(
        leading: isPulsing
            ? PulsingGlowingIcon(icon: icon, color: Colors.amber)
            : Icon(icon, color: isSelected ? Colors.white : Colors.white.withOpacity(0.7)),
        title: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.7)),
        ),
        onTap: () => onTap(index),
      ),
    );
  }
}