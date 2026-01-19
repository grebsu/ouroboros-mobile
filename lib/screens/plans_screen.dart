import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/screens/plan_detail_screen.dart';
import 'package:ouroboros_mobile/widgets/create_plan_modal.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';
import 'package:uuid/uuid.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  final List<String> _subjectColors = [
    '#ef4444',
    '#f97316',
    '#eab308',
    '#84cc16',
    '#22c55e',
    '#14b8a6',
    '#06b6d4',
    '#3b82f6',
    '#8b5cf6',
    '#d946ef',
    '#f43f5e',
    '#64748b',
    '#f43f5e',
    '#be123c',
    '#9f1239',
    '#7f1d1d',
    '#7f1d1d',
    '#881337',
    '#9d174d',
    '#a21caf',
    '#86198f',
    '#7e22ce',
    '#6b21a8',
    '#5b21b6',
    '#4c1d95',
    '#312e81',
    '#1e3a8a',
    '#1e40af',
    '#1d4ed8',
    '#2563eb',
    '#3b82f6',
    '#0284c7',
    '#0369a1',
    '#075985',
    '#0891b2',
    '#0e7490',
    '#155e75',
    '#166534',
    '#14532d',
    '#16a34a',
    '#15803d',
    '#166534',
  ];

  String _cleanSubjectName(String rawName) {
    final stopWords = [' para ', ' - ', ' ('];
    int? firstStopIndex;

    for (final word in stopWords) {
      final index = rawName.indexOf(word);
      if (index != -1) {
        if (firstStopIndex == null || index < firstStopIndex) {
          firstStopIndex = index;
        }
      }
    }

    if (firstStopIndex != null) {
      return rawName.substring(0, firstStopIndex).trim();
    }

    return rawName.trim();
  }

  @override
  Widget build(BuildContext context) {
    print('PlansScreen: build chamado.');
    return Stack(
      children: [
        Scaffold(
          body: Consumer<PlansProvider>(
            builder: (context, provider, child) {
              print(
                'PlansScreen Consumer: isLoading=${provider.isLoading}, plans.isEmpty=${provider.plans.isEmpty}',
              );
              if (provider.isLoading && provider.plans.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.teal),
                );
              }
              if (provider.plans.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildPlansList(context, provider.plans);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // Limita a largura máxima para desktop
        constraints: const BoxConstraints(
          maxWidth: 600,
        ), // Largura máxima para o conteúdo
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined, size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'Nenhum plano de estudo encontrado.',
                style: TextStyle(fontSize: 18, color: Colors.teal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const CreatePlanModal();
                    },
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Crie seu primeiro plano'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'OU',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlansList(BuildContext context, List<Plan> plans) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1000) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    final double horizontalPadding = screenWidth > 1000 ? 100.0 : 16.0;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16.0,
        ),
        children: <Widget>[
          const SizedBox(height: 24.0),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.7,
            ),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanDetailScreen(plan: plan),
                    ),
                  );
                },
                child: _buildPlanCard(context, plan),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, Plan plan) {
    final stats =
        Provider.of<PlansProvider>(context, listen: false).planStats[plan.id] ??
        (subjectCount: 0, topicCount: 0);

    return Card(
      elevation: 6.0, // Aumenta a elevação para um efeito mais pronunciado
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ), // Bordas mais arredondadas
      clipBehavior: Clip
          .antiAlias, // Garante que o conteúdo seja cortado pelas bordas arredondadas
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanDetailScreen(plan: plan),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Padding consistente
          child: Column(
            crossAxisAlignment: CrossAxisAlignment
                .stretch, // Estica os elementos horizontalmente
            mainAxisAlignment: MainAxisAlignment
                .spaceBetween, // Distribui o espaço verticalmente
            children: <Widget>[
              // Ícone ou imagem do plano
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(
                      0.1,
                    ), // Fundo suave com a cor primária
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: plan.iconUrl != null && plan.iconUrl!.isNotEmpty
                        ? Image.file(
                            File(plan.iconUrl!),
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.assignment,
                              size: 48,
                              color: Theme.of(context).primaryColor,
                            ), // Ícone padrão com cor primária
                          )
                        : Icon(
                            Icons.assignment,
                            size: 48,
                            color: Theme.of(context).primaryColor,
                          ), // Ícone padrão com cor primária
                  ),
                ),
              ),
              const SizedBox(height: 16), // Espaçamento maior após o ícone
              // Nome do plano e estatísticas
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight:
                          FontWeight.w700, // Mais destaque para o nome do plano
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface, // Cor mais escura para o texto principal
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plan.banca != null &&
                      plan.banca!.isNotEmpty) // Exibe a banca se disponível
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4.0,
                      ), // Espaçamento superior para a banca
                      child: Text(
                        plan.banca!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ), // Estilo para a banca
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(
                    height: 8,
                  ), // Espaçamento entre nome/banca e estatísticas
                  Text(
                    'Disciplinas: ${stats.subjectCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ), // Estilo discreto
                  ),
                  Text(
                    'Tópicos: ${stats.topicCount}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ), // Estilo discreto
                  ),
                ],
              ),
              // Botão de exclusão
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ), // Ícone de exclusão com cor de erro
                  onPressed: () {
                    _showDeleteConfirmationDialog(context, plan);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Plan plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationModal(
          title: 'Excluir Plano',
          message:
              'Você tem certeza que deseja excluir o plano "${plan.name}"? Esta ação não pode ser desfeita.',
          confirmText: 'Excluir',
          onConfirm: () {
            Provider.of<PlansProvider>(
              context,
              listen: false,
            ).deletePlan(plan.id);
            Navigator.of(context).pop();
          },
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  // Função auxiliar para calcular o número total de tópicos (replicando a lógica do desktop)
  int _calculateTotalTopicsRecursively(List<Topic> topics) {
    if (topics.isEmpty) {
      return 0;
    }
    return topics.fold<int>(0, (previousValue, topic) {
      return previousValue +
          1 +
          _calculateTotalTopicsRecursively(topic.sub_topics ?? []);
    });
  }
}
