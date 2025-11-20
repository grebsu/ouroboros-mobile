import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:uuid/uuid.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  bool _allTopicsExpanded = true;
  int _chartPeriodIndex = 2; // 0: daily, 1: weekly, 2: monthly

  void _openStudyRegisterModal({StudyRecord? record, Topic? topic}) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StudyRegisterModal(
        planId: widget.subject.plan_id,
        initialRecord: record,
        subject: widget.subject,
        topic: topic,
        onSave: (newRecord) {
          historyProvider.addStudyRecord(newRecord);
        },
        onUpdate: (updatedRecord) {
          historyProvider.updateStudyRecord(updatedRecord);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context);
    final historyProvider = Provider.of<HistoryProvider>(context);

    final studyHours = allSubjectsProvider.getStudyHoursForSubject(widget.subject.id);
    final performance = allSubjectsProvider.getPerformanceForSubject(widget.subject.id);

    final totalTopics = _countTopics(widget.subject.topics);
    final studiedTopics = _countStudiedTopics(widget.subject.topics, historyProvider.allStudyRecords);
    final progress = totalTopics > 0 ? (studiedTopics / totalTopics * 100).toStringAsFixed(0) : '0';

    final pagesRead = historyProvider.allStudyRecords
        .where((record) => record.subject_id == widget.subject.id)
        .fold<int>(0, (sum, record) {
          int recordPagesSum = 0;
          if (record.pages.isNotEmpty) {
            for (var p in record.pages) {

              if (p is Map<String, dynamic> && p.containsKey('start') && p.containsKey('end')) {
                final start = p['start'] as int?;
                final end = p['end'] as int?;
                if (start != null && end != null) {
                  recordPagesSum += (end - start + 1);
                }
              }
            }
          }
          return sum + recordPagesSum;
        });

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Colors.teal,
          secondary: Colors.teal,
        ),
        textSelectionTheme: Theme.of(context).textSelectionTheme.copyWith(
          cursorColor: Colors.teal,
          selectionColor: Colors.teal.withOpacity(0.4),
          selectionHandleColor: Colors.teal,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.subject.subject),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            // Header: Subject Name and Add Button


            // Four Summary Sections
            LayoutBuilder(
              builder: (context, constraints) {
                final orientation = MediaQuery.of(context).orientation;
                final isPortrait = orientation == Orientation.portrait;
                final crossAxisCount = isPortrait ? 2 : 4;
                final childAspectRatio = isPortrait ? 1.9 : 1.5;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: childAspectRatio,
                  children: <Widget>[
                    _buildSummaryCard(context, Icons.timer, 'Tempo de Estudo', studyHours),
                    _buildSummaryCard(context, Icons.trending_up, 'Desempenho', '${performance.toStringAsFixed(0)}%'),
                    _buildSummaryCard(context, Icons.assignment_turned_in, 'Progresso no Edital', '$progress%'),
                    _buildSummaryCard(context, Icons.menu_book, 'Páginas Lidas', pagesRead.toString()),
                  ],
                );
              },
            ),

            const SizedBox(height: 24.0),

                      // Edital Verticalizado (Topics)
                      Card(
                        elevation: 4.0,
                        color: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Edital Verticalizado',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  IconButton(
                                    icon: Icon(_allTopicsExpanded ? Icons.unfold_less : Icons.unfold_more, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _allTopicsExpanded = !_allTopicsExpanded;
                                      });
                                    },
                                  ),
                                ],
                              ),                    const SizedBox(height: 8.0),
                    // Display topics
                    if (widget.subject.topics.isEmpty)
                      const Text('Nenhum tópico cadastrado para esta disciplina.')
                    else
                      ..._buildTopicList(widget.subject.topics, 0, historyProvider.allStudyRecords),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24.0),

            // Histórico de Registros
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Histórico de Registros',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    _buildStudyHistoryTable(context, historyProvider.allStudyRecords.where((r) => r.subject_id == widget.subject.id).toList()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24.0),

            // Evolução no Tempo
            Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Evolução no Tempo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    _buildChart(context, historyProvider.allStudyRecords.where((r) => r.subject_id == widget.subject.id).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countTopics(List<Topic> topics) {
    int count = 0;
    for (final topic in topics) {
      count++;
      if (topic.sub_topics != null) {
        count += _countTopics(topic.sub_topics!);
      }
    }
    return count;
  }

  int _countStudiedTopics(List<Topic> topics, List<StudyRecord> records) {
    int count = 0;
    final studiedTopicTexts = records.map((r) => r.topic).toSet();
    for (final topic in topics) {
      if (studiedTopicTexts.contains(topic.topic_text)) {
        count++;
      }
      if (topic.sub_topics != null) {
        count += _countStudiedTopics(topic.sub_topics!, records);
      }
    }
    return count;
  }

  List<Widget> _buildTopicList(List<Topic> topics, int depth, List<StudyRecord> records) {
    List<Widget> topicWidgets = [];
    for (var topic in topics) {
      topicWidgets.add(
        TopicListItem(
          topic: topic,
          depth: depth,
          isInitiallyExpanded: _allTopicsExpanded,
          studiedTopicTexts: records.map((r) => r.topic).toSet(),
          onAdd: (Topic topic) => _openStudyRegisterModal(topic: topic),
        ),
      );
    }
    return topicWidgets;
  }

  Widget _buildSummaryCard(BuildContext context, IconData icon, String title, String value) {
    return Card(
      elevation: 4.0,
      color: Colors.teal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int milliseconds) {
    if (milliseconds < 0) return '0h 0m';
    final totalSeconds = milliseconds / 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  Widget _buildStudyHistoryTable(BuildContext context, List<StudyRecord> records) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Text('Nenhum registro de estudo para esta matéria ainda.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Primeiro Registro'),
              onPressed: () => _openStudyRegisterModal(),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (ctx, index) {
        final record = records[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 2.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(record.date)),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),
                          onPressed: () => _openStudyRegisterModal(record: record),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                            final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
                            historyProvider.deleteStudyRecord(record.id);
                            planningProvider.recalculateProgress(historyProvider.records);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  record.topic,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  'Categoria: ${record.category}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Tempo de Estudo: ${_formatTime(record.study_time)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChart(BuildContext context, List<StudyRecord> records) {
    if (records.isEmpty) {
      return const Center(child: Text('Nenhum registro de estudo para gerar o gráfico.'));
    }

    return Column(
      children: [
        ToggleButtons(
          isSelected: [_chartPeriodIndex == 0, _chartPeriodIndex == 1, _chartPeriodIndex == 2],
          onPressed: (index) {
            setState(() {
              _chartPeriodIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(8.0),
          selectedColor: Colors.white,
          color: Colors.teal,
          fillColor: Colors.teal,
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Diário')),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Semanal')),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Mensal')),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            _getChartData(records),
          ),
        ),
      ],
    );
  }

  LineChartData _getChartData(List<StudyRecord> records) {
    final Map<DateTime, double> aggregatedData = {};

    for (var record in records) {
      final date = DateTime.parse(record.date);
      final studyTimeHours = record.study_time / 3600000.0;
      DateTime key;

      if (_chartPeriodIndex == 0) { // Daily
        key = DateTime(date.year, date.month, date.day);
      } else if (_chartPeriodIndex == 1) { // Weekly
        key = date.subtract(Duration(days: date.weekday - 1));
        key = DateTime(key.year, key.month, key.day);
      } else { // Monthly
        key = DateTime(date.year, date.month);
      }

      aggregatedData[key] = (aggregatedData[key] ?? 0) + studyTimeHours;
    }

    final sortedKeys = aggregatedData.keys.toList()..sort();
    final List<FlSpot> spots = [];
    for (var i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), aggregatedData[sortedKeys[i]]!));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.black12,
            strokeWidth: 1,
            dashArray: [5],
          );
        },
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text('${value.toInt()}h', style: const TextStyle(color: Colors.black, fontSize: 10));
            },
            interval: 1,
            reservedSize: 28,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                final date = sortedKeys[value.toInt()];
                String format;
                if (_chartPeriodIndex == 0) {
                  format = 'dd/MM';
                } else if (_chartPeriodIndex == 1) {
                  format = 'dd/MM';
                } else {
                  format = 'MM/yy';
                }
                return SideTitleWidget(
                  meta: meta,
                  angle: -0.7, // Rotate labels
                  space: 8,
                  child: Text(DateFormat(format).format(date), style: const TextStyle(color: Colors.black, fontSize: 10)),
                );
              }
              return const Text('');
            },
            reservedSize: 40,
            interval: sortedKeys.length > 7 ? (sortedKeys.length / 7).ceilToDouble() : 1,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xffe7e7e7), width: 1),
      ),
      minX: 0,
      maxX: (sortedKeys.length - 1).toDouble(),
      minY: 0,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: const LinearGradient(
            colors: [Colors.teal, Colors.tealAccent],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.teal.withOpacity(0.3),
                Colors.tealAccent.withOpacity(0.3),
              ],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final flSpot = barSpot;
              if (flSpot.x.toInt() >= 0 && flSpot.x.toInt() < sortedKeys.length) {
                final date = sortedKeys[flSpot.x.toInt()];
                final hours = flSpot.y;
                return LineTooltipItem(
                  '${hours.toStringAsFixed(1)} horas\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: DateFormat('dd/MM/yyyy').format(date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              } else {
                return null;
              }
            }).whereType<LineTooltipItem>().toList();
          },
        ),
      ),
    );
  }
}

class TopicListItem extends StatefulWidget {
  final Topic topic;
  final int depth;
  final bool isInitiallyExpanded;
  final Set<String> studiedTopicTexts;
  final Function(Topic) onAdd;

  const TopicListItem({
    super.key,
    required this.topic,
    required this.depth,
    required this.isInitiallyExpanded,
    required this.studiedTopicTexts,
    required this.onAdd,
  });

  @override
  State<TopicListItem> createState() => _TopicListItemState();
}

class _TopicListItemState extends State<TopicListItem> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  void didUpdateWidget(TopicListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInitiallyExpanded != oldWidget.isInitiallyExpanded) {
      setState(() {
        _isExpanded = widget.isInitiallyExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSubtopics = widget.topic.sub_topics != null && widget.topic.sub_topics!.isNotEmpty;
    final bool isGroupingTopic = widget.topic.is_grouping_topic ?? false;
    final bool isStudied = widget.studiedTopicTexts.contains(widget.topic.topic_text);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: widget.depth * 16.0 + 16.0),
          leading: hasSubtopics
              ? IconButton(
                  icon: Icon(_isExpanded ? Icons.arrow_drop_down : Icons.arrow_right, color: Colors.white),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                )
              : const SizedBox(width: 48),
          title: Text(
            widget.topic.topic_text,
            style: TextStyle(
              fontWeight: isGroupingTopic ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                label: Text(
                  isStudied ? 'Concluído' : 'Pendente',
                  style: TextStyle(color: isStudied ? Colors.green.shade900 : Colors.red),
                ),
                backgroundColor: isStudied ? Colors.green.shade100 : Colors.red.shade100,
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: hasSubtopics ? Colors.grey.shade400 : Colors.white,
                ),
                onPressed: hasSubtopics ? null : () => widget.onAdd(widget.topic),
              ),
            ],
          ),
        ),
        if (_isExpanded && hasSubtopics)
          ...widget.topic.sub_topics!.map((subTopic) => TopicListItem(
                topic: subTopic,
                depth: widget.depth + 1,
                isInitiallyExpanded: widget.isInitiallyExpanded,
                studiedTopicTexts: widget.studiedTopicTexts,
                onAdd: widget.onAdd,
              )),
      ],
    );
  }
}