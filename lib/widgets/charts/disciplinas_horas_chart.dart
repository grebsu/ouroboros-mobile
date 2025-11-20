import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class DisciplinasHorasChart extends StatelessWidget {
  final Map<Subject, double> subjectHours;
  final String sortOrder;

  const DisciplinasHorasChart({super.key, required this.subjectHours, this.sortOrder = 'desc'});

  static String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final sortedSubjects = subjectHours.keys.toList();

    if (sortOrder == 'desc') {
      sortedSubjects.sort((a, b) => subjectHours[b]!.compareTo(subjectHours[a]!));
    } else if (sortOrder == 'asc') {
      sortedSubjects.sort((a, b) => subjectHours[a]!.compareTo(subjectHours[b]!));
    } else { // alpha
      sortedSubjects.sort((a, b) => a.subject.compareTo(b.subject));
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedSubjects.length; i++) {
      final subject = sortedSubjects[i];
      final hours = subjectHours[subject]!;
      final subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours,
              gradient: LinearGradient(
                colors: [subjectColor.withOpacity(0.8), subjectColor.withOpacity(0.4)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 400,
      width: double.infinity, // Ajustar a largura para ocupar todo o espaço disponível
      child: RotatedBox(
        quarterTurns: 1,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barGroups: barGroups,
            minY: 0,
            maxY: subjectHours.isNotEmpty ? subjectHours.values.reduce((a, b) => a > b ? a : b) * 1.2 : 1.0, // Ajusta o maxY para o maior valor + 20%
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles( // This is effectively the Y-axis for hours in the rotated view
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40, // Space for hours
                  getTitlesWidget: (value, meta) {
                    // Show decimal if less than 1 hour, otherwise integer
                    if (value < 1 && value > 0) {
                      return Text('${value.toStringAsFixed(1)}h', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10));
                    }
                    return Text('${value.toInt()}h', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10));
                  },
                  interval: null, // Let fl_chart determine the interval
                ),
              ),
              bottomTitles: AxisTitles( // This is effectively the X-axis for subjects in the rotated view
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 100, // Increased space for subject names
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < sortedSubjects.length) {
                      final subject = sortedSubjects[value.toInt()];
                      return SideTitleWidget(
                        meta: meta,
                        angle: -0.785, // Aproximadamente -45 graus em radianos para rotação diagonal
                        space: 4, // Adjust space to bring text closer to bars
                        child: Text(subject.subject, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10), textAlign: TextAlign.end),
                      );
                    }
                    return const Text('');
                  },
                  interval: 1, // Show all subject labels
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final subject = sortedSubjects[group.x.toInt()];
                  final hours = subjectHours[subject]!;
                  final h = hours.floor();
                  final m = ((hours - h) * 60).round();
                  return BarTooltipItem(
                    '${subject.subject}\n${h}h${m.toString().padLeft(2, '0')}min',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false, // Vertical lines in original orientation, so horizontal in rotated
              getDrawingHorizontalLine: (value) { // Horizontal lines in original orientation, so vertical in rotated
                return const FlLine(
                  color: Colors.black12,
                  strokeWidth: 1,
                  dashArray: [5],
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xffe7e7e7), width: 1),
            ),
          ),
        ),
      ),
    );
  }
}
