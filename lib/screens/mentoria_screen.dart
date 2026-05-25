import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/mentoria_provider.dart';

class MentoriaScreen extends StatelessWidget {
  const MentoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações da Mentoria'),
      ),
      body: Consumer<MentoriaProvider>(
        builder: (context, provider, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Recomendar tópicos em ordem sequencial'),
                subtitle: const Text(
                  'Ideal para quem está começando em uma matéria e prefere seguir a ordem do edital.',
                ),
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
                  'Critérios de Recomendação Avançados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Habilitar recomendação de múltiplos tópicos'),
                subtitle: const Text(
                  'Permite que o algoritmo sugira mais de um tópico por sessão, dividindo o tempo de estudo.',
                ),
                value: provider.multiTopicRecommendationEnabled,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setMultiTopicRecommendationEnabled(value),
              ),
              if (provider.multiTopicRecommendationEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Máximo de tópicos por sessão:'),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Slider(
                          value: provider.maxTopicsPerSession.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: provider.maxTopicsPerSession.toString(),
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: Colors.grey[300],
                          onChanged: provider.sequentialTopics
                              ? null
                              : (value) =>
                                  provider.setMaxTopicsPerSession(value.toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Text('Estratégia de alocação de tempo:'),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: provider.timeAllocationStrategy,
                          items: const [
                            DropdownMenuItem(
                              value: 'proportional',
                              child: Text('Proporcional à Pontuação'),
                            ),
                            DropdownMenuItem(
                              value: 'equal',
                              child: Text('Divisão Igual'),
                            ),
                          ],
                          onChanged: provider.sequentialTopics
                              ? null
                              : (value) =>
                                  provider.setTimeAllocationStrategy(value!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SwitchListTile(
                title: const Text('Progressão automática para próxima matéria'),
                subtitle: const Text(
                  'Quando todos os tópicos da sessão atual forem concluídos, o cronômetro avançará automaticamente para a próxima matéria.',
                ),
                value: provider.automaticProgressionToNextSubject,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setAutomaticProgressionToNextSubject(value),
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
                subtitle: const Text(
                  'Prioriza tópicos com menor percentual de acertos.',
                ),
                value: provider.useHitRate,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setUseHitRate(value),
              ),
              SwitchListTile(
                title: const Text('Menos tempo estudado'),
                subtitle: const Text(
                  'Prioriza tópicos com menor tempo de estudo acumulado.',
                ),
                value: provider.prioritizeLessStudiedTime,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeLessStudiedTime(value),
              ),
              SwitchListTile(
                title: const Text('Mais tempo estudado'),
                subtitle: const Text(
                  'Prioriza tópicos com maior tempo de estudo acumulado.',
                ),
                value: provider.prioritizeMoreStudiedTime,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeMoreStudiedTime(value),
              ),
              SwitchListTile(
                title: const Text('Maior número de erros'),
                subtitle: const Text(
                  'Prioriza tópicos com maior quantidade de erros em questões.',
                ),
                value: provider.prioritizeMostErrors,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeMostErrors(value),
              ),
              SwitchListTile(
                title: const Text('Menor quantidade de questões feitas'),
                subtitle: const Text(
                  'Prioriza tópicos com poucas questões respondidas.',
                ),
                value: provider.prioritizeLeastQuestions,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeLeastQuestions(value),
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
                subtitle: const Text(
                  'Prioriza tópicos com revisões próximas ou atrasadas.',
                ),
                value: provider.prioritizePendingReviews,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizePendingReviews(value),
              ),
              SwitchListTile(
                title: const Text('Tópicos Mais Revisados'),
                subtitle: const Text(
                  'Prioriza tópicos que foram mais revisados.',
                ),
                value: provider.prioritizeMostReviewed,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeMostReviewed(value),
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
                subtitle: const Text(
                  'Prioriza tópicos novos no plano de estudos.',
                ),
                value: provider.prioritizeRecentlyAdded,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeRecentlyAdded(value),
              ),
              SwitchListTile(
                title: const Text('Não estudados há um tempo'),
                subtitle: const Text(
                  'Prioriza tópicos não estudados em um período específico.',
                ),
                value: provider.prioritizeNotStudiedInTimeWindow,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) =>
                          provider.setPrioritizeNotStudiedInTimeWindow(value),
              ),
              SwitchListTile(
                title: const Text('Evitar repetição imediata'),
                subtitle: const Text(
                  'Penaliza tópicos estudados muito recentemente para sugerir novos.',
                ),
                value: provider.prioritizeNotRecentlyStudied,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) =>
                          provider.setPrioritizeNotRecentlyStudied(value),
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
                          inactiveColor:
                              Colors.grey[300],
                          onChanged: provider.sequentialTopics
                              ? null
                              : (value) =>
                                    provider.setNotStudiedInDays(value.toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Critérios de Relevância',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                title: const Text('Priorizar tópicos não finalizados'),
                subtitle: const Text(
                  'Dá mais peso a tópicos cuja teoria ainda não foi finalizada.',
                ),
                value: provider.prioritizeUnfinishedTopics,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeUnfinishedTopics(value),
              ),
              SwitchListTile(
                title: const Text('Peso dos Tópicos'),
                subtitle: const Text(
                  'Prioriza tópicos com maior peso (definido por você ou calculado).',
                ),
                value: provider.prioritizeTopicWeights,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
                onChanged: provider.sequentialTopics
                    ? null
                    : (value) => provider.setPrioritizeTopicWeights(value),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Configuração de Níveis de Estudo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildLevelConfig(context, provider, 'Iniciante', provider.inicianteWorkload, provider.inicianteMinSession, provider.inicianteMaxSession, provider.setInicianteWorkload, provider.setInicianteSessionRange),
              _buildLevelConfig(context, provider, 'Intermediário', provider.intermediarioWorkload, provider.intermediarioMinSession, provider.intermediarioMaxSession, provider.setIntermediarioWorkload, provider.setIntermediarioSessionRange),
              _buildLevelConfig(context, provider, 'Avançado', provider.avancadoWorkload, provider.avancadoMinSession, provider.avancadoMaxSession, provider.setAvancadoWorkload, provider.setAvancadoSessionRange),
              const Divider(),
              SwitchListTile(
                title: const Text('Embaralhar Ciclo'),
                subtitle: const Text(
                  'Se ativado, a ordem das sessões de estudo será aleatória a cada novo ciclo gerado.',
                ),
                value: provider.shuffleCycle,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) => provider.setShuffleCycle(value),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLevelConfig(BuildContext context, MentoriaProvider provider, String title, int workload, int min, int max, Function(int) setWorkload, Function(int, int) setSession) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Horas semanais: $workload'),
            Slider(
              value: workload.toDouble(),
              min: 10,
              max: 80,
              divisions: 70,
              label: workload.toString(),
              onChanged: (val) => setWorkload(val.toInt()),
            ),
            Text('Sessão: $min a $max minutos'),
            RangeSlider(
              values: RangeValues(min.toDouble(), max.toDouble()),
              min: 15,
              max: 240,
              divisions: 45,
              labels: RangeLabels('$min', '$max'),
              onChanged: (val) => setSession(val.start.toInt(), val.end.toInt()),
            ),
          ],
        ),
      ),
    );
  }
}
