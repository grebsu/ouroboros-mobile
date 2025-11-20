import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ouroboros_mobile/screens/cycle_creation_screen.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/subject_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/widgets/add_subject_modal.dart';
import 'package:ouroboros_mobile/widgets/create_plan_modal.dart'; // Import CreatePlanModal
import 'package:ouroboros_mobile/widgets/import_subject_modal.dart';
import 'package:ouroboros_mobile/widgets/stopwatch_modal.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/screens/subject_detail_screen.dart';
import 'package:collection/collection.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';

class PlanDetailScreen extends StatelessWidget {
  final Plan plan;

  const PlanDetailScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SubjectProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          )..fetchSubjects(plan.id),
        ),
        ChangeNotifierProvider(
          create: (_) => PlanningProvider(),
        ),
      ],
      child: _PlanDetailScreenContent(plan: plan),
    );
  }
}

class _PlanDetailScreenContent extends StatefulWidget {
  final Plan plan;

  const _PlanDetailScreenContent({required this.plan});

  @override
  State<_PlanDetailScreenContent> createState() => _PlanDetailScreenContentState();
}

class _PlanDetailScreenContentState extends State<_PlanDetailScreenContent> {
  InAppWebViewController? _webViewController;
  final Completer<InAppWebViewController> _controllerCompleter = Completer<InAppWebViewController>();

  final List<String> _subjectColors = [
    '#ef4444', '#f97316', '#eab308', '#84cc16', '#22c55e', '#14b8a6',
    '#06b6d4', '#3b82f6', '#8b5cf6', '#d946ef', '#f43f5e', '#64748b',
    '#f43f5e', '#be123c', '#9f1239', '#7f1d1d', '#7f1d1d', '#881337',
    '#9d174d', '#a21caf', '#86198f', '#7e22ce', '#6b21a8', '#5b21b6',
    '#4c1d95', '#312e81', '#1e3a8a', '#1e40af', '#1d4ed8', '#2563eb',
    '#3b82f6', '#0284c7', '#0369a1', '#075985', '#0891b2', '#0e7490',
    '#155e75', '#166534', '#14532d', '#16a34a', '#15803d', '#166534'
  ];

  int _countLeafTopics(List<Topic> topics) {
    int count = 0;
    for (final topic in topics) {
      if (topic.sub_topics == null || topic.sub_topics!.isEmpty) {
        count++;
      } else {
        count += _countLeafTopics(topic.sub_topics!);
      }
    }
    return count;
  }

  String _cleanSubjectName(String rawName) {
    final stopWords = [' (', ' - '];
    int? firstStopIndex;

    for (final word in stopWords) {
      final index = rawName.indexOf(word);
      if (index != -1) {
        if (firstStopIndex == null || index < firstStopIndex) {
          firstStopIndex = index;
        }
      }
    }

    if (firstStopIndex != null) {
      return rawName.substring(0, firstStopIndex).trim();
    }

    return rawName.trim();
  }

  Future<void> _waitForSelector(InAppWebViewController controller, String selector, {int timeout = 30000, String? textConditionJs}) async {
    final completer = Completer<void>();
    final stopwatch = Stopwatch()..start();

    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      final selectorExists = await controller.evaluateJavascript(source: 'document.querySelector("$selector") != null');
      bool conditionMet = selectorExists == true;

      if (conditionMet && textConditionJs != null) {
        final textConditionResult = await controller.evaluateJavascript(source: textConditionJs);
        conditionMet = textConditionResult == true;
      }

      if (conditionMet) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (stopwatch.elapsedMilliseconds > timeout) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception('Timeout esperando pelo seletor: $selector' + (textConditionJs != null ? ' com condição de texto: $textConditionJs' : '')));
        }
      }
    });

    return completer.future;
  }

  Future<String> _extractSubjectName(InAppWebViewController controller) async {
    await _waitForSelector(controller, 'div#cabecalho > span:last-of-type');
    final nameJs = "document.querySelector('div#cabecalho > span:last-of-type').textContent.trim();";
    final rawName = await controller.evaluateJavascript(source: nameJs) as String;
    return _cleanSubjectName(rawName);
  }

  Future<List<Topic>> _extractSubjectTopics(InAppWebViewController controller) async {
    await _waitForSelector(controller, 'div#materia-assuntos');
    String getTopicsJs = """
      (function() {
        const processSubassuntos = (parentElement) => {
          const topics = [];
          let currentLevelTopics = [];

          Array.from(parentElement.children).forEach(child => {
            if (child.classList.contains('subassunto')) {
              const topicNameEl = child.querySelector('.subassunto-nome');
              const questionCountEl = child.querySelector('.total-questoes span');
              
              const topicText = topicNameEl?.textContent?.trim();
              let questionCount = parseInt(questionCountEl?.textContent?.trim() || '0', 10);

              if (topicText) {
                const newTopic = {
                  topic_text: topicText,
                  question_count: questionCount,
                  sub_topics: [],
                  is_grouping_topic: false
                };
                currentLevelTopics.push(newTopic);
              }
            } else if (child.classList.contains('assunto-filho')) {
              if (currentLevelTopics.length > 0) {
                const lastTopic = currentLevelTopics[currentLevelTopics.length - 1];
                lastTopic.sub_topics = processSubassuntos(child);
                lastTopic.is_grouping_topic = lastTopic.sub_topics.length > 0;
              }
            }
          });
          return currentLevelTopics;
        };

        const mainContainer = document.querySelector('div#materia-assuntos');
        return processSubassuntos(mainContainer);
      })();
    """;
    final topicsResult = await controller.evaluateJavascript(source: getTopicsJs) as List<dynamic>;
    return topicsResult.map((topicMap) => Topic.fromMap(topicMap)).toList();
  }

  Future<Subject> _scrapeSubject(String url) async {
    final controller = await _controllerCompleter.future.timeout(const Duration(seconds: 30), onTimeout: () {
      throw Exception('WebView controller not ready within 30 seconds.');
    });
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

    final subjectName = await _extractSubjectName(controller);
    final List<Topic> rawTopics = await _extractSubjectTopics(controller);

    int maxQuestionsInSubject = 0;
    for (final topic in rawTopics) {
      if (topic.question_count != null && topic.question_count! > maxQuestionsInSubject) {
        maxQuestionsInSubject = topic.question_count!;
      }
    }

    final List<Topic> normalizedTopics = [];
    for (final topic in rawTopics) {
      int normalizedCount = 0;
      if (maxQuestionsInSubject > 0 && topic.question_count != null) {
        normalizedCount = ((topic.question_count! / maxQuestionsInSubject) * 1000).round();
      }
      normalizedTopics.add(topic.copyWith(question_count: normalizedCount));
    }

    final newSubject = Subject(
      id: const Uuid().v4(),
      plan_id: widget.plan.id,
      subject: subjectName,
      color: _subjectColors[0],
      topics: rawTopics,
      total_topics_count: rawTopics.length,
      import_source: 'INDIVIDUAL',
    );

    return newSubject;
  }

  Future<void> _handleImportSubject(String subjectUrl) async {
    try {
      final Subject newSubject = await _scrapeSubject(subjectUrl);

      final subjectProvider = Provider.of<SubjectProvider>(context, listen: false);
      final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);

      Subject? existingSubject = await allSubjectsProvider.getSubjectByNameAndPlanId(newSubject.subject, widget.plan.id);

      if (existingSubject != null) {
        final updatedSubject = newSubject.copyWith(id: existingSubject.id, color: existingSubject.color);
        await subjectProvider.updateSubject(updatedSubject);
      } else {
        await subjectProvider.addSubject(newSubject);
      }

      await allSubjectsProvider.fetchData();
      await subjectProvider.fetchSubjects(widget.plan.id);
      await Provider.of<PlansProvider>(context, listen: false).fetchPlans();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matéria "${newSubject.subject}" importada com sucesso!')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao importar a matéria: $e')), 
      );
    }
  }

  void _openAddSubjectModal(BuildContext context, {Subject? subjectToEdit}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surfaceTint: Colors.transparent,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: AddSubjectModal(
              initialSubjectData: subjectToEdit,
              onSave: (subjectName, topics, color) async {
                final provider = Provider.of<SubjectProvider>(context, listen: false);
                if (subjectToEdit != null) {
                  final updatedSubject = Subject(
                    id: subjectToEdit.id,
                    plan_id: subjectToEdit.plan_id,
                    subject: subjectName,
                    topics: topics,
                    color: color,
                  );
                  await provider.updateSubject(updatedSubject);
                } else {
                  final newSubject = Subject(
                    id: const Uuid().v4(),
                    plan_id: widget.plan.id,
                    subject: subjectName,
                    topics: topics,
                    color: color,
                  );
                  await provider.addSubject(newSubject);
                }
                if (mounted) {
                  await Provider.of<PlansProvider>(context, listen: false).fetchPlans();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Topic? _findTopicByText(List<Topic> topics, String text) {
    for (var topic in topics) {
      if (topic.topic_text == text) {
        return topic;
      }
      if (topic.sub_topics != null) {
        final found = _findTopicByText(topic.sub_topics!, text);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  void _onStartStudy(BuildContext context, StudySession session) async {
    final stopwatchProvider = Provider.of<StopwatchProvider>(context, listen: false);
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);

    final subject = allSubjectsProvider.subjects.firstWhereOrNull((s) => s.id == session.subjectId);
    final topic = subject != null ? _findTopicByText(subject.topics, session.subject) : null;

    stopwatchProvider.setContext(
      planId: widget.plan.id,
      subjectId: session.subjectId,
      topic: topic,
    );

    final result = await showDialog<Map<String, dynamic>?>( // Capturar o resultado
      context: context,
      builder: (context) => const StopwatchModal(), // Não passa onSaveAndClose
    );

    if (result != null) { // Se o usuário salvou
      final int time = result['time'];
      final String? subjectId = result['subjectId'];
      final Topic? topic = result['topic'];
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final record = StudyRecord(
        id: Uuid().v4(),
        userId: authProvider.currentUser!.name,
        plan_id: widget.plan.id,
        date: DateTime.now().toIso8601String(),
        subject_id: subjectId!,
        topic: topic?.topic_text ?? '',
        study_time: time,
        category: 'teoria',
        questions: {},
        review_periods: [],
        teoria_finalizada: false,
        count_in_planning: true,
        pages: [],
        videos: [],
      );
      Provider.of<HistoryProvider>(context, listen: false).addStudyRecord(record);
      if (record.count_in_planning) {
        Provider.of<PlanningProvider>(context, listen: false).updateProgress(record);
      }
    }
  }

  void _onRegisterStudy(BuildContext context, StudySession session) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final planningProvider = Provider.of<PlanningProvider>(context, listen: false);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final newRecord = StudyRecord(
      id: Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: widget.plan.id,
      date: DateTime.now().toIso8601String().split('T')[0],
      study_time: 0,
      subject_id: session.subjectId,
      topic: session.subject,
      category: 'teoria',
      questions: {},
      review_periods: [],
      teoria_finalizada: false,
      count_in_planning: true,
      pages: [],
      videos: [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StudyRegisterModal(
        planId: newRecord.plan_id,
        initialRecord: newRecord,
        onSave: (record) {
          historyProvider.addStudyRecord(record);
          if (record.count_in_planning) {
            planningProvider.updateProgress(record);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.name),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CreatePlanModal(initialPlan: widget.plan);
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<SubjectProvider>(
            builder: (context, provider, child) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  _buildPlanHeader(context),
                  const SizedBox(height: 24.0),
                  _buildStatsCard(context),
                  const SizedBox(height: 24.0),
                  _buildSubjectsSection(context, provider),
                ],
              );
            },
          ),
          SizedBox(
            width: 0,
            height: 0,
            child: Offstage(
              offstage: true,
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
                  builtInZoomControls: false,
                  supportZoom: false,
                useWideViewPort: true,
                initialScale: 100,
                ),
                onWebViewCreated: (controller) {
                  if (!_controllerCompleter.isCompleted) {
                    _controllerCompleter.complete(controller);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CycleCreationScreen(),
          );
        },
        label: const Text('Criar Ciclo'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: (widget.plan.iconUrl != null && widget.plan.iconUrl!.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    File(widget.plan.iconUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.assignment, size: 60, color: Colors.grey),
                  ),
                )
              : const Icon(Icons.assignment, size: 60, color: Colors.teal),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.plan.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Text('Edital: ${widget.plan.edital ?? 'N/A'}'),
              Text('Cargo: ${widget.plan.cargo ?? 'N/A'}'),
              Text('Banca: ${widget.plan.banca ?? 'N/A'}'),
              Text('Observações: ${widget.plan.observations ?? 'Nenhuma.'}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Card(
      elevation: 4.0,
      color: Colors.teal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(child: _buildStatColumn(context, '0h 0m', 'Horas Estudadas')),
            Expanded(child: _buildStatColumn(context, '0', 'Questões Resolvidas')),
            Expanded(child: _buildStatColumn(context, '0%', 'Desempenho')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String value, String label) {
    return Column(
      children: <Widget>[
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSubjectsSection(BuildContext context, SubjectProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Disciplinas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Importar'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return ImportSubjectModal(onImport: _handleImportSubject);
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nova'),
                  onPressed: () => _openAddSubjectModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        if (provider.isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.teal))
        else if (provider.subjects.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('Nenhuma disciplina adicionada.')))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.subjects.length,
            itemBuilder: (context, index) {
              return _buildSubjectCard(context, provider.subjects[index]);
            },
          ),
      ],
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    final provider = Provider.of<SubjectProvider>(context, listen: false);
    final totalTopics = _countLeafTopics(subject.topics);

    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 80,
              decoration: BoxDecoration(
                color: Color(int.parse(subject.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    subject.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Text('Tópicos: $totalTopics', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                ),
                popupMenuTheme: PopupMenuThemeData(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                ),
              ),
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAddSubjectModal(context, subjectToEdit: subject);
                  } else if (value == 'delete') {
                    provider.deleteSubject(subject.id, widget.plan.id);
                  } else if (value == 'view') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => SubjectDetailScreen(subject: subject),
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('Visualizar Tópicos'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar Disciplina'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Excluir Disciplina', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

