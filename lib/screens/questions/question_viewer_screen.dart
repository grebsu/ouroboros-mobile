import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/models/question_model.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class QuestionViewerScreen extends StatefulWidget {
  final Question question;

  const QuestionViewerScreen({super.key, required this.question});

  @override
  State<QuestionViewerScreen> createState() => _QuestionViewerScreenState();
}

class _QuestionViewerScreenState extends State<QuestionViewerScreen> {
  String? _selectedAlternative;
  bool _isAnswered = false;
  bool _isCorrect = false;
  UserQuestionResponse? _previousResponse;
  bool _isLoading = true;

  // AnkiPowerChoice visualizer states
  final Set<String> _struckAlternatives = {};
  bool _showProfessorComment = false;
  bool _showForumComment = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousResponse();
  }

  Future<void> _loadPreviousResponse() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      final response = await DatabaseService.instance.readResponseForQuestion(
        widget.question.id,
        userId,
      );

      if (response != null) {
        setState(() {
          _previousResponse = response;
          _selectedAlternative = response.selectedAlternative;
          _isAnswered = true;
          _isCorrect = response.isCorrect;
          // Auto reveal explanations if already answered
          if (widget.question.comentarioProfessor != null &&
              widget.question.comentarioProfessor!.isNotEmpty) {
            _showProfessorComment = true;
          }
          if (widget.question.comentarioForum != null &&
              widget.question.comentarioForum!.isNotEmpty) {
            _showForumComment = true;
          }
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    // Basic formatting replacement
    String result = htmlString
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '') // Strip other tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
    return result;
  }

  Future<void> _submitAnswer() async {
    if (_isAnswered || _selectedAlternative == null) return;

    final isCorrect =
        _selectedAlternative!.toUpperCase() ==
        widget.question.gabarito.toUpperCase();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id ?? '';

    final response = UserQuestionResponse(
      id: const Uuid().v4(),
      userId: userId,
      questionId: widget.question.id,
      selectedAlternative: _selectedAlternative!,
      isCorrect: isCorrect,
      answeredAt: DateTime.now().toIso8601String(),
    );

    try {
      await DatabaseService.instance.createUserQuestionResponse(response);
      setState(() {
        _isAnswered = true;
        _isCorrect = isCorrect;
        // Auto reveal comments upon answering
        if (widget.question.comentarioProfessor != null &&
            widget.question.comentarioProfessor!.isNotEmpty) {
          _showProfessorComment = true;
        }
        if (widget.question.comentarioForum != null &&
            widget.question.comentarioForum!.isNotEmpty) {
          _showForumComment = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCorrect ? 'Resposta Correta! 🎉' : 'Resposta Incorreta. ❌',
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar resposta: $e')));
    }
  }

  Widget _buildHeader() {
    final hasProfessor =
        widget.question.comentarioProfessor != null &&
        widget.question.comentarioProfessor!.isNotEmpty;
    final hasForum =
        widget.question.comentarioForum != null &&
        widget.question.comentarioForum!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Info: Matéria and Assunto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📚 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            widget.question.banca ?? 'Matéria',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🎯 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'Assunto da Questão',
                            style: TextStyle(
                              color: Colors.teal.shade100,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Header actions: toggle explanation/forum comments
              Row(
                children: [
                  if (hasProfessor)
                    IconButton(
                      icon: Opacity(
                        opacity: _showProfessorComment ? 1.0 : 0.4,
                        child: const Text('🎓', style: TextStyle(fontSize: 20)),
                      ),
                      onPressed: () {
                        setState(() {
                          _showProfessorComment = !_showProfessorComment;
                        });
                      },
                      tooltip: 'Comentário do Professor',
                    ),
                  if (hasForum)
                    IconButton(
                      icon: Opacity(
                        opacity: _showForumComment ? 1.0 : 0.4,
                        child: const Text('💬', style: TextStyle(fontSize: 20)),
                      ),
                      onPressed: () {
                        setState(() {
                          _showForumComment = !_showForumComment;
                        });
                      },
                      tooltip: 'Fórum de Discussão',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          // Lower Info: ID, Banca, Ano
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🆔 ID: #${widget.question.id}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '🏛️ Banca: ${widget.question.banca ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '📅 Ano: ${widget.question.ano ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesList() {
    final letters = ['A', 'B', 'C', 'D', 'E'];
    final uniqueAlts = widget.question.alternativas
        .map((alt) => _cleanHtml(alt))
        .toSet()
        .toList();

    bool isCertoErrado = false;
    if (uniqueAlts.length == 2) {
      final alt1 = uniqueAlts[0].toLowerCase().trim();
      final alt2 = uniqueAlts[1].toLowerCase().trim();
      if ((alt1 == 'certo' && alt2 == 'errado') ||
          (alt1 == 'errado' && alt2 == 'certo')) {
        isCertoErrado = true;
      }
    }

    return Column(
      children: List.generate(uniqueAlts.length, (index) {
        final altText = uniqueAlts[index];

        String altLetter;
        if (isCertoErrado) {
          altLetter = altText.toLowerCase().trim() == 'certo' ? 'C' : 'E';
        } else {
          altLetter = index < letters.length ? letters[index] : '?';
        }

        final isSelected = _selectedAlternative == altLetter;
        final isGabarito = widget.question.gabarito.toUpperCase() == altLetter;
        final isStruck = _struckAlternatives.contains(altLetter);

        Color cardColor = Theme.of(context).cardColor;
        Color borderColor = Colors.grey.shade700;
        double opacity = isStruck ? 0.4 : 1.0;

        if (_isAnswered) {
          if (isGabarito) {
            cardColor = Colors.green.shade900.withOpacity(0.2);
            borderColor = Colors.green;
          } else if (isSelected) {
            cardColor = Colors.red.shade900.withOpacity(0.2);
            borderColor = Colors.red;
          } else {
            opacity = 0.5;
          }
        } else if (isSelected) {
          borderColor = Colors.teal;
        }

        return Opacity(
          opacity: opacity,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: borderColor,
                width: isSelected || (_isAnswered && isGabarito) ? 2.0 : 1.0,
              ),
            ),
            color: cardColor,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: (_isAnswered || isStruck)
                        ? null
                        : () {
                            setState(() {
                              _selectedAlternative = altLetter;
                            });
                          },
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelected
                                ? Colors.teal
                                : (_isAnswered && isGabarito
                                      ? Colors.green
                                      : Colors.grey.shade800),
                            child: Text(
                              altLetter,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HtmlWidget(
                              altText,
                              textStyle: TextStyle(
                                fontSize: 14,
                                decoration: isStruck
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Strike through action button
                if (!_isAnswered)
                  IconButton(
                    icon: Icon(
                      isStruck ? Icons.restore : Icons.block,
                      color: isStruck ? Colors.grey : Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isStruck) {
                          _struckAlternatives.remove(altLetter);
                        } else {
                          _struckAlternatives.add(altLetter);
                          if (_selectedAlternative == altLetter) {
                            _selectedAlternative = null;
                          }
                        }
                      });
                    },
                    tooltip: isStruck
                        ? 'Restaurar alternativa'
                        : 'Riscar alternativa',
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCommentBox({
    required String title,
    required String content,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          HtmlWidget(
            content,
            textStyle: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: Colors.teal, secondary: Colors.teal),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Questão'),
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          // Enunciado
                          HtmlWidget(
                            widget.question.enunciado,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          // Alternativas
                          _buildAlternativesList(),
                          // Professor Comment
                          if (_showProfessorComment &&
                              widget.question.comentarioProfessor != null &&
                              widget.question.comentarioProfessor!.isNotEmpty)
                            _buildCommentBox(
                              title: 'EXPLICAÇÃO DO PROFESSOR',
                              content: widget.question.comentarioProfessor!,
                              accentColor: Colors.teal,
                            ),
                          // Forum Comment
                          if (_showForumComment &&
                              widget.question.comentarioForum != null &&
                              widget.question.comentarioForum!.isNotEmpty)
                            _buildCommentBox(
                              title: 'DISCUSSÃO DO FÓRUM',
                              content: widget.question.comentarioForum!,
                              accentColor: Colors.green,
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Respond control button
                  if (!_isAnswered)
                    SafeArea(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).cardColor,
                        child: ElevatedButton(
                          onPressed: _selectedAlternative == null
                              ? null
                              : _submitAnswer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'RESPONDER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
