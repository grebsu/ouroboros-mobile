import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/models/question_model.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/screens/questions/question_viewer_screen.dart';

class QuestionsListScreen extends StatefulWidget {
  final String subjectName;
  final String topicName;

  const QuestionsListScreen({
    super.key,
    required this.subjectName,
    required this.topicName,
  });

  @override
  State<QuestionsListScreen> createState() => _QuestionsListScreenState();
}

class _QuestionsListScreenState extends State<QuestionsListScreen> {
  List<Question> _questions = [];
  Map<String, UserQuestionResponse> _responses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionsAndResponses();
  }

  Future<void> _loadQuestionsAndResponses() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      final questions = await DatabaseService.instance
          .readQuestionsForUserTopic(widget.subjectName, widget.topicName);

      final responsesList =
          await DatabaseService.instance.readUserQuestionResponses(userId);
      final responsesMap = {
        for (var r in responsesList) r.questionId: r
      };

      setState(() {
        _questions = questions;
        _responses = responsesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar questões: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.teal,
              secondary: Colors.teal,
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.topicName, overflow: TextOverflow.ellipsis),
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _questions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma questão cadastrada para este tópico.',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use o script TecAnki para importar questões do Tec Concursos no banco de dados.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final question = _questions[index];
                      final response = _responses[question.id];

                      IconData statusIcon = Icons.help_outline;
                      Color statusColor = Colors.grey;
                      if (response != null) {
                        statusIcon = response.isCorrect ? Icons.check_circle : Icons.cancel;
                        statusColor = response.isCorrect ? Colors.green : Colors.red;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: 2.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(statusIcon, color: statusColor),
                          ),
                          title: Text(
                            'Questão #${question.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Banca: ${question.banca ?? 'Desconhecida'} | Ano: ${question.ano ?? 'N/A'}\n${question.orgao ?? ''}',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuestionViewerScreen(question: question),
                              ),
                            );
                            if (result == true) {
                              _loadQuestionsAndResponses();
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
