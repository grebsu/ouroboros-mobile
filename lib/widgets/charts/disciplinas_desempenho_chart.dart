import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class DisciplinasDesempenhoChart extends StatelessWidget {
  final Map<Subject, SubjectPerformanceData> subjectPerformanceData;

  const DisciplinasDesempenhoChart({super.key, required this.subjectPerformanceData});

  @override
  Widget build(BuildContext context) {
    // Etapa 1: Ordenar alfabeticamente
    final sortedSubjects = subjectPerformanceData.keys.toList();
    sortedSubjects.sort((a, b) => a.subject.compareTo(b.subject));

    if (sortedSubjects.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Nenhum dado de desempenho para exibir.')),
      );
    }

    // Etapa 2: Construir os grupos de barras
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedSubjects.length; i++) {
      final subject = sortedSubjects[i];
      final data = subjectPerformanceData[subject]!;
      
      final barRodWidth = 8.0;
      final spaceBetweenBars = 2.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barsSpace: spaceBetweenBars,
          barRods: [
            // Barra de Acertos
            BarChartRodData(
              toY: data.correctPercentage,
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent.withOpacity(0.6)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: barRodWidth,
              borderRadius: BorderRadius.circular(4),
            ),
            // Barra de Erros
            BarChartRodData(
              toY: data.incorrectPercentage,
              gradient: LinearGradient(
                colors: [Colors.red, Colors.redAccent.withOpacity(0.6)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: barRodWidth,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 400,
          width: double.infinity,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: barGroups,
              minY: 0,
              maxY: 100,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value % 20 == 0) {
                        return Text('${value.toInt()}%', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 100, // Adjusted reserved size for rotated labels
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedSubjects.length) {
                        final subject = sortedSubjects[value.toInt()];
                        return SideTitleWidget(
                          meta: meta,
                          angle: -0.785, // Aproximadamente -45 graus em radianos
                          space: 8,
                          child: Text(
                            subject.subject,
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10),
                            textAlign: TextAlign.end, // Alinhar ao final para o texto girado
                          ),
                        );
                      }
                      return const Text('');
                    },
                    interval: sortedSubjects.length > 5 ? (sortedSubjects.length / 5).ceilToDouble() : 1, // Dynamic interval
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final subject = sortedSubjects[group.x.toInt()];
                    final data = subjectPerformanceData[subject]!;
                    String label = rodIndex == 0 ? 'Acertos' : 'Erros';
                    Color color = rodIndex == 0 ? Colors.teal : Colors.red;
                    
                    final count = rodIndex == 0 ? data.correctQuestions : (data.totalQuestions - data.correctQuestions);

                    return BarTooltipItem(
                      '${subject.subject}\n$label: ${rod.toY.toStringAsFixed(1)}% ($count/${data.totalQuestions})',
                      TextStyle(color: color, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
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
        const SizedBox(height: 16),
        // Etapa 4: Legenda
        _buildLegend(context),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(context, Colors.teal, 'Acertos'),
        const SizedBox(width: 16),
        _legendItem(context, Colors.deepOrangeAccent, 'Erros'),
      ],
    );
  }

  Widget _legendItem(BuildContext context, Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }
}
