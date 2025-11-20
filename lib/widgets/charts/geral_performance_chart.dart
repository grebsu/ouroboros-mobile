import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GeralPerformanceChart extends StatelessWidget {
  final double correctPercentage;
  final int totalCorrectQuestions;
  final int totalQuestions;

  const GeralPerformanceChart({
    super.key,
    required this.correctPercentage,
    required this.totalCorrectQuestions,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: _generateSections(context),
              centerSpaceRadius: 60,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: true),
            ),
          ),
          Text(
            '${correctPercentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections(BuildContext context) {
    final incorrectQuestions = totalQuestions - totalCorrectQuestions;
    final correctPercentageValue = totalQuestions > 0 ? (totalCorrectQuestions / totalQuestions) * 100 : 0;
    final incorrectPercentageValue = totalQuestions > 0 ? (incorrectQuestions / totalQuestions) * 100 : 0;

    return [
      PieChartSectionData(
        color: Colors.teal,
        value: correctPercentageValue.toDouble(),
        title: '$totalCorrectQuestions Acertos',
        radius: 20,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: incorrectPercentageValue.toDouble(),
        title: '$incorrectQuestions Erros',
        radius: 20,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color),
      ),
    ];
  }
}
