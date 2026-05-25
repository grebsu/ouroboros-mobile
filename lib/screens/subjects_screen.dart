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
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (provider.subjects.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma matéria encontrada.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final screenWidth = MediaQuery.of(context).size.width;

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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _buildOverallStat(
                        context,
                        Icons.book,
                        totalStudyHours,
                        'Total de Horas',
                        iconSize: 42,
                      ),
                      _buildOverallStat(
                        context,
                        Icons.quiz,
                        totalQuestions.toString(),
                        'Total de Questões',
                        iconSize: 42,
                      ),
                      _buildOverallStat(
                        context,
                        Icons.bar_chart,
                        '${overallPerformance.toStringAsFixed(0)}%',
                        'Desempenho Geral',
                        iconSize: 42,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24.0),

              // List of Subject Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400.0,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.2,
                ),
                itemCount: provider.subjects.length,
                itemBuilder: (context, index) {
                  final subject = provider.subjects[index];
                  final planName =
                      provider.plansMap[subject.plan_id]?.name ??
                      'Plano Desconhecido';

                  final studyHours = provider.getStudyHoursForSubject(
                    subject.id,
                  );
                  final questions = provider.getQuestionsForSubject(subject.id);
                  final performance = provider.getPerformanceForSubject(
                    subject.id,
                  );

                  return _SubjectCardWidget(
                    subject: subject,
                    studyHours: studyHours,
                    questions: questions.toString(),
                    performance: '${performance.toStringAsFixed(0)}%',
                    planName: planName,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SubjectDetailScreen(subject: subject),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverallStat(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    double iconSize = 24.0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: Colors.teal),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: iconSize > 30 ? 16 : 14,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(
            fontSize: iconSize > 30 ? 12 : 10,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SubjectCardWidget extends StatefulWidget {
  final Subject subject;
  final String studyHours;
  final String questions;
  final String performance;
  final String planName;
  final VoidCallback onTap;

  const _SubjectCardWidget({
    required this.subject,
    required this.studyHours,
    required this.questions,
    required this.performance,
    required this.planName,
    required this.onTap,
  });

  @override
  State<_SubjectCardWidget> createState() => _SubjectCardWidgetState();
}

class _SubjectCardWidgetState extends State<_SubjectCardWidget> {
  bool _showOverlay = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _showOverlay = true),
      onExit: (_) => setState(() => _showOverlay = false),
      child: GestureDetector(
        onTap: () {
          if (_showOverlay) {
            widget.onTap(); // Segundo toque: navega
          } else {
            setState(() => _showOverlay = true); // Primeiro toque: mostra overlay
          }
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: Color(int.parse(widget.subject.color.replaceFirst('#', '0xFF'))),
          elevation: _showOverlay ? 8.0 : 4.0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Color(int.parse(widget.subject.color.replaceFirst('#', '0xFF'))),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.subject.subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildStatItem(
                            context,
                            Icons.timer,
                            widget.studyHours,
                            'Horas',
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            Icons.check_circle,
                            widget.questions,
                            'Questões',
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            Icons.trending_up,
                            widget.performance,
                            'Desempenho',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Presente nos Planos:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    SizedBox(
                      height: 32,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4.0,
                          runSpacing: 2.0,
                          alignment: WrapAlignment.center,
                          children: [
                            Chip(
                              label: Text(widget.planName,
                                  style: const TextStyle(fontSize: 9)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Overlay de "Visualizar"
              IgnorePointer( // Permite que o GestureDetector do pai receba o clique
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showOverlay ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Visualizar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24.0, color: Colors.teal),
        ),
        const SizedBox(height: 4.0),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
