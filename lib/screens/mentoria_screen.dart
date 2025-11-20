import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MentoriaProvider with ChangeNotifier {
  // General
  bool _sequentialTopics = false;

  // Performance
  bool _useHitRate = true;
  bool _prioritizeLessStudiedTime = false;
  bool _prioritizeMoreStudiedTime = false;
  bool _prioritizeMostErrors = false;
  bool _prioritizeLeastQuestions = false;

  // Review
  bool _prioritizePendingReviews = false;
  bool _prioritizeMostReviewed = false;

  // Temporality
  bool _prioritizeRecentlyAdded = false;
  bool _prioritizeNotStudiedInTimeWindow = false;
  int _notStudiedInDays = 7;

  // Manual
  // Presets will be implemented later

  // Getters
  bool get sequentialTopics => _sequentialTopics;
  bool get useHitRate => _useHitRate;
  bool get prioritizeLessStudiedTime => _prioritizeLessStudiedTime;
  bool get prioritizeMoreStudiedTime => _prioritizeMoreStudiedTime;
  bool get prioritizeMostErrors => _prioritizeMostErrors;
  bool get prioritizeLeastQuestions => _prioritizeLeastQuestions;
  bool get prioritizePendingReviews => _prioritizePendingReviews;
  bool get prioritizeMostReviewed => _prioritizeMostReviewed;
  bool get prioritizeRecentlyAdded => _prioritizeRecentlyAdded;
  bool get prioritizeNotStudiedInTimeWindow => _prioritizeNotStudiedInTimeWindow;
  int get notStudiedInDays => _notStudiedInDays;

  MentoriaProvider() {
    _loadPreferences();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _sequentialTopics = prefs.getBool('sequentialTopics') ?? true;
    _useHitRate = prefs.getBool('useHitRate') ?? false;
    _prioritizeLessStudiedTime = prefs.getBool('prioritizeLessStudiedTime') ?? false;
    _prioritizeMoreStudiedTime = prefs.getBool('prioritizeMoreStudiedTime') ?? false;
    _prioritizeMostErrors = prefs.getBool('prioritizeMostErrors') ?? false;
    _prioritizeLeastQuestions = prefs.getBool('prioritizeLeastQuestions') ?? false;
    _prioritizePendingReviews = prefs.getBool('prioritizePendingReviews') ?? false;
    _prioritizeMostReviewed = prefs.getBool('prioritizeMostReviewed') ?? false;
    _prioritizeRecentlyAdded = prefs.getBool('prioritizeRecentlyAdded') ?? false;
    _prioritizeNotStudiedInTimeWindow = prefs.getBool('prioritizeNotStudiedInTimeWindow') ?? false;
    _notStudiedInDays = prefs.getInt('notStudiedInDays') ?? 7;
    notifyListeners();
  }

  // Setters
  void setSequentialTopics(bool value) async {
    _sequentialTopics = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sequentialTopics', value);
    notifyListeners();
  }

  void setUseHitRate(bool value) async {
    _useHitRate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useHitRate', value);
    notifyListeners();
  }

  void setPrioritizeLessStudiedTime(bool value) async {
    _prioritizeLessStudiedTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeLessStudiedTime', value);
    notifyListeners();
  }

  void setPrioritizeMoreStudiedTime(bool value) async {
    _prioritizeMoreStudiedTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMoreStudiedTime', value);
    notifyListeners();
  }

  void setPrioritizeMostErrors(bool value) async {
    _prioritizeMostErrors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMostErrors', value);
    notifyListeners();
  }

  void setPrioritizeLeastQuestions(bool value) async {
    _prioritizeLeastQuestions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeLeastQuestions', value);
    notifyListeners();
  }

  void setPrioritizePendingReviews(bool value) async {
    _prioritizePendingReviews = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizePendingReviews', value);
    notifyListeners();
  }

  void setPrioritizeMostReviewed(bool value) async {
    _prioritizeMostReviewed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMostReviewed', value);
    notifyListeners();
  }

  void setPrioritizeRecentlyAdded(bool value) async {
    _prioritizeRecentlyAdded = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeRecentlyAdded', value);
    notifyListeners();
  }

  void setPrioritizeNotStudiedInTimeWindow(bool value) async {
    _prioritizeNotStudiedInTimeWindow = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeNotStudiedInTimeWindow', value);
    notifyListeners();
  }

  void setNotStudiedInDays(int value) async {
    _notStudiedInDays = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notStudiedInDays', value);
    notifyListeners();
  }
}

class MentoriaScreen extends StatelessWidget {
  const MentoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<MentoriaProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Recomendar tópicos em ordem sequencial'),
                subtitle: const Text('Ideal para quem está começando em uma matéria e prefere seguir a ordem do edital.'),
                value: provider.sequentialTopics,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: (value) {
                  provider.setSequentialTopics(value);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Critérios de Desempenho',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Taxa de Acertos'),
                subtitle: const Text('Prioriza tópicos com menor percentual de acertos.'),
                value: provider.useHitRate,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setUseHitRate(value),
              ),
              SwitchListTile(
                title: const Text('Menos tempo estudado'),
                subtitle: const Text('Prioriza tópicos com menor tempo de estudo acumulado.'),
                value: provider.prioritizeLessStudiedTime,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeLessStudiedTime(value),
              ),
              SwitchListTile(
                title: const Text('Mais tempo estudado'),
                subtitle: const Text('Prioriza tópicos com maior tempo de estudo acumulado.'),
                value: provider.prioritizeMoreStudiedTime,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeMoreStudiedTime(value),
              ),
              SwitchListTile(
                title: const Text('Maior número de erros'),
                subtitle: const Text('Prioriza tópicos com maior quantidade de erros em questões.'),
                value: provider.prioritizeMostErrors,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeMostErrors(value),
              ),
              SwitchListTile(
                title: const Text('Menor quantidade de questões feitas'),
                subtitle: const Text('Prioriza tópicos com poucas questões respondidas.'),
                value: provider.prioritizeLeastQuestions,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeLeastQuestions(value),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Critérios de Revisão',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Revisões Pendentes'),
                subtitle: const Text('Prioriza tópicos com revisões próximas ou atrasadas.'),
                value: provider.prioritizePendingReviews,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizePendingReviews(value),
              ),
              SwitchListTile(
                title: const Text('Tópicos Mais Revisados'),
                subtitle: const Text('Prioriza tópicos que foram mais revisados.'),
                value: provider.prioritizeMostReviewed,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeMostReviewed(value),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Critérios de Temporalidade',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Adicionados Recentemente'),
                subtitle: const Text('Prioriza tópicos novos no plano de estudos.'),
                value: provider.prioritizeRecentlyAdded,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeRecentlyAdded(value),
              ),
              SwitchListTile(
                title: const Text('Não estudados há um tempo'),
                subtitle: const Text('Prioriza tópicos não estudados em um período específico.'),
                value: provider.prioritizeNotStudiedInTimeWindow,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics ? null : (value) => provider.setPrioritizeNotStudiedInTimeWindow(value),
              ),
              if (provider.prioritizeNotStudiedInTimeWindow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Período (dias):'),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Slider(
                          value: provider.notStudiedInDays.toDouble(),
                          min: 1,
                          max: 90,
                          divisions: 89,
                          label: provider.notStudiedInDays.toString(),
                          activeColor: Theme.of(context).colorScheme.primary,
                          // Slider NÃO tem inactiveThumbColor ou inactiveTrackColor
                          inactiveColor: Colors.grey[300], // Cor da trilha quando inativo
                          onChanged: provider.sequentialTopics ? null : (value) => provider.setNotStudiedInDays(value.toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}