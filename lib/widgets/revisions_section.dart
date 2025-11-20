import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/navigation_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';


class RevisionsSection extends StatelessWidget {
  const RevisionsSection({Key? key}) : super(key: key);

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
              'Próximas Revisões',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer2<ReviewProvider, NavigationProvider>(
              builder: (context, reviewProvider, navigationProvider, child) {
                if (reviewProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }

                final pendingReviews = reviewProvider.allReviewRecords
                    .where((record) => record.completed_date == null && !record.ignored)
                    .toList();

                pendingReviews.sort((a, b) => a.scheduled_date.compareTo(b.scheduled_date));

                if (pendingReviews.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Nenhuma revisão pendente.'),
                    ),
                  );
                }

                final reviewsToShow = pendingReviews.take(3).toList();
                final remainingCount = pendingReviews.length - reviewsToShow.length;

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviewsToShow.length,
                      itemBuilder: (context, index) {
                        final record = reviewsToShow[index];
                        return RevisionCard(record: record);
                      },
                    ),
                    if (remainingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: TextButton(
                          onPressed: () {
                            // Supondo que o índice da tela de revisões é 2
                            navigationProvider.setIndex(2); 
                          },
                          child: Text(
                            'Ver mais ($remainingCount Revisões Restantes)',
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
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

class RevisionCard extends StatelessWidget {
  final ReviewRecord record;

  const RevisionCard({Key? key, required this.record}) : super(key: key);

  int getDaysOverdue(String scheduledDateStr) {
    try {
      final now = DateTime.now();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      DateTime scheduledDate;
      try {
        scheduledDate = DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').parse(scheduledDateStr, true).toUtc();
      } catch (e) {
        scheduledDate = DateFormat('yyyy-MM-dd').parse(scheduledDateStr, true).toUtc();
      }
      final diff = todayUtc.difference(scheduledDate).inDays;
      return diff;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
    final subject = allSubjectsProvider.subjects.firstWhere((s) => s.id == record.subject_id, orElse: () => Subject(id: '', plan_id: '', subject: 'Desconhecido', color: '#808080', topics: []));
    final subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));

    final dayDifference = getDaysOverdue(record.scheduled_date);
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (dayDifference > 0) {
      statusText = 'Atrasada há $dayDifference dia(s)';
      statusColor = Colors.red.shade700;
      statusIcon = Icons.warning_amber_rounded;
    } else if (dayDifference == 0) {
      statusText = 'Revisão para hoje';
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle_outline;
    } else {
      final daysUntil = dayDifference.abs();
      statusText = 'Revisão em $daysUntil dia(s)';
      statusColor = Colors.blue.shade700;
      statusIcon = Icons.timelapse;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.topic,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          statusIcon,
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(MaterialCommunityIcons.check_circle_outline, color: Colors.green),
                  onPressed: () {
                    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
                    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
                    final planId = activePlanProvider.activePlan?.id;

                    if (planId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhum plano de estudo ativo selecionado.')),
                      );
                      return;
                    }
                    
                    if (record.subject_id == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erro: A revisão não está associada a nenhuma matéria.')),
                      );
                      return;
                    }

                    final subject = allSubjectsProvider.subjects.firstWhereOrNull((s) => s.id == record.subject_id);
                    
                    final newRecord = StudyRecord(
                      id: Uuid().v4(),
                      userId: authProvider.currentUser!.name,
                      plan_id: planId,
                      date: DateTime.now().toIso8601String().split('T')[0],
                      subject_id: record.subject_id!, // Agora seguro por causa da verificação acima
                      topic: record.topic,
                      study_time: 0, // Inicia zerado para o usuário preencher
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
                        subject: subject, // Passa o objeto Subject
                        onSave: (savedRecord) {
                          historyProvider.addStudyRecord(savedRecord);
                          reviewProvider.markReviewAsCompleted(record);
                        },
                      ),
                    );
                  },
                  tooltip: 'Concluir Revisão',
                ),
                IconButton(
                  icon: const Icon(MaterialCommunityIcons.close_circle_outline, color: Colors.red),
                  onPressed: () {
                    reviewProvider.ignoreReview(record);
                  },
                  tooltip: 'Ignorar por agora',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
