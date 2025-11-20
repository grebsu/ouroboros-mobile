import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/widgets/stopwatch_modal.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:collection/collection.dart';

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

String formatTime(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).floor();
  final hours = (totalSeconds / 3600).floor();
  final minutes = ((totalSeconds % 3600) / 60).floor();
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

const Map<StudyCategory, String> categoryDisplayMap = {
  StudyCategory.teoria: 'Teoria',
  StudyCategory.revisao: 'Revisão',
  StudyCategory.questoes: 'Questões',
  StudyCategory.leituraLei: 'Leitura de Lei',
  StudyCategory.jurisprudencia: 'Jurisprudência',
};

Map<StudyCategory, Color> categoryColorMap = {
  StudyCategory.teoria: Colors.blue.shade200,
  StudyCategory.revisao: Colors.purple.shade200,
  StudyCategory.questoes: Colors.green.shade200,
  StudyCategory.leituraLei: Colors.yellow.shade200,
  StudyCategory.jurisprudencia: Colors.indigo.shade200,
};

const Map<String, Color> subjectColorMap = {
  'Língua Portuguesa': Colors.blue,
  'Direito Administrativo': Colors.red,
  'Direito Constitucional': Colors.green,
  'Informática': Colors.purple,
};

class RevisionsScreen extends StatefulWidget {
  const RevisionsScreen({super.key});

  @override
  State<RevisionsScreen> createState() => _RevisionsScreenState();
}

enum ReviewTab {
  scheduled,
  overdue,
  ignored,
  completed,
}

const Map<ReviewTab, String> _reviewTabNames = {
  ReviewTab.scheduled: 'Programadas',
  ReviewTab.overdue: 'Atrasadas',
  ReviewTab.ignored: 'Ignoradas',
  ReviewTab.completed: 'Concluídas',
};

class _RevisionsScreenState extends State<RevisionsScreen> {
  ReviewTab _activeTab = ReviewTab.scheduled;

  @override
  void initState() {
    super.initState();
  }

  String _getDaysRemainingText(DateTime scheduledDate) {
    final today = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Normalizar today para UTC meia-noite
    final diff = scheduledDate.difference(today);
    final diffDays = diff.inDays;

    if (diffDays == 0) return 'HOJE';
    if (diffDays == 1) return 'AMANHÃ';
    if (diffDays > 1) return '${diffDays} DIAS';
    return '${diffDays.abs()} DIAS ATRASADOS';
  }

  List<ReviewRecord> _filteredReviewRecords(List<ReviewRecord> allReviewRecords) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    return allReviewRecords.where((record) {
      final scheduledDate = DateTime.parse(record.scheduled_date);

      if (_activeTab == ReviewTab.scheduled) {
        return !record.ignored && record.completed_date == null && scheduledDate.isAfter(today) || scheduledDate.isAtSameMomentAs(today);
      } else if (_activeTab == ReviewTab.overdue) {
        return !record.ignored && record.completed_date == null && scheduledDate.isBefore(today);
      } else if (_activeTab == ReviewTab.ignored) {
        return record.ignored;
      } else if (_activeTab == ReviewTab.completed) {
        return record.completed_date != null;
      }
      return true;
    }).toList();
  }

  Map<String, List<ReviewRecord>> _groupedReviewRecords(List<ReviewRecord> allReviewRecords) {
    final Map<String, List<ReviewRecord>> groups = {};
    for (var record in _filteredReviewRecords(allReviewRecords)) {
      String dateKey;
      if (_activeTab == ReviewTab.completed && record.completed_date != null) {
        dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(record.completed_date!));
      } else {
        dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(record.scheduled_date));
      }
      if (!groups.containsKey(dateKey)) {
        groups[dateKey] = [];
      }
      groups[dateKey]!.add(record);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReviewProvider, HistoryProvider>(
      builder: (context, reviewProvider, historyProvider, child) {
        if (reviewProvider.isLoading || historyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }

        final List<ReviewRecord> allReviewRecords = reviewProvider.allReviewRecords;
        final List<StudyRecord> allStudyRecords = historyProvider.allStudyRecords;

        return Scaffold(
          body: Column(
            children: [
              _buildTabButtons(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _filteredReviewRecords(allReviewRecords).isEmpty
                          ? _buildNoRecordsMessage()
                          : Column(
                              children: _groupedReviewRecords(allReviewRecords).entries.map((entry) {
                                final dateKey = entry.key;
                                final recordsForDate = entry.value;
                                return _buildDateSection(context, dateKey, recordsForDate, allStudyRecords, reviewProvider, historyProvider);
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ReviewTab.values.map((tab) {
          return Expanded(
            child: TextButton(
              onPressed: () => setState(() => _activeTab = tab),
              style: TextButton.styleFrom(
                foregroundColor: _activeTab == tab ? Colors.white : Colors.grey[700],
                backgroundColor: _activeTab == tab ? Colors.teal : Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(_reviewTabNames[tab]!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoRecordsMessage() {
    String message;
    switch (_activeTab) {
      case ReviewTab.scheduled: message = 'Nenhuma revisão programada.'; break;
      case ReviewTab.overdue: message = 'Nenhuma revisão atrasada.'; break;
      case ReviewTab.ignored: message = 'Nenhuma revisão ignorada.'; break;
      case ReviewTab.completed: message = 'Nenhuma revisão concluída.'; break;
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
      ),
    );
  }

  Widget _buildDateSection(BuildContext context, String dateKey, List<ReviewRecord> records, List<StudyRecord> allStudyRecords, ReviewProvider reviewProvider, HistoryProvider historyProvider) {
    final dateForSection = DateTime.parse(dateKey).toUtc();
    
    String titleText;
    if (_activeTab == ReviewTab.completed) {
      // Use full date format for completed tab
      titleText = DateFormat('d \'de\' MMMM \'de\' yyyy', 'pt_BR').format(dateForSection);
    } else {
      // Use relative days text for other tabs
      titleText = _getDaysRemainingText(dateForSection);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Text(
                titleText,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.teal,
                  margin: const EdgeInsets.only(left: 16.0),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: records.map((record) => _ReviewRecordCard(
            reviewRecord: record,
            studyRecords: allStudyRecords,
            reviewProvider: reviewProvider,
            historyProvider: historyProvider,
            getDaysRemainingText: _getDaysRemainingText,
            buildDatePill: _buildDatePill,
          )).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDatePill(BuildContext context, DateTime scheduledDate) {
    final today = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Normalizar today para UTC meia-noite
    final diff = scheduledDate.difference(today);
    final diffDays = diff.inDays;
    final theme = Theme.of(context);

    String mainText;
    Color backgroundColor = Colors.teal;
    Color textColor = Colors.white;

    if (diffDays == 0) {
      mainText = 'HOJE';
    } else if (diffDays == 1) {
      mainText = 'AMANHÃ';
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scheduledDate.day.toString(),
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${DateFormat('MMM', 'pt_BR').format(scheduledDate).toUpperCase()}/${DateFormat('yy').format(scheduledDate)}',
                  style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('EEE', 'pt_BR').format(scheduledDate).toUpperCase(),
                  style: TextStyle(color: textColor, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mainText,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ReviewRecordCard extends StatelessWidget {
  final ReviewRecord reviewRecord;
  final List<StudyRecord> studyRecords;
  final ReviewProvider reviewProvider;
  final HistoryProvider historyProvider;
  final Function(DateTime) getDaysRemainingText;
  final Widget Function(BuildContext, DateTime) buildDatePill;

  const _ReviewRecordCard({
    required this.reviewRecord,
    required this.studyRecords,
    required this.reviewProvider,
    required this.historyProvider,
    required this.getDaysRemainingText,
    required this.buildDatePill,
  });

  StudyCategory _getStudyCategoryFromString(String categoryString) {
    switch (categoryString) {
      case 'teoria':
        return StudyCategory.teoria;
      case 'revisao':
        return StudyCategory.revisao;
      case 'questoes':
        return StudyCategory.questoes;
      case 'leitura_lei':
        return StudyCategory.leituraLei;
      case 'jurisprudencia':
        return StudyCategory.jurisprudencia;
      default:
        return StudyCategory.teoria;
    }
  }

  @override
  Widget build(BuildContext context) {
    final studyRecord = studyRecords.firstWhere(
      (sr) => sr.id == reviewRecord.study_record_id,
      orElse: () {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        return StudyRecord(
          id: '',
          userId: authProvider.currentUser?.name ?? '',
          plan_id: '',
          date: DateTime.now().toIso8601String(),
          subject_id: '',
          topic: 'Tópico não encontrado',
          study_time: 0,
          category: 'revisao',
          questions: {},
          review_periods: [],
          teoria_finalizada: false,
          count_in_planning: false,
          pages: [],
          videos: [],
        );
      },
    );

    // Obter a cor da matéria para uso nos cards
    final subject = historyProvider.allSubjectsMap[studyRecord.subject_id];
    final subjectColor = subject != null ? Color(int.parse(subject.color.replaceFirst('#', '0xFF'))) : Colors.grey;

    // Se a revisão estiver concluída, exibe o novo layout SIMILAR AO HISTÓRICO.
    if (reviewRecord.completed_date != null) {
      final completedDate = DateTime.parse(reviewRecord.completed_date!); // DEFINIDO AQUI

      // Lógica para encontrar o registro de estudo que EFETIVAMENTE completou a revisão.
      final completionRecords = studyRecords.where((sr) {
        if (sr.topic != reviewRecord.topic || sr.subject_id != studyRecord.subject_id || sr.category != 'revisao') {
          return false;
        }
        // Compara apenas a parte da data (ano, mês, dia), ignorando a hora.
        // A variável completedDate já está disponível do escopo superior.
        final recordDate = DateTime.parse(sr.date);
        return completedDate.year == recordDate.year &&
               completedDate.month == recordDate.month &&
               completedDate.day == recordDate.day;
      }).toList();

      // Ordena para pegar o mais recente, caso haja múltiplos no mesmo dia.
      completionRecords.sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

      // Usa o registro da conclusão se encontrado, senão usa o registro original como fallback.
      final recordToDisplay = completionRecords.isNotEmpty ? completionRecords.first : studyRecord;

      // Agora, usa 'recordToDisplay' para construir o card.
      final subject = historyProvider.allSubjectsMap[recordToDisplay.subject_id];
      final subjectName = subject?.subject ?? 'Desconhecido';
      final subjectColor = subject != null ? Color(int.parse(subject.color.replaceFirst('#', '0xFF'))) : Colors.grey;
      
      final time = formatTime(recordToDisplay.study_time);
      final correctQuestions = recordToDisplay.questions['correct'] ?? 0;
      final totalQuestions = recordToDisplay.questions['total'] ?? 0;
      final incorrectQuestions = totalQuestions - correctQuestions;
      final category = categoryDisplayMap[_getStudyCategoryFromString(recordToDisplay.category)] ?? recordToDisplay.category;

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 1.0,
        clipBehavior: Clip.antiAlias, // Mantém as bordas arredondadas
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: subjectColor,
                margin: const EdgeInsets.only(right: 8),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subjectName, style: Theme.of(context).textTheme.titleMedium),
                      Text(recordToDisplay.topic, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Concluída em: ${DateFormat('dd/MM/yyyy').format(completedDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          Chip(
                            label: Text(
                              category,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            backgroundColor: categoryColorMap[_getStudyCategoryFromString(recordToDisplay.category)] ?? Colors.grey,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          if (recordToDisplay.study_time > 0)
                            Chip(
                              label: Text(
                                time,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                              backgroundColor: Colors.teal.shade700,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          if (totalQuestions > 0) ...[
                            Chip(
                              label: Text(
                                '${correctQuestions} acertos',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                              backgroundColor: Colors.green.shade700,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            Chip(
                              label: Text(
                                '${incorrectQuestions} erros',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                              backgroundColor: Colors.red.shade700,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Layout original para revisões pendentes, atrasadas ou ignoradas.
    final scheduledDate = DateTime.parse(reviewRecord.scheduled_date).toUtc();
    final now = DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final diffDays = todayUtc.difference(scheduledDate).inDays;

    String statusText;
    Color statusColor;

    if (diffDays > 0) {
      statusText = 'Atrasada em $diffDays dia(s)';
      statusColor = Colors.red.shade700;
    } else if (diffDays == 0) {
      statusText = 'Revisar hoje';
      statusColor = Colors.green.shade700;
    } else {
      final daysUntilReview = diffDays.abs();
      statusText = 'Programada para daqui a $daysUntilReview dia(s)';
      statusColor = Colors.blue.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 10,
              color: subjectColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      (historyProvider.allSubjectsMap[studyRecord.subject_id]?.subject ?? 'Desconhecido').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        buildDatePill(context, DateTime.parse(reviewRecord.scheduled_date).toUtc()),
                        const SizedBox(width: 8),
                        Expanded(child: Text(reviewRecord.topic)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(categoryDisplayMap[_getStudyCategoryFromString(studyRecord.category)] ?? 'N/A'),
                          backgroundColor: categoryColorMap[_getStudyCategoryFromString(studyRecord.category)] ?? Colors.grey[200],
                          labelStyle: TextStyle(color: Colors.grey[800], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 8.0,
                      children: [
                        if (studyRecord.study_time > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 4), Text(formatTime(studyRecord.study_time))],
                          ),
                        if ((studyRecord.questions['total'] ?? 0) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('${studyRecord.questions['correct'] ?? 0}'),
                              const SizedBox(width: 8),
                              const Icon(Icons.cancel, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text('${(studyRecord.questions['total'] ?? 0) - (studyRecord.questions['correct'] ?? 0)}'),
                            ],
                          ),
                        if ((studyRecord.questions['total'] ?? 0) > 0)
                          Text(
                            '${((studyRecord.questions['correct'] ?? 0) / (studyRecord.questions['total'] ?? 1) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 8.0,
                      children: [
                        if (studyRecord.material != null && studyRecord.material!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [const Icon(Icons.book, size: 16), const SizedBox(width: 4), Text(studyRecord.material!)],
                          ),
                        if (studyRecord.pages != null && studyRecord.pages!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [const Icon(Icons.menu_book, size: 16), const SizedBox(width: 4), Text('Páginas: ${studyRecord.pages!.map((p) => '${p['start']}-${p['end']}').join(', ')}')],
                          ),
                        if (studyRecord.videos != null && studyRecord.videos!.any((v) => (v['title'] ?? '').isNotEmpty || (v['start'] ?? '00:00:00') != '00:00:00' || (v['end'] ?? '00:00:00') != '00:00:00'))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [const Icon(Icons.videocam, size: 16), const SizedBox(width: 4), Text('Vídeos: ${studyRecord.videos!.map((v) => '${v['title'] ?? ''} (${v['start'] ?? '00:00:00'} - ${v['end'] ?? '00:00:00'})').join(', ')}')],
                          ),
                        if (studyRecord.notes != null && studyRecord.notes!.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.comment, size: 16),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(studyRecord.notes!)),
                              );
                            },
                            tooltip: 'Ver Comentários',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.play_arrow, color: Colors.teal), onPressed: () async {
                  final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
                  final stopwatchProvider = Provider.of<StopwatchProvider>(context, listen: false);
                  final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
                  final planId = activePlanProvider.activePlan?.id;

                  if (planId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nenhum plano de estudo ativo selecionado.')),
                    );
                    return;
                  }

                  final subject = allSubjectsProvider.subjects.firstWhereOrNull((s) => s.id == studyRecord.subject_id);
                  final topic = subject != null ? _findTopicByText(subject.topics, reviewRecord.topic) : null;

                  stopwatchProvider.setContext(
                    planId: planId,
                    subjectId: studyRecord.subject_id,
                    topic: topic,
                  );

                  final result = await showDialog<Map<String, dynamic>?>( 
                    context: context,
                    builder: (ctx) => const StopwatchModal(),
                  );

                  if (result != null) {
                    final int time = result['time'];
                    final String? subjectId = result['subjectId'];
                    final Topic? topic = result['topic'];

                    if (subjectId != null && topic != null) {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final newRecord = StudyRecord(
                        id: Uuid().v4(),
                        userId: authProvider.currentUser!.name,
                        plan_id: planId,
                        date: DateTime.now().toIso8601String().split('T')[0],
                        subject_id: subjectId,
                        topic: topic.topic_text,
                        study_time: time,
                        category: 'revisao',
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
                        builder: (modalCtx) => StudyRegisterModal(
                          planId: newRecord.plan_id,
                          initialRecord: newRecord,
                          onSave: (record) {
                            historyProvider.addStudyRecord(record);
                          },
                        ),
                      );
                    }
                  }
                }, tooltip: 'Iniciar Revisão'),
                IconButton(icon: const Icon(Icons.check_circle, color: Colors.teal), onPressed: () async {
                  final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
                  final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
                  final planId = activePlanProvider.activePlan?.id;

                  if (planId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nenhum plano de estudo ativo selecionado.')),
                    );
                    return;
                  }

                  if (studyRecord.subject_id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erro: A revisão não está associada a nenhuma matéria.')),
                    );
                    return;
                  }

                  final subject = allSubjectsProvider.subjects.firstWhereOrNull((s) => s.id == studyRecord.subject_id);

                  final authProvider = Provider.of<AuthProvider>(context, listen: false); // Adicionado aqui
                  final newRecord = StudyRecord(
                    id: Uuid().v4(),
                    userId: authProvider.currentUser!.name,
                    plan_id: planId,
                    date: DateTime.now().toIso8601String().split('T')[0],
                    subject_id: studyRecord.subject_id!, // Agora seguro por causa da verificação acima
                    topic: reviewRecord.topic,
                    study_time: 0, // Será preenchido no modal
                    category: 'revisao',
                    questions: {},
                    review_periods: [],
                    teoria_finalizada: false,
                    count_in_planning: true,
                    pages: [],
                    videos: [],
                  );

                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (modalCtx) => StudyRegisterModal(
                      planId: newRecord.plan_id,
                      initialRecord: newRecord,
                      subject: subject, // Passa o objeto Subject
                      onSave: (record) {
                        historyProvider.addStudyRecord(record);
                        reviewProvider.markReviewAsCompleted(reviewRecord);
                      },
                    ),
                  );
                }, tooltip: 'Concluir'),
                IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () {
                  reviewProvider.ignoreReview(reviewRecord);
                }, tooltip: 'Ignorar'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
