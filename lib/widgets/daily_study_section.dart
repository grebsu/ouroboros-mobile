import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class DailyStudySection extends StatefulWidget {
  final Map<String, Map<String, int>> dailySubjectStudyTime;
  final List<Subject> subjectColors;

  const DailyStudySection({
    Key? key,
    required this.dailySubjectStudyTime,
    required this.subjectColors,
  }) : super(key: key);

  @override
  State<DailyStudySection> createState() => _DailyStudySectionState();
}

class _DailyStudySectionState extends State<DailyStudySection> {
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _updateCurrentDate();
  }

  void _updateCurrentDate() {
    final today = DateTime.now();
    _currentDate = DateFormat('dd/MM/yyyy').format(today);
  }

  Color _hexToColor(String hexString) {
    final hexCode = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  String _formatMinutesToHoursMinutes(int totalMinutes) {
    if (totalMinutes < 0) return '0min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}min';
    } else {
      return '${minutes}min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayIso = DateTime.now().toIso8601String().split('T')[0];
    final todaysStudyData = widget.dailySubjectStudyTime[todayIso] ?? {};

    final Map<String, Color> subjectColorMap = {};
    for (var subject in widget.subjectColors) {
      subjectColorMap[subject.subject] = _hexToColor(subject.color);
    }

    final List<Map<String, dynamic>> studyData = [];
    todaysStudyData.forEach((subjectName, timeInMs) {
      studyData.add({
        'subject': subjectName,
        'minutes': (timeInMs / 60000).round(),
        'color': subjectColorMap[subjectName] ?? Colors.grey,
      });
    });

    final totalStudyMinutes = studyData.fold<int>(
      0,
      (acc, item) => acc + item['minutes'] as int,
    );

    List<PieChartSectionData> showingSections() {
      if (studyData.isEmpty) {
        return [
          PieChartSectionData(
            color: Colors.grey.shade300,
            value: 100,
            title: '0%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            showTitle: false,
          ),
        ];
      }

      return studyData.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final isTouched = false; // No touch interaction for now
        final double radius = isTouched ? 60 : 50;
        final double fontSize = isTouched ? 16 : 12;

        final double percentage = totalStudyMinutes > 0
            ? (data['minutes'] / totalStudyMinutes) * 100
            : 0;

        return PieChartSectionData(
          color: data['color'],
          value: data['minutes'].toDouble(),
          title: percentage > 0 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          badgePositionPercentageOffset: .98,
        );
      }).toList();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESTUDOS DO DIA ', // + _currentDate
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '(${_currentDate})',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: studyData.isEmpty
                  ? Center(
                      child: PieChart(
                        PieChartData(
                          sections: showingSections(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                        ),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sections: showingSections(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Legenda:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: studyData.length,
              itemBuilder: (context, index) {
                final item = studyData[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item['color'],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item['subject']}: ${_formatMinutesToHoursMinutes(item['minutes'] as int)}',
                          style: TextStyle(color: Colors.grey.shade700),
                          overflow: TextOverflow
                              .ellipsis, // Add ellipsis for long text
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${_formatMinutesToHoursMinutes(totalStudyMinutes)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
