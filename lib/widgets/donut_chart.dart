import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ouroboros_mobile/models/data_models.dart';

class DonutChart extends StatelessWidget {
  final List<StudySession> cycle;
  final double size;
  final String studyHours;
  final Map<String, int> sessionProgressMap;

  const DonutChart({
    Key? key,
    required this.cycle,
    this.size = 300,
    required this.studyHours,
    required this.sessionProgressMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutChartPainter(
          context: context, // Pass the context here
          cycle: cycle,
          studyHours: studyHours,
          sessionProgressMap: sessionProgressMap,
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<StudySession> cycle;
  final String studyHours;
  final Map<String, int> sessionProgressMap;
  final BuildContext context; // Add BuildContext here

  _DonutChartPainter({
    required this.context, // Require context in the constructor
    required this.cycle,
    required this.studyHours,
    required this.sessionProgressMap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 40.0;
    final gap = 5.0;

    final mainRingRadius = size.width / 2 - strokeWidth - gap;
    final progressRingRadius = size.width / 2 - (strokeWidth / 2);

    final center = Offset(size.width / 2, size.height / 2);

    // Draw the background rings
    final backgroundPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, progressRingRadius, backgroundPaint);
    canvas.drawCircle(center, mainRingRadius, backgroundPaint);

    if (cycle.isEmpty) return;

    final totalSessions = cycle.length;
    final anglePerSession = 2 * math.pi / totalSessions;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < cycle.length; i++) {
      final session = cycle[i];
      final progress = sessionProgressMap[session.id] ?? 0;
      final isCompleted = progress >= session.duration;

      // Main ring (session color or transparent if completed)
      final sessionPaint = Paint()
        ..color = isCompleted ? Colors.transparent : Color(int.parse(session.color.replaceFirst('#', '0xFF')))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: mainRingRadius),
        startAngle,
        anglePerSession,
        false,
        sessionPaint,
      );

      // Progress ring (teal if completed, transparent otherwise)
      final progressPaint = Paint()
        ..color = isCompleted ? Colors.teal : Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: progressRingRadius),
        startAngle,
        anglePerSession,
        false,
        progressPaint,
      );

      startAngle += anglePerSession;
    }

    // Draw the center text
    final textPainter = TextPainter(
      text: TextSpan(
        text: studyHours,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}