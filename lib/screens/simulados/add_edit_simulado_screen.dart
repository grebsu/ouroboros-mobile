import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Explicitly import foundation for ValueNotifier
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/models/data_models.dart'; // For SimuladoRecord and SimuladoSubject
import 'package:ouroboros_mobile/providers/active_plan_provider.dart'; // For ActivePlanProvider
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart'; // For AllSubjectsProvider
import 'package:ouroboros_mobile/providers/simulados_provider.dart'; // For SimuladosProvider
import 'package:ouroboros_mobile/providers/auth_provider.dart'; // For AuthProvider

// Classe auxiliar para gerenciar o estado da UI de cada matéria do simulado
class _SimuladoSubjectUI {
  String? id; // ID do SimuladoSubject do banco de dados (se for edição)
  String name;
  ValueNotifier<num> weight;
  ValueNotifier<int> totalQuestions;
  ValueNotifier<int> correct;
  ValueNotifier<int> incorrect;
  String color;

  _SimuladoSubjectUI({
    this.id,
    required this.name,
    num weight = 1,
    required int totalQuestions,
    required int correct,
    required int incorrect,
    this.color = '#000000',
  }) : this.weight = ValueNotifier(weight),
       this.totalQuestions = ValueNotifier(totalQuestions),
       this.correct = ValueNotifier(correct),
       this.incorrect = ValueNotifier(incorrect);
}

class AddEditSimuladoScreen extends StatefulWidget {
  final SimuladoRecord? simulado;

  const AddEditSimuladoScreen({Key? key, this.simulado}) : super(key: key);

  @override
  _AddEditSimuladoScreenState createState() => _AddEditSimuladoScreenState();
}

class _AddEditSimuladoScreenState extends State<AddEditSimuladoScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late DateTime _date;
  late String _style;
  late String _banca;
  late String _timeSpent;
  late String _comments;
  late List<_SimuladoSubjectUI> _subjects;

  @override
  void initState() {
    super.initState();

    if (widget.simulado != null) {
      final s = widget.simulado!;
      _name = s.name;
      _date = DateTime.parse(s.date); // Convert String date to DateTime
      _style = s.style ?? 'Múltipla Escolha';
      _banca = s.banca ?? '';
      _timeSpent = s.time_spent ?? '00:00:00';
      _comments = s.comments ?? '';
      _subjects = s.subjects
          .map(
            (sub) => _SimuladoSubjectUI(
              id: sub.id?.toString(), // Use o ID do sub, se existir
              name: sub.subject_name,
              weight: sub.weight,
              totalQuestions: sub.total_questions,
              correct: sub.correct,
              incorrect: sub.incorrect,
              color: sub.color,
            ),
          )
          .toList();
    } else {
      _name = '';
      _date = DateTime.now();
      _style = 'Múltipla Escolha';
      _banca = '';
      _timeSpent = '00:00:00';
      _comments = '';
      _subjects = [];

      // Carrega matérias do plano ativo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activePlanId = Provider.of<ActivePlanProvider>(
          context,
          listen: false,
        ).activePlan?.id;
        if (activePlanId != null) {
          final allSubjects = Provider.of<AllSubjectsProvider>(
            context,
            listen: false,
          ).subjects;
          final planSubjects = allSubjects
              .where((s) => s.plan_id == activePlanId)
              .toList();

          setState(() {
            _subjects = planSubjects
                .map(
                  (sub) => _SimuladoSubjectUI(
                    name: sub.subject,
                    weight: 1,
                    totalQuestions: 10, // Alterado de 0 para 10
                    correct: 0,
                    incorrect: 0,
                    color: sub.color,
                  ),
                )
                .toList();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.simulado == null ? 'Adicionar Simulado' : 'Editar Simulado',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Linha 1: Data, Tempo, Banca
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('dd/MM/yyyy').format(_date),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Tempo Gasto',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _timeSpent,
                      onSaved: (value) => _timeSpent = value ?? '00:00:00',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Banca',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _banca,
                      onSaved: (value) => _banca = value ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Linha 2: Nome e Estilo
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Nome do Simulado',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _name,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um nome';
                        }
                        return null;
                      },
                      onSaved: (value) => _name = value!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _style,
                      decoration: const InputDecoration(
                        labelText: 'Estilo de Prova',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Múltipla Escolha', 'Certo/Errado']
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _style = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tabela de Matérias
              const Text(
                'Matérias',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildSubjectsTable(isLandscape),
              const SizedBox(height: 20),

              // Comentários
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Comentários',
                  border: OutlineInputBorder(),
                ),
                initialValue: _comments,
                maxLines: 3,
                onSaved: (value) => _comments = value ?? '',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsTable(bool isLandscape) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.resolveWith(
          (states) => Theme.of(context).brightness == Brightness.dark
              ? Colors
                    .grey
                    .shade800 // Cor do cabeçalho no modo escuro
              : Colors.grey.shade200, // Cor do cabeçalho no modo claro
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors
                    .white // Cor do texto do cabeçalho no modo escuro
              : Colors.black, // Cor do texto do cabeçalho no modo claro
        ),
        dataRowHeight: 70.0,
        columnSpacing: 8.0, // Reduzido de 20.0 para 8.0
        columns: _buildColumns(isLandscape),
        rows: _buildRows(isLandscape),
      ),
    );
  }

  List<DataColumn> _buildColumns(bool isLandscape) {
    final columns = [
      const DataColumn(label: Text('Matéria')),
      const DataColumn(
        label: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14.0),
            child: Text('Peso'),
          ),
        ),
      ),
      const DataColumn(
        label: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14.0),
            child: Icon(Icons.edit),
          ),
        ),
      ),
      const DataColumn(
        label: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14.0),
            child: Icon(Icons.check_circle, color: Colors.green),
          ),
        ),
      ),
      const DataColumn(
        label: Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14.0),
            child: Icon(Icons.cancel, color: Colors.red),
          ),
        ),
      ),
    ];

    if (isLandscape) {
      columns.addAll([
        const DataColumn(label: Icon(Icons.remove_circle, color: Colors.grey)),
        const DataColumn(label: Icon(Icons.star, color: Colors.amber)),
        const DataColumn(label: Icon(Icons.percent, color: Colors.blue)),
      ]);
    }

    columns.add(const DataColumn(label: Text('Ação')));
    return columns;
  }

  List<DataRow> _buildRows(bool isLandscape) {
    return _subjects.asMap().entries.map((entry) {
      final index = entry.key;
      final _SimuladoSubjectUI subjectUI = entry.value;

      final rowColor = Theme.of(context).brightness == Brightness.dark
          ? (index.isOdd
                ? Colors.grey.shade900
                : Colors.grey.shade800) // Cores para o modo escuro
          : (index.isOdd
                ? Colors.grey.withOpacity(0.05)
                : Colors.transparent); // Cores para o modo claro

      final borderColor = Theme.of(context).brightness == Brightness.dark
          ? Colors
                .grey
                .shade700 // Cor da borda no modo escuro
          : Colors.grey.shade300; // Cor da borda no modo claro

      final cells = <DataCell>[
        // Matéria com cor
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            width: isLandscape
                ? 220
                : 150, // Largura condicional para a coluna da matéria
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: Color(
                    int.parse(subjectUI.color.substring(1, 7), radix: 16) +
                        0xFF000000,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subjectUI.name,
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Peso
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: Center(
              child: NumberField<num>(
                notifier: subjectUI.weight,
                onDecrease: () => subjectUI.weight.value =
                    (subjectUI.weight.value - 1).clamp(0, double.infinity),
                onIncrease: () => subjectUI.weight.value =
                    (subjectUI.weight.value + 1).clamp(0, double.infinity),
                onChanged: (v) => subjectUI.weight.value = num.tryParse(v) ?? 1,
                width: 100,
              ),
            ),
          ),
        ),

        // Total de Questões
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: Center(
              child: NumberField<int>(
                notifier: subjectUI.totalQuestions,
                onDecrease: () => subjectUI.totalQuestions.value =
                    (subjectUI.totalQuestions.value - 1).clamp(0, 999),
                onIncrease: () => subjectUI.totalQuestions.value =
                    (subjectUI.totalQuestions.value + 1).clamp(0, 999),
                onChanged: (v) =>
                    subjectUI.totalQuestions.value = int.tryParse(v) ?? 0,
                width: 100,
                isInt: true,
              ),
            ),
          ),
        ),

        // Corretas
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: Center(
              child: NumberField<int>(
                notifier: subjectUI.correct,
                onDecrease: () => subjectUI.correct.value =
                    (subjectUI.correct.value - 1).clamp(0, 999),
                onIncrease: () {
                  if (subjectUI.correct.value + subjectUI.incorrect.value <
                      subjectUI.totalQuestions.value) {
                    subjectUI.correct.value = (subjectUI.correct.value + 1)
                        .clamp(0, 999);
                  }
                },
                onChanged: (v) {
                  final value = int.tryParse(v) ?? 0;
                  if (value + subjectUI.incorrect.value <=
                      subjectUI.totalQuestions.value) {
                    subjectUI.correct.value = value;
                  }
                },
                width: 100,
                isInt: true,
              ),
            ),
          ),
        ),

        // Incorretas
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: Center(
              child: NumberField<int>(
                notifier: subjectUI.incorrect,
                onDecrease: () => subjectUI.incorrect.value =
                    (subjectUI.incorrect.value - 1).clamp(0, 999),
                onIncrease: () {
                  if (subjectUI.correct.value + subjectUI.incorrect.value <
                      subjectUI.totalQuestions.value) {
                    subjectUI.incorrect.value = (subjectUI.incorrect.value + 1)
                        .clamp(0, 999);
                  }
                },
                onChanged: (v) {
                  final value = int.tryParse(v) ?? 0;
                  if (value + subjectUI.correct.value <=
                      subjectUI.totalQuestions.value) {
                    subjectUI.incorrect.value = value;
                  }
                },
                width: 100,
                isInt: true,
              ),
            ),
          ),
        ),
      ];

      if (isLandscape) {
        cells.addAll([
          DataCell(
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  subjectUI.totalQuestions,
                  subjectUI.correct,
                  subjectUI.incorrect,
                ]),
                builder: (context, child) {
                  final blank =
                      subjectUI.totalQuestions.value -
                      subjectUI.correct.value -
                      subjectUI.incorrect.value;
                  return Center(
                    child: Text(
                      blank.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          DataCell(
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  subjectUI.correct,
                  subjectUI.weight,
                ]),
                builder: (context, child) {
                  final points =
                      subjectUI.correct.value * subjectUI.weight.value;
                  return Center(
                    child: Text(
                      points.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          DataCell(
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.0),
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  subjectUI.correct,
                  subjectUI.totalQuestions,
                ]),
                builder: (context, child) {
                  final performance = subjectUI.totalQuestions.value > 0
                      ? (subjectUI.correct.value /
                                subjectUI.totalQuestions.value *
                                100)
                            .toStringAsFixed(1)
                      : '0.0';
                  return Center(
                    child: Text(
                      '$performance%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]);
      }

      cells.add(
        DataCell(
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => setState(() => _subjects.remove(subjectUI)),
            ),
          ),
        ),
      );

      return DataRow(
        color: MaterialStateProperty.resolveWith((states) => rowColor),
        cells: cells,
      );
    }).toList();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final activePlanId = Provider.of<ActivePlanProvider>(
        context,
        listen: false,
      ).activePlan?.id;
      final simulado = SimuladoRecord(
        id: widget.simulado?.id ?? const Uuid().v4(),
        userId: authProvider.currentUser!.name,
        plan_id: activePlanId!,
        name: _name,
        date: DateFormat('yyyy-MM-dd').format(_date),
        style: _style == 'Múltipla Escolha'
            ? 'multipla_escolha'
            : 'certo_errado',
        banca: _banca,
        time_spent: _timeSpent,
        comments: _comments,
        subjects: _subjects
            .map(
              (s) => SimuladoSubject(
                id: s.id != null
                    ? int.tryParse(s.id!)
                    : null, // Manter ID se existir
                simulado_record_id:
                    widget.simulado?.id ??
                    const Uuid().v4(), // Será preenchido pelo banco de dados
                subject_id:
                    s.id ??
                    const Uuid().v4(), // Usar o ID da UI como subject_id
                subject_name: s.name,
                weight: s.weight.value.toDouble(),
                total_questions: s.totalQuestions.value,
                correct: s.correct.value,
                incorrect: s.incorrect.value,
                color: s.color,
                lastModified: DateTime.now().millisecondsSinceEpoch,
              ),
            )
            .toList(),
        lastModified: DateTime.now().millisecondsSinceEpoch,
      );

      final provider = Provider.of<SimuladosProvider>(context, listen: false);
      if (widget.simulado == null) {
        provider.addSimulado(simulado);
      } else {
        provider.updateSimulado(simulado);
      }

      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _date) {
      setState(() {
        _date = pickedDate;
      });
    }
  }
}

class NumberField<T extends num> extends StatefulWidget {
  final ValueNotifier<T> notifier;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final Function(String) onChanged;
  final double width;
  final bool isInt;

  const NumberField({
    Key? key,
    required this.notifier,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
    required this.width,
    this.isInt = false,
  }) : super(key: key);

  @override
  _NumberFieldState<T> createState() => _NumberFieldState<T>();
}

class _NumberFieldState<T extends num> extends State<NumberField<T>> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.notifier.value.toString());
    widget.notifier.addListener(_updateText);
  }

  @override
  void didUpdateWidget(NumberField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notifier != oldWidget.notifier) {
      oldWidget.notifier.removeListener(_updateText);
      widget.notifier.addListener(_updateText);
      _controller.text = widget.notifier.value.toString();
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_updateText);
    _controller.dispose();
    super.dispose();
  }

  void _updateText() {
    final newText = widget.notifier.value.toString();
    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextFormField(
        controller: _controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(
            left: 8,
            right: 4,
            top: 8,
            bottom: 8,
          ),
          suffixIcon: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12.0),
              bottomLeft: Radius.circular(12.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: widget.onIncrease,
                    mini: true,
                    backgroundColor: Colors.teal,
                    shape: const RoundedRectangleBorder(),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: widget.onDecrease,
                    mini: true,
                    backgroundColor: Colors.teal.shade200,
                    shape: const RoundedRectangleBorder(),
                    child: const Icon(Icons.remove, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
