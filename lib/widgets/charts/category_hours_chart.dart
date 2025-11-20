import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CategoryHoursChart extends StatelessWidget {
  final Map<String, double> categoryHours;

  const CategoryHoursChart({super.key, required this.categoryHours});

  static const Map<String, String> _categoryTitles = {
    'teoria': 'Teoria',
    'revisao': 'Revisão',
    'questoes': 'Questões',
    'leitura_lei': 'Lei Seca',
    'jurisprudencia': 'Jurisprudência',
  };

  static const List<String> _categoryOrder = [
    'teoria',
    'revisao',
    'questoes',
    'leitura_lei',
    'jurisprudencia',
  ];

  String _formatTimeLabel(double value) {
    final hours = value.floor();
    final minutes = ((value % 1) * 60).round();
    return '${hours.toString().padLeft(2, '0')}h${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final orderedValues = _categoryOrder.map((key) => categoryHours[key] ?? 0.0).toList();
    final orderedTitles = _categoryOrder.map((key) => _categoryTitles[key] ?? key).toList();
    final maxValue = orderedValues.isNotEmpty ? orderedValues.reduce(max) : 1.0;
    final hasData = orderedValues.any((value) => value > 0);

    if (!hasData) {
      return const SizedBox(
        height: 350,
        child: Center(child: Text('Nenhum dado de horas por categoria.')),
      );
    }

    final chart = RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: orderedValues.map((value) => RadarEntry(value: value)).toList(),
            borderColor: Colors.teal,
            fillColor: Colors.teal.withOpacity(0.4),
            borderWidth: 2,
          ),
        ],
        getTitle: (index, angle) {
          return RadarChartTitle(
            text: orderedTitles[index],
            angle: angle,
          );
        },
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
        tickBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
        gridBorderData: BorderSide(color: Colors.grey.shade300, width: 1),
        radarBorderData: const BorderSide(color: Colors.transparent),
        radarBackgroundColor: Colors.transparent,
        titlePositionPercentageOffset: 0.2,
        titleTextStyle: const TextStyle(fontSize: 14),
      ),
      swapAnimationDuration: const Duration(milliseconds: 150),
      swapAnimationCurve: Curves.linear,
    );

    return SizedBox(
      height: 350,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              chart,
              Positioned.fill(
                child: _DataLabels(
                  constraints: constraints,
                  values: orderedValues,
                  maxValue: maxValue,
                  formatLabel: _formatTimeLabel,
                  titles: orderedTitles,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DataLabels extends StatelessWidget {
  final BoxConstraints constraints;
  final List<double> values;
  final double maxValue;
  final String Function(double) formatLabel;
  final List<String> titles;

  const _DataLabels({
    required this.constraints,
    required this.values,
    required this.maxValue,
    required this.formatLabel,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    final chartRadius = min(centerX, centerY) * 0.7;

    return Stack(
      children: List.generate(values.length, (index) {
        final value = values[index];
        if (value <= 0) return const SizedBox.shrink();

        final angle = (2 * pi / values.length) * index - (pi / 2);
        final dataPointRadius = (value / (maxValue > 0 ? maxValue : 1.0)) * chartRadius;
        final labelRadius = dataPointRadius + 20.0; // Ajuste este valor conforme necessário

        final labelX = centerX + cos(angle) * labelRadius;
        final labelY = centerY + sin(angle) * labelRadius;

        return Positioned(
          left: labelX,
          top: labelY,
          child: Transform.translate(
            offset: const Offset(-22, -10), // Ajuste este offset para centralizar o texto
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                formatLabel(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
