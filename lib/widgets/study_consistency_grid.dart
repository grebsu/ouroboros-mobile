import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudyConsistencyGrid extends StatelessWidget {
  final List<Map<String, dynamic>> daysData;

  const StudyConsistencyGrid({Key? key, required this.daysData}) : super(key: key);

  Color _getDayColor(Map<String, dynamic> day) {
    if (!(day['active'] as bool)) return Colors.grey.shade200;
    switch (day['status']) {
      case 'studied':
        return Colors.teal;
      case 'not_studied':
        return Colors.redAccent;
      case 'rest_day':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  String _getTooltipText(Map<String, dynamic> day) {
    final date = day['date'] as DateTime;
    final formattedDate = DateFormat('EEEE, d MMMM', 'pt_BR').format(date);
    String statusText;
    switch (day['status']) {
      case 'studied':
        statusText = 'Estudado';
        break;
      case 'not_studied':
        statusText = 'Não estudado';
        break;
      case 'rest_day':
        statusText = 'Folga';
        break;
      default:
        statusText = '';
    }
    return '$formattedDate: $statusText';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 15,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: daysData.length,
      itemBuilder: (context, index) {
        final day = daysData[index];
        return Tooltip(
          message: _getTooltipText(day),
          child: Container(
            height: 24, // Increased height to accommodate day number
            width: 24, // Added width for square shape
            decoration: BoxDecoration(
              color: _getDayColor(day),
              borderRadius: BorderRadius.circular(4), // Slightly larger radius
            ),
            child: Center(
              child: Text(
                (day['date'] as DateTime).day.toString(),
                style: TextStyle(
                  color: (day['active'] as bool) ? Colors.white : Colors.grey.shade600, // Text color based on active status
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
