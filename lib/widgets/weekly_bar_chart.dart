import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ouroboros_mobile/screens/home_screen.dart'; // Import ChartView enum

class WeeklyBarChart extends StatelessWidget {
  final List<Duration> weeklyData;
  final List<int> weeklyQuestionsData;
  final ChartView currentView;

  const WeeklyBarChart({
    Key? key,
    required this.weeklyData,
    required this.weeklyQuestionsData,
    required this.currentView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> days = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    if (currentView == ChartView.time) {
      final maxStudyTime = weeklyData.fold<Duration>(Duration.zero, (max, d) => d > max ? d : max);
      maxY = (maxStudyTime.inMinutes / 60.0) * 1.2; // Add some padding to the top
      if (maxY == 0) maxY = 1.0; // Avoid division by zero if no data

      for (int i = 0; i < weeklyData.length; i++) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weeklyData[i].inMinutes / 60.0,
                color: Colors.teal, // Use Teal for time
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          ),
        );
      }
    } else {
      final maxQuestions = weeklyQuestionsData.fold<int>(0, (max, q) => q > max ? q : max);
      maxY = (maxQuestions * 1.2).toDouble(); // Add some padding to the top
      if (maxY == 0) maxY = 10.0; // Avoid division by zero if no data

      for (int i = 0; i < weeklyQuestionsData.length; i++) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weeklyQuestionsData[i].toDouble(),
                color: Colors.purple, // Use Purple for questions
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          ),
        );
      }
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(days[value.toInt()], style: const TextStyle(fontSize: 10)),
                  );
                },
                reservedSize: 20,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  String text;
                  if (currentView == ChartView.time) {
                    text = '${value.toInt()}h';
                  } else {
                    text = value.toInt().toString();
                  }
                  return Text(text, style: const TextStyle(fontSize: 10));
                },
                reservedSize: 28,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String valueText;
                if (currentView == ChartView.time) {
                  valueText = '${rod.toY.toStringAsFixed(1)}h';
                } else {
                  valueText = rod.toY.toInt().toString();
                }
                return BarTooltipItem(
                  valueText,
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
