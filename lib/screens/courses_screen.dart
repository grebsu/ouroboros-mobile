import 'package:flutter/material.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

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
                    'Meus Cursos',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gerencie suas videoaulas e materiais de cursos.',
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

          // Search bar wireframe
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar curso ou plataforma...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 24),

          // Statistics overview cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Cursos Ativos',
                  value: '4',
                  icon: Icons.school,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Aulas Concluídas',
                  value: '128',
                  icon: Icons.play_circle_fill,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  title: 'Horas Assistidas',
                  value: '64h',
                  icon: Icons.timer,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Cursos em Andamento',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Wireframe course cards
          _buildCourseCard(
            context,
            title: 'Direito Constitucional do Zero ao Avançado',
            platform: 'Estratégia Concursos',
            progress: 0.65,
            completedLessons: 26,
            totalLessons: 40,
            color: Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildCourseCard(
            context,
            title: 'Português Técnico e Redação Oficial',
            platform: 'Gran Cursos Online',
            progress: 0.30,
            completedLessons: 9,
            totalLessons: 30,
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildCourseCard(
            context,
            title: 'Raciocínio Lógico-Matemático para Carreiras Fiscais',
            platform: 'Curso AlfaCon',
            progress: 0.85,
            completedLessons: 34,
            totalLessons: 40,
            color: Colors.deepOrange,
          ),
          const SizedBox(height: 12),
          _buildCourseCard(
            context,
            title: 'Direito Administrativo Sistematizado',
            platform: 'Mege Concursos',
            progress: 0.15,
            completedLessons: 3,
            totalLessons: 20,
            color: Colors.purple,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Funcionalidade de Adicionar Curso em desenvolvimento.'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Curso'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context, {
    required String title,
    required String platform,
    required double progress,
    required int completedLessons,
    required int totalLessons,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.video_library, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        platform,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedLessons de $totalLessons aulas (${(progress * 100).toInt()}%)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[600]),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
