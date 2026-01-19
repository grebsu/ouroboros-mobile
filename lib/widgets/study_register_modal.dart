import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/widgets/add_subject_modal.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';

import 'package:ouroboros_mobile/providers/planning_provider.dart';

class StudyRegisterModal extends StatefulWidget {
  final String planId;
  final Function(StudyRecord) onSave;
  final Function(StudyRecord)? onUpdate;
  final StudyRecord? initialRecord;
  final Subject? subject;
  final Topic? topic;
  final String? justification;
  final int? initialTime;
  final bool showDeleteButton;
  final Function()? onDelete;

  const StudyRegisterModal({
    super.key,
    required this.planId,
    required this.onSave,
    this.onUpdate,
    this.initialRecord,
    this.subject,
    this.topic,
    this.justification,
    this.initialTime,
    this.showDeleteButton = false,
    this.onDelete,
  });

  @override
  State<StudyRegisterModal> createState() => _StudyRegisterModalState();
}

class _StudyRegisterModalState extends State<StudyRegisterModal> {
  final _formKey = GlobalKey<FormState>();

  // State variables
  late DateTime _selectedDate;
  Subject? _selectedSubject;
  List<Topic> _allAvailableTopics =
      []; // Todos os tópicos da disciplina selecionada
  // NOVO: Lista de TopicProgress para o registro atual
  List<TopicProgress> _currentTopicsProgress = [];
  int _activeTopicProgressIndex =
      0; // Índice do TopicProgress atualmente visível/editável

  String? _selectedCategory;
  final TextEditingController _studyTimeController = TextEditingController(
    text: '00:00:00',
  );
  // Removed old progress controllers as they are now per TopicProgress
  final TextEditingController _notesController = TextEditingController();
  bool _countInPlanning = true;
  bool _isReviewSchedulingEnabled = false;
  List<String> _reviewPeriods = [];
  Map<String, String> _errors = {};

  // Controladores e variáveis de estado temporárias para o TopicProgress ativo
  late TextEditingController _activeTpCorrectQuestionsController;
  late TextEditingController _activeTpIncorrectQuestionsController;
  late TextEditingController _activeTpStartPageController;
  late TextEditingController _activeTpEndPageController;
  late List<Map<String, int>> _activeTpPages;
  late List<Map<String, String>> _activeTpVideos;
  // NOVO: Controladores para os campos de vídeo
  final List<TextEditingController> _activeTpVideoTitleControllers = [];
  final List<TextEditingController> _activeTpVideoStartControllers = [];
  final List<TextEditingController> _activeTpVideoEndControllers = [];
  late bool _activeTpIsTeoriaFinalizada;
  late ScrollController
  _horizontalScrollController; // NOVO: Controlador para a rolagem horizontal
  @override
  void initState() {
    super.initState();

    _horizontalScrollController = ScrollController();

    // Inicialização dos controladores temporários
    _activeTpCorrectQuestionsController = TextEditingController(text: '0');
    _activeTpIncorrectQuestionsController = TextEditingController(text: '0');
    _activeTpStartPageController = TextEditingController(text: '0');
    _activeTpEndPageController = TextEditingController(text: '0');
    _activeTpPages = [];
    _activeTpVideos = [
      {'title': '', 'start': '00:00:00', 'end': '00:00:00'},
    ];
    _activeTpIsTeoriaFinalizada = false;

    _reviewPeriods = []; // Inicializa vazia ou com base no initialRecord

    if (widget.initialRecord != null) {
      // Editar um registro existente
      final record = widget.initialRecord!;
      _selectedDate = DateTime.parse(record.date);
      _selectedCategory = record.category;
      _studyTimeController.text = _formatTime(record.study_time);
      _notesController.text = record.topicsProgress.isNotEmpty
          ? record.topicsProgress.first.notes ?? ''
          : '';
      _countInPlanning = record.count_in_planning;
      _reviewPeriods = List.from(record.review_periods);
      _isReviewSchedulingEnabled = _reviewPeriods.isNotEmpty;
      _currentTopicsProgress = List.from(record.topicsProgress);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final allSubjectsProvider = Provider.of<AllSubjectsProvider>(
          context,
          listen: false,
        );
        final subjects = allSubjectsProvider.subjects
            .where((s) => s.plan_id == widget.planId)
            .toList();
        if (subjects.isNotEmpty) {
          try {
            _selectedSubject = subjects.firstWhere(
              (s) => s.id == record.subject_id,
            );
            // Também carregamos todos os tópicos disponíveis para o subject selecionado
            // para que a seleção de tópicos funcione corretamente.
            _allAvailableTopics = _selectedSubject!.topics;
            // Carregar os dados do primeiro TopicProgress (se houver)
            if (_currentTopicsProgress.isNotEmpty) {
              _loadActiveTopicProgressIntoControllers();
            }
          } catch (e) {
            // Handle case where subject is not found
          }
        }
        setState(() {}); // Update UI with found subject/topic
      });
    } else {
      // Criar um novo registro
      _selectedDate = DateTime.now();
      _selectedSubject = widget.subject;
      _studyTimeController.text = _formatTime(widget.initialTime ?? 0);
      _selectedCategory = 'teoria'; // Default para novos registros
      _countInPlanning = true;
      _currentTopicsProgress =
          []; // Inicia com lista vazia para novos registros
      // Se um tópico e matéria iniciais foram passados (ex: da sugestão do algoritmo), pré-preencher
      if (widget.subject != null && widget.topic != null) {
        _selectedSubject = widget.subject;
        _allAvailableTopics = _selectedSubject!.topics;
        _currentTopicsProgress.add(
          TopicProgress(
            topicId: widget.topic!.id.toString(),
            topicText: widget.topic!.topic_text,
            isTheoryFinished: false, // Default
            userWeight: widget.topic!.userWeight,
          ),
        );
        // Carregar os dados do TopicProgress recém-criado
        _loadActiveTopicProgressIntoControllers();
      }
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose(); // Descartar no dispose
    _studyTimeController.dispose();
    _notesController.dispose();
    _activeTpCorrectQuestionsController.dispose();
    _activeTpIncorrectQuestionsController.dispose();
    _activeTpStartPageController.dispose();
    _activeTpEndPageController.dispose();

    // NOVO: Descarte dos controladores de vídeo
    for (var controller in _activeTpVideoTitleControllers) {
      controller.dispose();
    }
    for (var controller in _activeTpVideoStartControllers) {
      controller.dispose();
    }
    for (var controller in _activeTpVideoEndControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  String _formatTime(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _parseTime(String timeStr) {
    final parts = timeStr.split(':').map(int.tryParse).toList();
    if (parts.length == 3 && parts.every((p) => p != null)) {
      return (parts[0]! * 3600 + parts[1]! * 60 + parts[2]!) * 1000;
    }
    return 0;
  }

  bool _validateForm() {
    final newErrors = <String, String>{};
    final timeRegex = RegExp(r'^([0-9]?[0-9]):[0-5][0-9]:[0-5][0-9]$');

    if (_selectedSubject == null)
      newErrors['subject'] = 'Selecione uma disciplina';
    if (_selectedCategory == null)
      newErrors['category'] = 'Selecione uma categoria';
    if (_studyTimeController.text == '00:00:00') {
      newErrors['studyTime'] = 'Informe o tempo de estudo';
    }
    if (!timeRegex.hasMatch(_studyTimeController.text)) {
      newErrors['studyTime'] = 'Formato de tempo inválido (HH:MM:SS)';
    }

    if (_currentTopicsProgress.isEmpty) {
      newErrors['topicsProgress'] = 'Selecione pelo menos um tópico';
    } else {
      for (int i = 0; i < _currentTopicsProgress.length; i++) {
        final tp = _currentTopicsProgress[i];
        // Validações para as questões
        if ((tp.questions['total'] ?? 0) < 0 ||
            (tp.questions['correct'] ?? 0) < 0) {
          newErrors['topicProgress-$i-questions'] =
              'Valores de questões não podem ser negativos';
        }
        if ((tp.questions['correct'] ?? 0) > (tp.questions['total'] ?? 0)) {
          newErrors['topicProgress-$i-questions'] =
              'Acertos não podem ser maiores que o total';
        }

        // Validações para as páginas
        for (int j = 0; j < tp.pages.length; j++) {
          final page = tp.pages[j];
          if (page['start']! < 0 || page['end']! < 0) {
            newErrors['topicProgress-$i-page-$j'] =
                'Páginas não podem ser negativas';
          }
          if (page['end']! < page['start']!) {
            newErrors['topicProgress-$i-page-$j'] =
                'Página final deve ser maior ou igual à inicial';
          }
        }

        // Validações para os vídeos
        for (int j = 0; j < tp.videos.length; j++) {
          final video = tp.videos[j];
          final hasInfo =
              video['title']!.trim().isNotEmpty ||
              video['start'] != '00:00:00' ||
              video['end'] != '00:00:00';
          if (hasInfo) {
            if (video['title']!.trim().isEmpty) {
              newErrors['topicProgress-$i-video-title-$j'] =
                  'Título do vídeo é obrigatório';
            }
            if (!timeRegex.hasMatch(video['start']!) ||
                !timeRegex.hasMatch(video['end']!)) {
              newErrors['topicProgress-$i-video-time-$j'] =
                  'Formato de tempo inválido (HH:MM:SS)';
            }
            if (_parseTime(video['end']!) < _parseTime(video['start']!)) {
              newErrors['topicProgress-$i-video-time-$j'] =
                  'Tempo final deve ser maior ou igual ao inicial';
            }
          }
        }
      }
    }
    setState(() => _errors = newErrors);
    return newErrors.isEmpty;
  }

  void _showAddReviewDialog() {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: theme.colorScheme.onSurface),
            const SizedBox(width: 12),
            Text(
              'Adicionar Revisão',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe em quantos dias a partir da data do estudo você deseja agendar a próxima revisão.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAddChip('1d'),
                _buildQuickAddChip('7d'),
                _buildQuickAddChip('30d'),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                labelText: 'Dias para a revisão',
                labelStyle: const TextStyle(color: Colors.teal),
                prefixIcon: const Icon(Icons.timelapse, color: Colors.teal),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              cursorColor: Colors.teal,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Adicionar'),
            onPressed: () {
              final days = int.tryParse(controller.text);
              if (days != null && days > 0) {
                setState(() => _reviewPeriods.add('${days}d'));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(String period) {
    return ActionChip(
      label: Text(
        period,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.teal,
      onPressed: () {
        setState(() {
          if (!_reviewPeriods.contains(period)) {
            _reviewPeriods.add(period);
          }
        });
      },
    );
  }

  void _showTopicSelector() async {
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma disciplina primeiro.'),
        ),
      );
      return;
    }

    // Copiar os tópicos disponíveis para que _TopicSelectionSheet possa manipulá-los
    _allAvailableTopics = _selectedSubject!.topics;

    final selectedTopicsFromSheet = await showModalBottomSheet<List<Topic>?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (BuildContext context, ScrollController scrollController) {
            return _TopicSelectionSheet(
              topics: _allAvailableTopics, // Passa todos os tópicos disponíveis
              scrollController: scrollController,
              onTopicsSelected: (topics) {
                Navigator.of(context).pop(topics); // Retorna a lista de Topics
              },
              // Passa os IDs dos TopicProgress atuais para inicializar a seleção
              initialSelectedTopicIds: _currentTopicsProgress
                  .map((tp) => tp.topicId)
                  .toList(),
            );
          },
        );
      },
    );

    if (selectedTopicsFromSheet != null) {
      setState(() {
        // Mapeia os Topics selecionados de volta para TopicProgress
        _currentTopicsProgress = selectedTopicsFromSheet.map((topic) {
          // Tenta encontrar um TopicProgress existente para este tópico
          final existingTp = _currentTopicsProgress.firstWhere(
            (tp) => tp.topicId == topic.id.toString(),
            orElse: () => TopicProgress(
              topicId: topic.id.toString(),
              topicText: topic.topic_text,
              // Initializa com valores padrão para um novo TopicProgress
              questions: {'total': 0, 'correct': 0},
              pages: [],
              videos: [],
              notes: null,
              isTheoryFinished: false,
              userWeight: topic.userWeight,
            ),
          );
          return existingTp;
        }).toList();

        if (_currentTopicsProgress.isEmpty) {
          _errors['topicsProgress'] = 'Selecione pelo menos um tópico';
        } else {
          _errors.remove('topicsProgress');
        }
      });
    }
  }

  void _saveForm() {
    if (!_validateForm()) return;

    // Atualiza o TopicProgress ativo com os dados dos controladores de texto antes de salvar
    // Isso é crucial para que as últimas edições no formulário sejam refletidas na lista.
    _updateActiveTopicProgressFromControllers();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final activePlanProvider = Provider.of<ActivePlanProvider>(
      context,
      listen: false,
    );
    final planningProvider = Provider.of<PlanningProvider>(
      context,
      listen: false,
    ); // NOVO

    final record = StudyRecord(
      id: widget.initialRecord?.id ?? const Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: activePlanProvider.activePlan!.id,
      cycleId: planningProvider.currentCycleId, // NOVO
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      subject_id: _selectedSubject!.id,
      category: _selectedCategory!,
      study_time: _parseTime(_studyTimeController.text),
      topicsProgress:
          _currentTopicsProgress, // NOVO: Usar a lista de TopicProgress
      review_periods: _reviewPeriods,
      count_in_planning: _countInPlanning,
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );

    if (widget.initialRecord != null && widget.onUpdate != null) {
      widget.onUpdate!(record);
    } else {
      widget.onSave(record);
    }
    Navigator.of(context).pop();
  }

  // NOVO MÉTODO: Atualiza o TopicProgress ativo com os dados dos controladores de texto
  void _updateActiveTopicProgressFromControllers() {
    if (_currentTopicsProgress.isEmpty) return;

    final activeTp = _currentTopicsProgress[_activeTopicProgressIndex];

    final correct = int.tryParse(_activeTpCorrectQuestionsController.text) ?? 0;
    final incorrect =
        int.tryParse(_activeTpIncorrectQuestionsController.text) ?? 0;
    final totalQuestions = correct + incorrect;

    // Constrói a lista de páginas para salvar
    List<Map<String, int>> pagesToSave = [];
    final startPage = int.tryParse(_activeTpStartPageController.text) ?? 0;
    final endPage = int.tryParse(_activeTpEndPageController.text) ?? 0;
    if (startPage > 0 || endPage > 0) {
      // Somente adiciona se houver alguma informação
      pagesToSave.add({'start': startPage, 'end': endPage});
    }

    // NOVO: Atualiza a lista _activeTpVideos a partir dos controladores
    _activeTpVideos.clear();
    for (int i = 0; i < _activeTpVideoTitleControllers.length; i++) {
      _activeTpVideos.add({
        'title': _activeTpVideoTitleControllers[i].text,
        'start': _activeTpVideoStartControllers[i].text,
        'end': _activeTpVideoEndControllers[i].text,
      });
    }

    // Filtra vídeos vazios antes de salvar
    final videosToSave = _activeTpVideos
        .where(
          (v) =>
              v['title']!.trim().isNotEmpty ||
              v['start'] != '00:00:00' ||
              v['end'] != '00:00:00',
        )
        .toList();

    // Atualiza o TopicProgress ativo com os valores dos controladores
    _currentTopicsProgress[_activeTopicProgressIndex] = activeTp.copyWith(
      questions: {'total': totalQuestions, 'correct': correct},
      pages: pagesToSave,
      videos: videosToSave, // Salva a lista filtrada
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isTheoryFinished: _activeTpIsTeoriaFinalizada,
    );
  }

  void _handleDelete() {
    if (widget.initialRecord != null && widget.onDelete != null) {
      // NOVO: Descarte dos controladores de vídeo ao deletar
      for (var controller in _activeTpVideoTitleControllers) {
        controller.dispose();
      }
      for (var controller in _activeTpVideoStartControllers) {
        controller.dispose();
      }
      for (var controller in _activeTpVideoEndControllers) {
        controller.dispose();
      }
      _activeTpVideoTitleControllers.clear();
      _activeTpVideoStartControllers.clear();
      _activeTpVideoEndControllers.clear();

      widget.onDelete!();
      Navigator.of(context).pop();
    }
  }

  // NOVO MÉTODO: Adiciona um par de páginas ao TopicProgress ativo
  void _addPagePair() {
    // Não precisa de verificação de empty aqui, pois _currentTopicsProgress
    // sempre terá pelo menos um item se esta seção estiver visível
    setState(() {
      _activeTpPages.add({'start': 0, 'end': 0});
    });
    // Não chamar _updateActiveTopicProgressFromControllers aqui.
    // O salvamento real ocorre no _saveForm ou ao mudar de tópico.
  }

  // NOVO MÉTODO: Adiciona uma linha de vídeo ao TopicProgress ativo
  void _addVideoRow() {
    // Não precisa de verificação de empty aqui
    setState(() {
      _activeTpVideos.add({
        'title': '',
        'start': '00:00:00',
        'end': '00:00:00',
      });
      // NOVO: Adiciona controladores correspondentes
      _activeTpVideoTitleControllers.add(TextEditingController());
      _activeTpVideoStartControllers.add(
        TextEditingController(text: '00:00:00'),
      );
      _activeTpVideoEndControllers.add(TextEditingController(text: '00:00:00'));
    });
    // Não chamar _updateActiveTopicProgressFromControllers aqui.
  }

  void _showEditSubjectModal() {
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma disciplina selecionada para editar.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddSubjectModal(
        initialSubjectData: _selectedSubject,
        onSave: (subjectName, topics, color) async {
          final updatedSubject = Subject(
            id: _selectedSubject!.id,
            plan_id: _selectedSubject!.plan_id,
            subject: subjectName,
            topics: topics,
            color: color,
            lastModified: DateTime.now().millisecondsSinceEpoch,
          );
          final allSubjectsProvider = Provider.of<AllSubjectsProvider>(
            context,
            listen: false,
          );
          await allSubjectsProvider.updateSubject(updatedSubject);

          // Atualiza o estado local para refletir a mudança
          setState(() {
            _selectedSubject = updatedSubject;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showAddSubjectModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // Set background to white
      isScrollControlled: true,
      builder: (context) {
        return Theme(
          // Wrap content in a Theme
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surfaceTint: Colors.transparent, // Override surfaceTint
            ),
          ),
          child: Container(
            // Direct child of Theme
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: AddSubjectModal(
              onSave: (subjectName, topics, color) async {
                final newSubject = Subject(
                  id: const Uuid().v4(),
                  plan_id: widget.planId,
                  subject: subjectName,
                  topics: topics,
                  color: color,
                  lastModified: DateTime.now().millisecondsSinceEpoch,
                );
                final allSubjectsProvider = Provider.of<AllSubjectsProvider>(
                  context,
                  listen: false,
                );
                await allSubjectsProvider.addSubject(newSubject);
                setState(() {
                  _selectedSubject = newSubject;
                  _currentTopicsProgress =
                      []; // Reseta a lista de TopicProgress
                  _activeTopicProgressIndex = 0; // Reseta o índice
                });
                Navigator.pop(context); // Pop the modal sheet
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 768.0;

        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: MaterialStateProperty.all(Colors.teal),
            radius: const Radius.circular(10),
            thickness: MaterialStateProperty.all(8),
          ),
          child: Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: Colors.teal,
                secondary: Colors.teal,
              ),
              textSelectionTheme: theme.textSelectionTheme.copyWith(
                cursorColor: Colors.teal,
                selectionColor: Colors.teal.withOpacity(0.4),
                selectionHandleColor: Colors.teal,
              ),
            ),
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 768.0,
                      ), // Limita a largura em desktop
                      child: _buildModalContent(context, theme, isDesktop),
                    ),
                  )
                : _buildModalContent(context, theme, isDesktop),
          ),
        );
      },
    );
  }

  Widget _buildModalContent(
    BuildContext context,
    ThemeData theme,
    bool isDesktop,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialRecord == null
              ? 'Adicionar Registro'
              : 'Editar Registro',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.justification != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    border: Border(
                      left: BorderSide(
                        width: 4,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sugestão do Algoritmo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.justification!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDateField(theme, isDesktop)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildContentSelectors(theme, isDesktop),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildDateField(theme, isDesktop),
                        const SizedBox(height: 12),
                        _buildContentSelectors(theme, isDesktop),
                      ],
                    ),
              const SizedBox(height: 12),
              _buildTimeAndTopicSelectors(theme, isDesktop),
              const SizedBox(height: 16),
              // NOVO: Seletor de TopicProgress e campos de progresso associados
              _buildTopicProgressSelector(theme),
              _buildProgressFields(theme, isDesktop),
              _buildVideosFields(theme),
              const SizedBox(height: 16),
              _buildCheckboxes(),
              if (_isReviewSchedulingEnabled) _buildReviewPeriods(),
              const SizedBox(height: 16),
              _buildNotesField(theme),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomBar(context),
    );
  }

  // -----------------------------------------------------------------------
  // Métodos auxiliares de UI (todos estavam faltando ou incompletos)
  // -----------------------------------------------------------------------

  Widget _buildDateField(ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              flex: isDesktop ? 1 : 2, // Menor flex para desktop
              child: ElevatedButton(
                onPressed: () => setState(() => _selectedDate = DateTime.now()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hoje'),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              flex: isDesktop ? 1 : 2, // Menor flex para desktop
              child: ElevatedButton(
                onPressed: () => setState(
                  () => _selectedDate = DateTime.now().subtract(
                    const Duration(days: 1),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ontem'),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              flex: isDesktop ? 1 : 2, // Menor flex para desktop
              child: ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Outro'),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              flex: isDesktop ? 3 : 3, // Maior flex para desktop
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey[200]!
                            : Colors.black,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey[200]!
                            : Colors.black,
                        width: 2.0, // Make it slightly thicker when focused
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentSelectors(ThemeData theme, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            isExpanded: true,
            dropdownColor: theme.cardColor,
            items:
                {
                      'teoria': 'Teoria',
                      'revisao': 'Revisão',
                      'questoes': 'Questões',
                      'leitura_lei': 'Leitura de Lei',
                      'jurisprudencia': 'Jurisprudência',
                    }.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
            decoration: InputDecoration(
              labelText: 'Categoria',
              errorText: _errors['category'],
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface, // Use onSurface
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  // Make it const
                  color: Colors.teal, // Change this to Colors.teal
                  width: 2.0,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Consumer<AllSubjectsProvider>(
            builder: (context, allSubjectsProvider, child) {
              final subjects = allSubjectsProvider.subjects
                  .where((s) => s.plan_id == widget.planId)
                  .toList();

              return DropdownButtonFormField<Subject>(
                value: _selectedSubject,
                isExpanded: true,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: Colors.teal), // Add this
                decoration: InputDecoration(
                  labelText: 'Disciplina',
                  errorText: _errors['subject'],
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface, // Use onSurface
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.teal,
                      width: 2.0,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                selectedItemBuilder: (BuildContext context) {
                  return subjects.map<Widget>((Subject item) {
                    return Text(
                      item.subject,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                      ), // Revert to theme text color
                    );
                  }).toList();
                },
                items: subjects.map((s) {
                  return DropdownMenuItem<Subject>(
                    value: s,
                    child: Card(
                      color: Color(
                        int.parse(s.color.replaceFirst('#', '0xFF')),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          s.subject,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSubject = v;
                    _currentTopicsProgress =
                        []; // Reseta a lista de TopicProgress
                    _activeTopicProgressIndex = 0; // Reseta o índice
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: _showAddSubjectModal,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(0),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeAndTopicSelectors(ThemeData theme, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          flex: isDesktop ? 1 : 1, // Menor flex para desktop
          child: TextFormField(
            controller: _studyTimeController,
            decoration: InputDecoration(
              labelText: 'Tempo (HH:MM:SS)',
              errorText: _errors['studyTime'],
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.onSurface),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.teal, width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
            keyboardType: TextInputType.datetime,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
            ), // Add this
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: isDesktop ? 3 : 2, // Maior flex para desktop
          child: InkWell(
            onTap: _showTopicSelector,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Tópico(s)', // Alterado label
                errorText: _errors['topic'],
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.onSurface),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child:
                        _currentTopicsProgress
                            .isEmpty // Exibe a lista de tópicos
                        ? Text(
                            'Selecione um tópico',
                            style: TextStyle(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Wrap(
                            // Usa Wrap para exibir múltiplos tópicos como Chips
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _currentTopicsProgress
                                .map(
                                  (tp) => Chip(
                                    label: Text(tp.topicText),
                                    backgroundColor: Colors.teal.shade50,
                                    labelStyle: TextStyle(
                                      color: Colors.teal.shade800,
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ), // Make it const
                                    onDeleted: () {
                                      setState(() {
                                        // Remover o TopicProgress da lista e ajustar o índice ativo
                                        final removedIndex =
                                            _currentTopicsProgress.indexOf(tp);
                                        _currentTopicsProgress.remove(tp);
                                        if (removedIndex ==
                                            _activeTopicProgressIndex) {
                                          _activeTopicProgressIndex =
                                              (_currentTopicsProgress.isEmpty)
                                              ? 0
                                              : (_activeTopicProgressIndex - 1)
                                                    .clamp(
                                                      0,
                                                      _currentTopicsProgress
                                                              .length -
                                                          1,
                                                    );
                                          _loadActiveTopicProgressIntoControllers(); // Carrega os dados do novo tópico ativo
                                        } else if (removedIndex <
                                            _activeTopicProgressIndex) {
                                          _activeTopicProgressIndex--; // Ajusta o índice se o removido estava antes
                                        }

                                        if (_currentTopicsProgress.isEmpty) {
                                          _errors['topicsProgress'] =
                                              'Selecione pelo menos um tópico';
                                        } else {
                                          _errors.remove('topicsProgress');
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: _showEditSubjectModal,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(0),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  // NOVO WIDGET: Seletor de TopicProgress no modal
  Widget _buildTopicProgressSelector(ThemeData theme) {
    if (_currentTopicsProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progresso por Tópico:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48, // Altura fixa para o seletor
          child: ScrollbarTheme(
            // Tema para a Scrollbar
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.all(Colors.teal),
              radius: const Radius.circular(10),
              thickness: MaterialStateProperty.all(8),
              thumbVisibility: MaterialStateProperty.all(true),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              controller: _horizontalScrollController,
              child: ListView.builder(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _currentTopicsProgress.length,
                itemBuilder: (context, index) {
                  final tp = _currentTopicsProgress[index];
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(
                          tp.topicText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _activeTopicProgressIndex == index
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        selected: _activeTopicProgressIndex == index,
                        selectedColor: Colors.teal,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _updateActiveTopicProgressFromControllers();
                              _activeTopicProgressIndex = index;
                              _loadActiveTopicProgressIntoControllers();
                            });
                          }
                        },
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Editando: ${_currentTopicsProgress[_activeTopicProgressIndex].topicText}',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // NOVO MÉTODO: Carrega os dados do TopicProgress ativo nos controladores de texto.
  void _loadActiveTopicProgressIntoControllers() {
    if (_currentTopicsProgress.isEmpty) return;

    final activeTp = _currentTopicsProgress[_activeTopicProgressIndex];

    _activeTpCorrectQuestionsController.text =
        (activeTp.questions['correct'] ?? 0).toString();
    _activeTpIncorrectQuestionsController.text =
        ((activeTp.questions['total'] ?? 0) -
                (activeTp.questions['correct'] ?? 0))
            .toString();
    _activeTpStartPageController.text = activeTp.pages.isNotEmpty
        ? (activeTp.pages.first['start'] ?? 0).toString()
        : '0';
    _activeTpEndPageController.text = activeTp.pages.isNotEmpty
        ? (activeTp.pages.first['end'] ?? 0).toString()
        : '0';
    _activeTpPages = List.from(activeTp.pages);
    _activeTpVideos = List.from(
      activeTp.videos.isEmpty
          ? [
              {'title': '', 'start': '00:00:00', 'end': '00:00:00'},
            ]
          : activeTp.videos,
    );
    _activeTpIsTeoriaFinalizada = activeTp.isTheoryFinished;
    _notesController.text = activeTp.notes ?? '';

    // NOVO: Gerenciamento dos controladores de vídeo
    // 1. Limpa os controladores existentes
    for (var controller in _activeTpVideoTitleControllers) {
      controller.dispose();
    }
    for (var controller in _activeTpVideoStartControllers) {
      controller.dispose();
    }
    for (var controller in _activeTpVideoEndControllers) {
      controller.dispose();
    }
    _activeTpVideoTitleControllers.clear();
    _activeTpVideoStartControllers.clear();
    _activeTpVideoEndControllers.clear();

    // 2. Cria novos controladores para os vídeos do tópico ativo
    for (var video in _activeTpVideos) {
      _activeTpVideoTitleControllers.add(
        TextEditingController(text: video['title']),
      );
      _activeTpVideoStartControllers.add(
        TextEditingController(text: video['start']),
      );
      _activeTpVideoEndControllers.add(
        TextEditingController(text: video['end']),
      );
    }

    // Chamamos setState para garantir que a UI reflita as mudanças nos controladores.
    setState(() {});
  }

  Widget _buildProgressFields(ThemeData theme, bool isDesktop) {
    return Column(
      children: [
        _buildQuestionsSection(theme),
        const SizedBox(height: 16),
        _buildPagesSection(theme),
      ],
    );
  }

  Widget _buildQuestionsSection(ThemeData theme) {
    if (_currentTopicsProgress.isEmpty)
      return const SizedBox.shrink(); // Não exibe se não houver TopicProgress

    return Column(
      children: [
        const Text("Questões", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: _activeTpCorrectQuestionsController,
                    decoration: InputDecoration(
                      labelText: 'Acertos',
                      errorText:
                          _errors['topicProgress-$_activeTopicProgressIndex-questions'],
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (value) =>
                        _updateActiveTopicProgressFromControllers(), // Atualiza o TP ao mudar
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpCorrectQuestionsController.text,
                                ) ??
                                0;
                            if (cur > 0) {
                              _activeTpCorrectQuestionsController.text =
                                  (cur - 1).toString();
                              _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpCorrectQuestionsController.text,
                                ) ??
                                0;
                            _activeTpCorrectQuestionsController.text = (cur + 1)
                                .toString();
                            _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: _activeTpIncorrectQuestionsController,
                    decoration: InputDecoration(
                      labelText: 'Erros',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (value) =>
                        _updateActiveTopicProgressFromControllers(), // Atualiza o TP ao mudar
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpIncorrectQuestionsController.text,
                                ) ??
                                0;
                            if (cur > 0) {
                              _activeTpIncorrectQuestionsController.text =
                                  (cur - 1).toString();
                              _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpIncorrectQuestionsController.text,
                                ) ??
                                0;
                            _activeTpIncorrectQuestionsController.text =
                                (cur + 1).toString();
                            _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPagesSection(ThemeData theme) {
    if (_currentTopicsProgress.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const Text("Páginas", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: _activeTpStartPageController,
                    decoration: InputDecoration(
                      labelText: 'Início',
                      errorText:
                          _errors['topicProgress-$_activeTopicProgressIndex-page-0'], // Erro específico
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (value) =>
                        _updateActiveTopicProgressFromControllers(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpStartPageController.text,
                                ) ??
                                0;
                            if (cur > 0) {
                              _activeTpStartPageController.text = (cur - 1)
                                  .toString();
                              _updateActiveTopicProgressFromControllers();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(
                                  _activeTpStartPageController.text,
                                ) ??
                                0;
                            _activeTpStartPageController.text = (cur + 1)
                                .toString();
                            _updateActiveTopicProgressFromControllers();
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: _activeTpEndPageController,
                    decoration: InputDecoration(
                      labelText: 'Fim',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    onChanged: (value) =>
                        _updateActiveTopicProgressFromControllers(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(_activeTpEndPageController.text) ??
                                0;
                            if (cur > 0) {
                              _activeTpEndPageController.text = (cur - 1)
                                  .toString();
                              _updateActiveTopicProgressFromControllers();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.remove),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            final cur =
                                int.tryParse(_activeTpEndPageController.text) ??
                                0;
                            _activeTpEndPageController.text = (cur + 1)
                                .toString();
                            _updateActiveTopicProgressFromControllers();
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(0),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideosFields(ThemeData theme) {
    if (_currentTopicsProgress.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Vídeos/Aulas", style: TextStyle(fontSize: 16)),
        ..._activeTpVideoTitleControllers.asMap().entries.map((entry) {
          final idx = entry.key;
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller:
                        _activeTpVideoTitleControllers[idx], // USA CONTROLLER
                    decoration: InputDecoration(
                      labelText: 'Título',
                      errorText:
                          _errors['topicProgress-$_activeTopicProgressIndex-video-title-$idx'],
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (v) {
                      _updateActiveTopicProgressFromControllers();
                    },
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller:
                        _activeTpVideoStartControllers[idx], // USA CONTROLLER
                    decoration: InputDecoration(
                      labelText: 'Início',
                      errorText:
                          _errors['topicProgress-$_activeTopicProgressIndex-video-time-$idx'],
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    onChanged: (v) {
                      _updateActiveTopicProgressFromControllers();
                    },
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller:
                        _activeTpVideoEndControllers[idx], // USA CONTROLLER
                    decoration: InputDecoration(
                      labelText: 'Fim',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    keyboardType: TextInputType.datetime,
                    onChanged: (v) {
                      _updateActiveTopicProgressFromControllers();
                    },
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
                if (_activeTpVideoTitleControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () =>
                        _removeVideoRow(idx), // NOVO: Chama método de remoção
                  ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              onPressed: _addVideoRow,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  // NOVO MÉTODO: Remove uma linha de vídeo e seus controladores
  void _removeVideoRow(int index) {
    setState(() {
      // Remove os controladores e faz o dispose deles
      _activeTpVideoTitleControllers[index].dispose();
      _activeTpVideoStartControllers[index].dispose();
      _activeTpVideoEndControllers[index].dispose();

      _activeTpVideoTitleControllers.removeAt(index);
      _activeTpVideoStartControllers.removeAt(index);
      _activeTpVideoEndControllers.removeAt(index);

      // Remove os dados da lista de vídeos
      if (index < _activeTpVideos.length) {
        _activeTpVideos.removeAt(index);
      }

      _updateActiveTopicProgressFromControllers();
    });
  }

  Widget _buildNotesField(ThemeData theme) {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: 'Comentários',
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal, width: 2.0),
        ),
        alignLabelWithHint: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      maxLines: 4,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color), // Add this
    );
  }

  Widget _buildCheckboxes() {
    return Column(
      children: [
        if (_currentTopicsProgress
            .isNotEmpty) // Apenas exibe se houver um TopicProgress ativo
          Row(
            children: [
              Checkbox(
                value: _activeTpIsTeoriaFinalizada,
                onChanged: (v) => setState(() {
                  _activeTpIsTeoriaFinalizada = v!;
                  _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                }),
                activeColor: Colors.teal,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _activeTpIsTeoriaFinalizada = !_activeTpIsTeoriaFinalizada;
                    _updateActiveTopicProgressFromControllers(); // Atualiza o TP
                  }),
                  child: const Text('Teoria Finalizada'),
                ),
              ),
            ],
          ),
        Row(
          children: [
            Checkbox(
              value: _isReviewSchedulingEnabled,
              onChanged: (v) => setState(() => _isReviewSchedulingEnabled = v!),
              activeColor: Colors.teal,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(
                  () =>
                      _isReviewSchedulingEnabled = !_isReviewSchedulingEnabled,
                ),
                child: const Text('Programar Revisões'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: _countInPlanning,
              onChanged: (v) => setState(() => _countInPlanning = v!),
              activeColor: Colors.teal,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _countInPlanning = !_countInPlanning),
                child: Text(
                  'Contabilizar no Planejamento',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewPeriods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text("Revisões Programadas", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            ..._reviewPeriods.map(
              (p) => Chip(
                label: Text(p),
                onDeleted: () => setState(() => _reviewPeriods.remove(p)),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                'Adicionar',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: _showAddReviewDialog,
              backgroundColor: Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.initialRecord != null && widget.showDeleteButton)
            TextButton(
              onPressed: _handleDelete,
              child: const Text(
                'Excluir Registro',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveForm,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Topic? _findTopicById(List<Topic> topics, String id) {
    for (var topic in topics) {
      if (topic.id.toString() == id) {
        return topic;
      }
      if (topic.sub_topics != null) {
        final found = _findTopicById(topic.sub_topics!, id);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }
} // Fim da classe _StudyRegisterModalState

// Novo Widget para renderizar a árvore de tópicos
class _TopicTreeWidget extends StatelessWidget {
  final List<Topic> topics;
  final int level;
  final ValueChanged<Topic> onToggleTopicSelection; // Alterado
  final Set<Topic> selectedTopics; // Alterado

  const _TopicTreeWidget({
    required this.topics,
    required this.level,
    required this.onToggleTopicSelection, // Alterado
    required this.selectedTopics, // Alterado
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<Widget> items = [];
    for (var topic in topics) {
      final isGrouping =
          (topic.sub_topics?.isNotEmpty ?? false) ||
          (topic.is_grouping_topic ?? false);

      if (isGrouping) {
        items.add(
          Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: ExpansionTile(
              leading: const Icon(Icons.folder, color: Colors.teal),
              title: Text(
                topic.topic_text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              children: [
                _TopicTreeWidget(
                  topics: topic.sub_topics ?? [],
                  level: level + 1,
                  onToggleTopicSelection: onToggleTopicSelection, // Ajustado
                  selectedTopics: selectedTopics, // Ajustado
                ),
              ],
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: Colors.teal,
              collapsedIconColor: Colors.teal,
            ),
          ),
        );
      } else {
        items.add(
          Padding(
            padding: EdgeInsets.only(
              left: level * 16.0 + 4.0,
              right: 4.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: ListTile(
              leading: Checkbox(
                value: selectedTopics.contains(topic), // Ajustado
                onChanged: (bool? value) {
                  onToggleTopicSelection(topic); // Ajustado: apenas alterna
                },
                activeColor: Colors.teal,
              ),
              title: Text(
                topic.topic_text,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () =>
                  onToggleTopicSelection(topic), // Ajustado: apenas alterna
              selected: selectedTopics.contains(topic), // Ajustado
              selectedTileColor: Colors.teal.withOpacity(0.1),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
}

// Nova classe para o BottomSheet de seleção de tópico
class _TopicSelectionSheet extends StatefulWidget {
  final List<Topic> topics;
  final ScrollController scrollController;
  final ValueChanged<List<Topic>> onTopicsSelected; // Alterado para List<Topic>
  final List<String> initialSelectedTopicIds; // Alterado para lista de IDs

  const _TopicSelectionSheet({
    required this.topics,
    required this.scrollController,
    required this.onTopicsSelected,
    this.initialSelectedTopicIds = const [], // Default para lista vazia
  });

  @override
  State<_TopicSelectionSheet> createState() => _TopicSelectionSheetState();
}

class _TopicSelectionSheetState extends State<_TopicSelectionSheet> {
  final Set<Topic> _selectedTopics = {}; // Set para multi-seleção

  @override
  void initState() {
    super.initState();
    // Inicializa o Set com os IDs dos tópicos pré-selecionados
    for (String id in widget.initialSelectedTopicIds) {
      final topic = _findTopicById(widget.topics, id);
      if (topic != null) {
        _selectedTopics.add(topic);
      }
    }
  }

  // Função auxiliar para encontrar um tópico pelo ID em uma lista hierárquica
  Topic? _findTopicById(List<Topic> topics, String id) {
    for (var topic in topics) {
      if (topic.id.toString() == id) {
        // Comparar como String
        return topic;
      }
      if (topic.sub_topics != null) {
        final found = _findTopicById(topic.sub_topics!, id);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  void _toggleTopicSelection(Topic topic) {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        _selectedTopics.add(topic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Selecione os Tópicos',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onTopicsSelected(
                _selectedTopics.toList(),
              ); // Retorna a lista de tópicos selecionados
            },
            child: Text(
              'Confirmar (${_selectedTopics.length})',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.teal),
          radius: const Radius.circular(10),
          thickness: MaterialStateProperty.all(8),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          controller: widget.scrollController,
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(right: 16.0),
            children: [
              _TopicTreeWidget(
                topics: widget.topics,
                level: 0,
                onToggleTopicSelection:
                    _toggleTopicSelection, // Passa o callback de toggle
                selectedTopics:
                    _selectedTopics, // Passa o Set de tópicos selecionados
              ),
            ],
          ),
        ),
      ),
    );
  }
}
