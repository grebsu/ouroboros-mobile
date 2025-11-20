import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class PerformanceData {
  final Subject subject;
  final int totalQuestions;
  final int correctQuestions;
  final double performance;
  final Duration? studyTime; // Make nullable

  PerformanceData({
    required this.subject,
    required this.totalQuestions,
    required this.correctQuestions,
    required this.performance,
    this.studyTime, // Make optional
  });
}

class PerformanceTable extends StatelessWidget {
  final List<PerformanceData> performanceData;

  const PerformanceTable({Key? key, required this.performanceData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (performanceData.isEmpty) {
      return const Center(child: Text('Nenhum dado de desempenho ainda.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: performanceData.length,
      itemBuilder: (context, index) {
        final data = performanceData[index];
        final subjectColor = Color(int.parse(data.subject.color.replaceFirst('#', '0xFF')));
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          color: subjectColor, // Set card color to subject color
          child: ListTile(
            // leading property removed
            title: Row(
              children: [
                Expanded(
                  flex: 3, // Give more space to the title
                  child: Text(
                    data.subject.subject,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2, // Give less space to the progress bar
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: data.performance / 100,
                      backgroundColor: Colors.black.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        data.performance >= 80 ? Colors.teal : (data.performance >= 50 ? Colors.yellow : Colors.redAccent)
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Wrap(
              spacing: 8.0, // Horizontal space between capsules
              runSpacing: 4.0, // Vertical space between lines of capsules
              children: [
                _buildDataCapsule(
                  label: 'Acertos',
                  value: '${data.correctQuestions}',
                  backgroundColor: Colors.black.withOpacity(0.2),
                  labelColor: Colors.lightGreenAccent,
                ),
                _buildDataCapsule(
                  label: 'Erros',
                  value: '${data.totalQuestions - data.correctQuestions}',
                  backgroundColor: Colors.black.withOpacity(0.2),
                  labelColor: Colors.redAccent,
                ),
                if (data.studyTime != null)
                  _buildDataCapsule(
                    label: 'Tempo',
                    value: _formatDuration(data.studyTime!),
                    backgroundColor: Colors.black.withOpacity(0.2),
                    labelColor: Colors.white,
                  ),
                _buildDataCapsule(
                  label: 'Desempenho',
                  value: '${data.performance.toStringAsFixed(1)}%',
                  backgroundColor: Colors.black.withOpacity(0.2),
                  labelColor: Colors.white,
                ),
              ],
            ),
            // trailing removed
          ),
        );
      },
    );
  }

  Widget _buildDataCapsule({
    required String label,
    required String value,
    required Color backgroundColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: labelColor)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h${minutes.toString().padLeft(2, '0')}m';
  }
}
