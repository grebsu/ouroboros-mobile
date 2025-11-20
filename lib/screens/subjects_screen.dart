import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/screens/subject_detail_screen.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AllSubjectsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (provider.subjects.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma matéria encontrada.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final orientation = MediaQuery.of(context).orientation;
          final crossAxisCount = orientation == Orientation.portrait ? 1 : 3;
          final childAspectRatio = orientation == Orientation.portrait ? 1.4 : 1.0;

          final totalStudyHours = provider.getTotalStudyHours();
          final totalQuestions = provider.getTotalQuestions();
          final overallPerformance = provider.getOverallPerformance();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              // Header: Title and Description
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Visão Geral das Matérias',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Acompanhe seu progresso em todas as disciplinas.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),

              // Overall Stats Card
              Card(
                color: Colors.teal,
                elevation: 4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _buildOverallStat(context, Icons.book, totalStudyHours, 'Total de Horas'),
                      _buildOverallStat(context, Icons.quiz, totalQuestions.toString(), 'Total de Questões'),
                      _buildOverallStat(context, Icons.bar_chart, '${overallPerformance.toStringAsFixed(0)}%', 'Desempenho Geral'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24.0),

              // List of Subject Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: provider.subjects.length,
                itemBuilder: (context, index) {
                  final subject = provider.subjects[index];
                  final planName = provider.plansMap[subject.plan_id]?.name ?? 'Plano Desconhecido';

                  final studyHours = provider.getStudyHoursForSubject(subject.id);
                  final questions = provider.getQuestionsForSubject(subject.id);
                  final performance = provider.getPerformanceForSubject(subject.id);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubjectDetailScreen(subject: subject),
                        ),
                      );
                    },
                    child: _buildSubjectCard(context, subject, studyHours, questions.toString(), '${performance.toStringAsFixed(0)}%', [planName]),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverallStat(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
                      child: Icon(icon, size: 42, color: Colors.teal),        ),
        const SizedBox(height: 4.0),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: Colors.white), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject, String studyHours, String questions, String performance, List<String> plans) {
    return Card(
      color: Color(int.parse(subject.color.replaceFirst('#', '0xFF'))),
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(int.parse(subject.color.replaceFirst('#', '0xFF'))), width: 2), // Use subject color
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              subject.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center, // Centralize the subject title
            ),
            const SizedBox(height: 8.0),
            Row(
              children: <Widget>[
                Expanded(child: _buildOverallStat(context, Icons.timer, studyHours, 'Horas')),
                const SizedBox(width: 8.0),
                Expanded(child: _buildOverallStat(context, Icons.check_circle, questions, 'Questões')),
                const SizedBox(width: 8.0),
                Expanded(child: _buildOverallStat(context, Icons.trending_up, performance, 'Desempenho')),
              ],
            ),
            const SizedBox(height: 8.0),
            Text('Presente nos Planos:', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            const SizedBox(height: 4.0),
            SingleChildScrollView(
                child: Wrap(
                  spacing: 4.0,
                  runSpacing: 2.0,
                  children: plans.map((plan) => Chip(label: Text(plan, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
