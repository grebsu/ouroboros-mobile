import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/simulado_record.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/simulados_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:uuid/uuid.dart';

class ListenableBuilder extends AnimatedWidget {
  final Listenable listenable;
  final Widget Function(BuildContext) builder;

  const ListenableBuilder({
    Key? key,
    required this.listenable,
    required this.builder,
  }) : super(key: key, listenable: listenable);

  @override
  Widget build(BuildContext context) {
    return builder(context);
  }
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
  late List<SimuladoSubject> _subjects;

  @override
  void initState() {
    super.initState();

    if (widget.simulado != null) {
      final s = widget.simulado!;
      _name = s.name;
      _date = s.date;
      _style = s.style;
      _banca = s.banca;
      _timeSpent = s.timeSpent;
      _comments = s.comments;
      _subjects = s.subjects
          .map((sub) => SimuladoSubject(
        name: sub.name,
        weight: sub.weight.value,
        totalQuestions: sub.totalQuestions.value,
        correct: sub.correct.value,
        incorrect: sub.incorrect.value,
        color: sub.color,
      ))
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
        final activePlanId =
            Provider.of<ActivePlanProvider>(context, listen: false).activePlan?.id;
        if (activePlanId != null) {
          final allSubjects =
              Provider.of<AllSubjectsProvider>(context, listen: false).subjects;
          final planSubjects =
          allSubjects.where((s) => s.plan_id == activePlanId).toList();

          setState(() {
            _subjects = planSubjects
                .map((sub) => SimuladoSubject(
              name: sub.subject,
              weight: 1,
              totalQuestions: 10, // Alterado de 0 para 10
              correct: 0,
              incorrect: 0,
              color: sub.color,
            ))
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.simulado == null ? 'Adicionar Simulado' : 'Editar Simulado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
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
                          text: DateFormat('dd/MM/yyyy').format(_date)),
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
                          .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
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
              const Text('Matérias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              ? Colors.grey.shade800 // Cor do cabeçalho no modo escuro
              : Colors.grey.shade200, // Cor do cabeçalho no modo claro
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white // Cor do texto do cabeçalho no modo escuro
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
          label: Center(child: Padding(padding: EdgeInsets.only(left: 14.0), child: Text('Peso')))),
      const DataColumn(
          label: Center(child: Padding(padding: EdgeInsets.only(left: 14.0), child: Icon(Icons.edit)))),
      const DataColumn(
          label: Center(child: Padding(padding: EdgeInsets.only(left: 14.0), child: Icon(Icons.check_circle, color: Colors.green)))),
      const DataColumn(
          label: Center(child: Padding(padding: EdgeInsets.only(left: 14.0), child: Icon(Icons.cancel, color: Colors.red)))),
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
      final subject = entry.value;

      final rowColor = Theme.of(context).brightness == Brightness.dark
          ? (index.isOdd ? Colors.grey.shade900 : Colors.grey.shade800) // Cores para o modo escuro
          : (index.isOdd ? Colors.grey.withOpacity(0.05) : Colors.transparent); // Cores para o modo claro

      final borderColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade700 // Cor da borda no modo escuro
          : Colors.grey.shade300; // Cor da borda no modo claro

      final cells = <DataCell>[
        // Matéria com cor
        DataCell(Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          width: isLandscape ? 220 : 150, // Largura condicional para a coluna da matéria
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: Color(int.parse(subject.color.substring(1, 7), radix: 16) + 0xFF000000),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject.name,
                  softWrap: true,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        )),

        // Peso
        DataCell(Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Center(
            child: NumberField<num>(
              notifier: subject.weight,
              onDecrease: () => subject.weight.value = (subject.weight.value - 1).clamp(0, double.infinity),
              onIncrease: () => subject.weight.value = (subject.weight.value + 1).clamp(0, double.infinity),
              onChanged: (v) => subject.weight.value = num.tryParse(v) ?? 1,
              width: 100,
            ),
          ),
        )),

        // Total de Questões
        DataCell(Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Center(
            child: NumberField<int>(
              notifier: subject.totalQuestions,
              onDecrease: () => subject.totalQuestions.value = (subject.totalQuestions.value - 1).clamp(0, 999),
              onIncrease: () => subject.totalQuestions.value = (subject.totalQuestions.value + 1).clamp(0, 999),
              onChanged: (v) => subject.totalQuestions.value = int.tryParse(v) ?? 0,
              width: 100,
              isInt: true,
            ),
          ),
        )),

        // Corretas
        DataCell(Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Center(
            child: NumberField<int>(
              notifier: subject.correct,
              onDecrease: () => subject.correct.value = (subject.correct.value - 1).clamp(0, 999),
              onIncrease: () {
                if (subject.correct.value + subject.incorrect.value < subject.totalQuestions.value) {
                  subject.correct.value = (subject.correct.value + 1).clamp(0, 999);
                }
              },
              onChanged: (v) {
                final value = int.tryParse(v) ?? 0;
                if (value + subject.incorrect.value <= subject.totalQuestions.value) {
                  subject.correct.value = value;
                }
              },
              width: 100,
              isInt: true,
            ),
          ),
        )),

        // Incorretas
        DataCell(Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Center(
            child: NumberField<int>(
              notifier: subject.incorrect,
              onDecrease: () => subject.incorrect.value = (subject.incorrect.value - 1).clamp(0, 999),
              onIncrease: () {
                if (subject.correct.value + subject.incorrect.value < subject.totalQuestions.value) {
                  subject.incorrect.value = (subject.incorrect.value + 1).clamp(0, 999);
                }
              },
              onChanged: (v) {
                final value = int.tryParse(v) ?? 0;
                if (value + subject.correct.value <= subject.totalQuestions.value) {
                  subject.incorrect.value = value;
                }
              },
              width: 100,
              isInt: true,
            ),
          ),
        )),
      ];

      if (isLandscape) {
        cells.addAll([
          DataCell(Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([subject.totalQuestions, subject.correct, subject.incorrect]),
              builder: (context) {
                final blank = subject.totalQuestions.value - subject.correct.value - subject.incorrect.value;
                return Center(child: Text(blank.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
              },
            ),
          )),
          DataCell(Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([subject.correct, subject.weight]),
              builder: (context) {
                final points = subject.correct.value * subject.weight.value;
                return Center(child: Text(points.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)));
              },
            ),
          )),
          DataCell(Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([subject.correct, subject.totalQuestions]),
              builder: (context) {
                final performance = subject.totalQuestions.value > 0
                    ? (subject.correct.value / subject.totalQuestions.value * 100).toStringAsFixed(1)
                    : '0.0';
                return Center(child: Text('$performance%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)));
              },
            ),
          )),
        ]);
      }

      cells.add(DataCell(Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
        ),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => setState(() => _subjects.remove(subject)),
        ),
      )));

      return DataRow(
        color: MaterialStateProperty.resolveWith((states) => rowColor),
        cells: cells,
      );
    }).toList();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final simulado = SimuladoRecord(
        id: widget.simulado?.id ?? const Uuid().v4(),
        name: _name,
        date: _date,
        style: _style,
        banca: _banca,
        timeSpent: _timeSpent,
        comments: _comments,
        subjects: _subjects.map((s) => SimuladoSubject(
          name: s.name,
          weight: s.weight.value,
          totalQuestions: s.totalQuestions.value,
          correct: s.correct.value,
          incorrect: s.incorrect.value,
          color: s.color,
        )).toList(),
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
          contentPadding: const EdgeInsets.only(left: 8, right: 4, top: 8, bottom: 8),
          suffixIcon: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12.0), bottomLeft: Radius.circular(12.0)),
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