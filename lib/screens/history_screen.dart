import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:intl/intl.dart';
import 'package:ouroboros_mobile/providers/subject_provider.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:ouroboros_mobile/widgets/filter_modal.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  StudyRecord? _editingRecord;
  String? _recordToDeleteId;

  final Map<String, String> _categoryDisplayMap = {
    'teoria': 'Teoria',
    'revisao': 'Revisão',
    'questoes': 'Questões',
    'leitura_lei': 'Leitura de Lei',
    'jurisprudencia': 'Jurisprudência',
  };

  final Map<String, Color> _categoryColors = {
    'teoria': Colors.blue.shade700,
    'revisao': Colors.green.shade700,
    'questoes': Colors.orange.shade700,
    'leitura_lei': Colors.purple.shade700,
    'jurisprudencia': Colors.red.shade700,
  };

  String _formatTime(int ms) {
    if (ms.isNaN || ms < 0) return '0h 0m';
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    return '${hours}h ${minutes}m';
  }

  void _openStudyRegisterModal({StudyRecord? record}) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StudyRegisterModal(
        planId: record!.plan_id,
        initialRecord: record,
        onSave: (newRecord) { // Embora seja edição, onSave pode ser usado para criar um novo se a lógica mudar
          historyProvider.addStudyRecord(newRecord);
        },
        onUpdate: (updatedRecord) {
          final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
          historyProvider.updateStudyRecord(updatedRecord);
          // Recalcula todo o progresso para garantir consistência.
          planningProvider.recalculateProgress(historyProvider.allStudyRecords);
        },
        onDelete: () {
          historyProvider.deleteStudyRecord(record.id);
        },
        showDeleteButton: true, // Mostra o botão de excluir no modo de edição
      ),
    );
  }

  void _showDeleteConfirmationDialog(String recordId) {
    setState(() {
      _recordToDeleteId = recordId;
    });
    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Confirmar Exclusão',
        message: 'Tem certeza que deseja excluir este registro? Esta ação não poderá ser desfeita.',
        onConfirm: () async {
          if (_recordToDeleteId != null) {
            final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
            final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
            await historyProvider.deleteStudyRecord(_recordToDeleteId!);
            planningProvider.recalculateProgress(historyProvider.allStudyRecords);
            Navigator.of(context).pop();
            setState(() {
              _recordToDeleteId = null;
            });
          }
        },
        onClose: () {
          Navigator.of(context).pop();
          setState(() {
            _recordToDeleteId = null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('HistoryScreen: build chamado.');
    return Consumer<FilterProvider>(
      builder: (context, filterProvider, child) {
        return Scaffold(
          body: Consumer<HistoryProvider>(
            builder: (context, provider, child) {
              print('HistoryScreen Consumer: isLoading=${provider.isLoading}, records.isEmpty=${provider.records.isEmpty}');
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }

              final filteredRecords = provider.records; // Records are already filtered by provider

              if (filteredRecords.isEmpty) {
                final bool filtersAreActive = filterProvider.historyStartDate != null ||
                    filterProvider.historyEndDate != null ||
                    filterProvider.historyMinDuration != null ||
                    filterProvider.historyMaxDuration != null ||
                    filterProvider.historyMinPerformance != null ||
                    filterProvider.historyMaxPerformance != null ||
                    filterProvider.historySelectedCategories.isNotEmpty ||
                    filterProvider.historySelectedSubjects.isNotEmpty ||
                    filterProvider.historySelectedTopics.isNotEmpty;

                return Center(
                  child: Text(
                    filtersAreActive
                        ? 'Nenhum registro corresponde aos filtros aplicados.'
                        : 'Nenhum registro de estudo encontrado. Comece adicionando seu primeiro estudo!',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // Group records by date
              final groupedRecords = <String, List<StudyRecord>>{};
              for (var record in filteredRecords) {
                final dateKey = DateFormat('dd/MM/yyyy').format(DateTime.parse(record.date));
                groupedRecords.putIfAbsent(dateKey, () => []).add(record);
              }

              final sortedDates = groupedRecords.keys.toList()
                ..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ...sortedDates.map((date) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(date, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        ...groupedRecords[date]!.map((record) => _buildRecordCard(context, record)).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, StudyRecord record) {
    final time = _formatTime(record.study_time); // Use helper
    final correctQuestions = record.questions['correct'] ?? 0;
    final totalQuestions = record.questions['total'] ?? 0;
    final incorrectQuestions = totalQuestions - correctQuestions;
    final questionsText = totalQuestions > 0
        ? '$correctQuestions acertos, $incorrectQuestions erros'
        : 'Nenhuma questão registrada';
    final category = _categoryDisplayMap[record.category] ?? record.category;

    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final subject = historyProvider.allSubjectsMap[record.subject_id];
    final subjectName = subject?.subject ?? 'Desconhecido';
    final subjectColor = subject != null ? Color(int.parse(subject.color.replaceFirst('#', '0xFF'))) : Colors.grey; // Default color

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 90,
              color: subjectColor,
              margin: const EdgeInsets.only(right: 8),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subjectName, style: Theme.of(context).textTheme.titleMedium),
                  Text(record.topic, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap( // Novo Wrap para agrupar os elementos lado a lado
                    spacing: 8.0, // Espaçamento entre os elementos
                    runSpacing: 4.0, // Espaçamento entre as linhas, se quebrar
                    children: [
                      Chip( // Categoria
                        label: Text(
                          category,
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        backgroundColor: _categoryColors[record.category] ?? Colors.grey,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip( // Tempo
                        label: Text(
                          time,
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        backgroundColor: Colors.teal.shade700,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (totalQuestions > 0) ...[
                        Chip( // Acertos
                          label: Text(
                            '$correctQuestions acertos',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.green.shade700,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        Chip( // Erros
                          label: Text(
                            '$incorrectQuestions erros',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.red.shade700,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ] else ...[
                        Chip( // Nenhuma questão registrada
                          label: Text(
                            'Nenhuma questão registrada',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: Colors.grey,
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
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openStudyRegisterModal(record: record),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmationDialog(record.id),
            ),
          ],
        ),
      ),
    );
  }
}
