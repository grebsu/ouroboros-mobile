import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class SimuladoLineChart extends StatelessWidget {
  final List<SimuladoRecord> simulados;
  final String chartType;

  const SimuladoLineChart({
    Key? key,
    required this.simulados,
    required this.chartType,
  }) : super(key: key);

  double _getPerformance(SimuladoRecord simulado) {
    final totalCorrect = simulado.subjects.fold(0, (sum, s) => sum + s.correct);
    final totalQuestions = simulado.subjects.fold(
      0,
      (sum, s) => sum + s.total_questions,
    );
    return totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;
  }

  double _getTotalScore(SimuladoRecord simulado) {
    return simulado.subjects.fold(0.0, (sum, sub) {
      if (simulado.style == 'certo_errado') {
        return sum + (sub.correct - sub.incorrect);
      } else {
        return sum + (sub.correct * sub.weight);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (simulados.isEmpty) {
      return const Center(
        child: Text('Registre simulados para ver seu desempenho aqui.'),
      );
    }

    final List<FlSpot> spots = simulados.asMap().entries.map((entry) {
      final index = entry.key;
      final simulado = entry.value;
      final value = chartType == 'desempenho'
          ? _getPerformance(simulado)
          : _getTotalScore(simulado);
      return FlSpot(index.toDouble(), value.toDouble());
    }).toList();

    final List<String> labels = simulados.map((s) {
      final dateTime = DateTime.parse(s.date);
      return '${dateTime.day}/${dateTime.month}';
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    labels[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
              interval: 10,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: chartType == 'desempenho' ? Colors.teal : Colors.deepPurple,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
