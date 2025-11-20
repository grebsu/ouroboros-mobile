
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';

import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';

class StudySessionList extends StatefulWidget {
  final List<StudySession> cycle;
  final String planId;
  final Function(StudySession)? onStartStudy;
  final Function(StudySession)? onRegisterStudy;
  final bool isEditMode;
  final Function(String) onDeleteSession;
  final Function(StudySession) onDuplicateSession;
  final Function(int oldIndex, int newIndex) onReorder;
  final String emptyListMessage;
  final Map<String, int> sessionProgressMap;
  final Map<String, int> extraStudyTimeBySubjectId; // Novo campo

  const StudySessionList({
    Key? key,
    required this.cycle,
    required this.planId,
    this.onStartStudy,
    this.onRegisterStudy,
    this.isEditMode = false,
    required this.onDeleteSession,
    required this.onDuplicateSession,
    required this.onReorder,
    required this.emptyListMessage,
    required this.sessionProgressMap,
    this.extraStudyTimeBySubjectId = const {}, // Novo campo com valor padrão
  }) : super(key: key);

  @override
  State<StudySessionList> createState() => _StudySessionListState();
}

class _StudySessionListState extends State<StudySessionList> {
  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}min';
    }
    return '${remainingMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final sessionProgressMap = widget.sessionProgressMap;

    if (widget.cycle.isEmpty) {
      return Center(child: Text(widget.emptyListMessage));
    }

    Widget buildListItem(StudySession session, int index) {
      final currentProgress = sessionProgressMap[session.id] ?? 0;
      final isCompleted = currentProgress >= session.duration;
      final progressPercentage = session.duration > 0 ? currentProgress / session.duration : 0.0;
      final extraTime = widget.extraStudyTimeBySubjectId[session.subjectId] ?? 0;

      return Card(
        key: ValueKey(session.id),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Color(int.parse(session.color.replaceFirst('#', '0xFF')))),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.subject,
                style: isCompleted ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
              Text(
                '${_formatDuration(currentProgress)} / ${_formatDuration(session.duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(int.parse(session.color.replaceFirst('#', '0xFF')))),
                ),
              ),
              if (isCompleted && extraTime > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Chip(
                    label: Text(
                      '+ ${_formatDuration(extraTime)} (Extra)',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.indigo.shade400,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          trailing: widget.isEditMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => widget.onDuplicateSession(session),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => widget.onDeleteSession(session.id),
                    ),
                  ],
                )
              : (widget.onStartStudy != null && widget.onRegisterStudy != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => widget.onStartStudy!(session),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => widget.onRegisterStudy!(session),
                        ),
                      ],
                    )
                  : null),
        ),
      );
    }

    return widget.isEditMode
        ? ReorderableListView.builder(
            itemCount: widget.cycle.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              widget.onReorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final session = widget.cycle[index];
              return buildListItem(session, index);
            },
          )
        : ListView.builder(
            itemCount: widget.cycle.length,
            itemBuilder: (context, index) {
              final session = widget.cycle[index];
              return buildListItem(session, index);
            },
          );
  }
}
