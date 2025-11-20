import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EvolucaoTempoChart extends StatelessWidget {
  final Map<DateTime, Map<String, int>> dailyStats;

  const EvolucaoTempoChart({super.key, required this.dailyStats});

  @override
  Widget build(BuildContext context) {
    final sortedDates = dailyStats.keys.toList()..sort();

    final List<FlSpot> correctSpots = [];
    final List<FlSpot> incorrectSpots = [];

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final stats = dailyStats[date]!;
      correctSpots.add(FlSpot(i.toDouble(), (stats['correct'] ?? 0).toDouble()));
      incorrectSpots.add(FlSpot(i.toDouble(), (stats['incorrect'] ?? 0).toDouble()));
    }

    double maxY = 0;
    for (var stats in dailyStats.values) {
      final correct = (stats['correct'] ?? 0).toDouble();
      final incorrect = (stats['incorrect'] ?? 0).toDouble();
      if (correct > maxY) maxY = correct;
      if (incorrect > maxY) maxY = incorrect;
    }

    double yInterval;
    if (maxY <= 5) {
      yInterval = 1;
    } else if (maxY <= 20) {
      yInterval = 5;
    } else if (maxY <= 50) {
      yInterval = 10;
    } else {
      yInterval = (maxY / 5).ceilToDouble(); // Mostrar cerca de 5 rótulos
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
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
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}Q', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10));
                },
                interval: yInterval, // Show labels for every question count
                reservedSize: 28,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40, // Increased reserved size for rotated labels
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                    final date = sortedDates[value.toInt()];
                    return SideTitleWidget(
                      meta: meta,
                      angle: -45, // Rotate labels
                      space: 8,
                      child: Text(DateFormat('dd/MM').format(date), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
                interval: sortedDates.length > 7 ? (sortedDates.length / 7).ceilToDouble() : 1, // Dynamic interval
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xffe7e7e7), width: 1),
          ),
          minX: 0,
          maxX: (sortedDates.length - 1).toDouble(),
          minY: 0,
          lineBarsData: [
            _buildLineChartBarData(correctSpots, Colors.teal),
            _buildLineChartBarData(incorrectSpots, Colors.red),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  if (flSpot.x.toInt() >= 0 && flSpot.x.toInt() < sortedDates.length) {
                    final date = sortedDates[flSpot.x.toInt()];
                    final value = flSpot.y;
                    final isCorrectLine = barSpot.bar.color == Colors.teal; // Check color
                    final label = isCorrectLine ? 'Acertos' : 'Erros';
                    final color = isCorrectLine ? Colors.teal : Colors.red;

                    return LineTooltipItem(
                      '${value.toInt()} $label\n',
                      TextStyle(color: color, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: DateFormat('dd/MM/yyyy').format(date),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return null;
                  }
                }).whereType<LineTooltipItem>().toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      gradient: LinearGradient(
        colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
      ),
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
