import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HorasEstudoChart extends StatelessWidget {
  final Map<DateTime, double> dailyHours;

  const HorasEstudoChart({super.key, required this.dailyHours});

  @override
  Widget build(BuildContext context) {
    final sortedDates = dailyHours.keys.toList()..sort();

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final hours = dailyHours[date]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: hours,
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent.withOpacity(0.6)],
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
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hours = rod.toY.toInt();
                final minutes = ((rod.toY - hours) * 60).toInt();
                final date = sortedDates[group.x.toInt()];
                return BarTooltipItem(
                  '${hours.toString().padLeft(2, '0')}h${minutes.toString().padLeft(2, '0')}m\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final hours = value.toInt();
                  return Text('${hours}h', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10));
                },
                interval: 1, // Show labels for every hour
              ),
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
    );
  }
}
