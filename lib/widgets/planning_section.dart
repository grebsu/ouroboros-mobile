import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/navigation_provider.dart';

class PlanningSection extends StatelessWidget {
  const PlanningSection({Key? key}) : super(key: key);

  Color _hexToColor(String hexString) {
    final hexCode = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
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
              'PLANEJAMENTO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<PlanningProvider>(
              builder: (context, planningProvider, child) {
                final studyCycle = planningProvider.studyCycle;
                final sessionProgressMap = planningProvider.sessionProgressMap;
                const displayLimit = 5;

                if (studyCycle == null || studyCycle.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Nenhum ciclo de estudos ativo. Crie um na página de planejamento.'),
                    ),
                  );
                }

                final uncompletedSessions = studyCycle.where((session) {
                  final progress = sessionProgressMap[session.id] ?? 0;
                  return progress < session.duration;
                }).toList();

                if (uncompletedSessions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Todas as sessões do planejamento foram concluídas!'),
                    ),
                  );
                }

                final displayedCycle = uncompletedSessions.take(displayLimit).toList();
                final hasMore = uncompletedSessions.length > displayLimit;

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedCycle.length,
                      itemBuilder: (context, index) {
                        final session = displayedCycle[index];
                        return Card(
                          color: _hexToColor(session.color),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              session.subject,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () {
                            context.read<NavigationProvider>().setIndex(1);
                          },
                          child: Text(
                            'Ver Mais (${uncompletedSessions.length - displayLimit} sessões restantes)',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold
                            ),
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
