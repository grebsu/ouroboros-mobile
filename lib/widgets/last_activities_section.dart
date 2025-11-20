import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/screens/history_screen.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class LastActivitiesSection extends StatelessWidget {
  const LastActivitiesSection({Key? key}) : super(key: key);

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimas Atividades',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<HistoryProvider>(
              builder: (context, historyProvider, child) {
                if (historyProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }

                final latestActivities = (historyProvider.allStudyRecords..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)))).take(2).toList();

                if (latestActivities.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Nenhuma atividade registrada ainda.'),
                    ),
                  );
                }

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: latestActivities.length,
                      itemBuilder: (context, index) {
                        final activity = latestActivities[index];
                        final subject = historyProvider.allSubjectsMap[activity.subject_id];
                        return ActivityCard(activity: activity, subject: subject);
                      },
                    ),
                    if (historyProvider.allStudyRecords.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const HistoryScreen()));
                          },
                          child: Text(
                            'Ver Mais (${historyProvider.allStudyRecords.length - 2} sessões restantes)',
                            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final StudyRecord activity;
  final Subject? subject;

  const ActivityCard({Key? key, required this.activity, this.subject}) : super(key: key);

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.teal, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MaterialCommunityIcons.book_open_page_variant_outline, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject?.subject ?? 'Desconhecido',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 4.0, bottom: 8.0),
              child: Text(
                activity.topic,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(MaterialCommunityIcons.calendar_month, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 8),
                const Text('Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.parse(activity.date)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(MaterialCommunityIcons.clock_time_three_outline, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 8),
                const Text('Tempo de Estudo:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDuration(activity.study_time),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (activity.questions['total'] != null && activity.questions['total']! > 0)
              Row(
                children: [
                  Icon(MaterialCommunityIcons.comment_question, color: Colors.grey.shade500, size: 16),
                  const SizedBox(width: 8),
                  const Text('Questões:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${activity.questions['total']} (${activity.questions['correct']} certas)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
