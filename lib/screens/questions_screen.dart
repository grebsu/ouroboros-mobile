import 'package:flutter/material.dart';

class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Banco de Questões',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pratique questões e acompanhe seu rendimento por matéria.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Chip(
                avatar: const Icon(Icons.build_circle, color: Colors.teal),
                label: const Text('Modo Wireframe'),
                backgroundColor: Colors.teal.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtrar por palavra-chave, banca ou assunto...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Filtros avançados em desenvolvimento.')),
                  );
                },
                icon: const Icon(Icons.tune),
                label: const Text('Filtros'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overall Performance Banner
          Card(
            color: Colors.teal,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context, 'Resolvidas', '1.450', Icons.check_circle_outline),
                  _buildStatItem(context, 'Acertos', '1.189', Icons.thumb_up_alt_outlined),
                  _buildStatItem(context, 'Taxa de Sucesso', '82%', Icons.pie_chart_outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Cadernos de Questões por Matéria',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Question notebooks list
          _buildNotebookTile(
            context,
            title: 'Direito Constitucional',
            subtitle: 'Controle de Constitucionalidade, Direitos Fundamentais',
            questionsCount: 450,
            accuracy: 85,
            color: Colors.indigo,
          ),
          const SizedBox(height: 10),
          _buildNotebookTile(
            context,
            title: 'Direito Administrativo',
            subtitle: 'Licitações, Atos Administrativos, Improbidade',
            questionsCount: 380,
            accuracy: 78,
            color: Colors.teal,
          ),
          const SizedBox(height: 10),
          _buildNotebookTile(
            context,
            title: 'Língua Portuguesa',
            subtitle: 'Sintaxe, Pontuação, Compreensão de Texto',
            questionsCount: 320,
            accuracy: 88,
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 10),
          _buildNotebookTile(
            context,
            title: 'Raciocínio Lógico',
            subtitle: 'Lógica de Proposições, Diagramas, Probabilidade',
            questionsCount: 200,
            accuracy: 70,
            color: Colors.purple,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Criação de caderno de questões em desenvolvimento.'),
            ),
          );
        },
        icon: const Icon(Icons.playlist_add),
        label: const Text('Novo Caderno'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNotebookTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int questionsCount,
    required int accuracy,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.quiz, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$questionsCount questões',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$accuracy% de acertos',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abrindo caderno: $title')),
          );
        },
      ),
    );
  }
}
