import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:ouroboros_mobile/models/data_models.dart';

class DonutChart extends StatelessWidget {
  final List<StudySession> cycle;
  final double size;
  final String studyHours;
  final Map<String, int> sessionProgressMap;
  final int currentProgressMinutes; // NOVO PARÂMETRO

  const DonutChart({
    Key? key,
    required this.cycle,
    this.size = 300,
    required this.studyHours,
    required this.sessionProgressMap,
    required this.currentProgressMinutes, // NOVO PARÂMETRO
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
          currentProgressMinutes: currentProgressMinutes, // NOVO PARÂMETRO
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
  final int currentProgressMinutes; // NOVO PARÂMETRO

  _DonutChartPainter({
    required this.context, // Require context in the constructor
    required this.cycle,
    required this.studyHours,
    required this.sessionProgressMap,
    required this.currentProgressMinutes, // NOVO PARÂMETRO
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 25.0; // Largura de cada anel
    final gap = 8.0; // Espaço entre os anéis
    const startAngleOffset = -math.pi / 2;

    final center = Offset(size.width / 2, size.height / 2);
    // Raio do anel interno (ciclo)
    final innerRingRadius = size.width / 2 - strokeWidth - gap;
    // Raio do anel externo (progresso)
    final outerRingRadius = size.width / 2 - (strokeWidth / 2);

    // 1. Calcular a duração total do ciclo
    final totalCycleDuration = cycle.fold<int>(
      0,
      (sum, session) => sum + session.duration,
    );

    // 2. Se o ciclo está vazio ou não tem duração, desenha anéis cinzas e para.
    if (totalCycleDuration == 0) {
      final backgroundPaint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, innerRingRadius, backgroundPaint);
      canvas.drawCircle(center, outerRingRadius, backgroundPaint);
    } else {
      // 3. Desenhar o anel INTERNO (fundo do ciclo)
      double cumulativeAngleForInnerRing = startAngleOffset;

      // Reordena as sessões para a visualização do anel interno
      final List<StudySession> sessionsWithProgress = cycle.where((session) {
        final progress = sessionProgressMap[session.id] ?? 0;
        return progress > 0;
      }).toList();
      final List<StudySession> sessionsWithoutProgress = cycle.where((session) {
        final progress = sessionProgressMap[session.id] ?? 0;
        return progress == 0;
      }).toList();

      final List<StudySession> reorderedCycleForInnerRing = [
        ...sessionsWithProgress,
        ...sessionsWithoutProgress,
      ];

      for (final session in reorderedCycleForInnerRing) {
        final progress = sessionProgressMap[session.id] ?? 0;
        final isCompleted = progress >= session.duration;

        final sessionPaint = Paint()
          ..color = isCompleted
              ? Colors.grey[300]! // Cor neutra para sessões concluídas
              : Color(int.parse(session.color.replaceFirst('#', '0xFF')))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

        // Se a sessão foi pulada e não há progresso, ela ainda ocupará seu espaço no anel interno,
        // mas sua cor pode ser mais suave ou transparente para indicar que não foi tocada.
        // No momento, ela manterá a cor da matéria se não estiver completa.

        final sessionAngle =
            (session.duration / totalCycleDuration) * 2 * math.pi;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: innerRingRadius),
          cumulativeAngleForInnerRing,
          sessionAngle,
          false,
          sessionPaint,
        );
        cumulativeAngleForInnerRing += sessionAngle;
      }

      // 4. Desenhar o anel EXTERNO (progresso)
      // Fundo cinza para o anel de progresso
      final progressBackgroundPaint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, outerRingRadius, progressBackgroundPaint);

      // Arco de progresso em Teal
      if (currentProgressMinutes > 0) {
        final progressPaint = Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = strokeWidth;

        final progressAngle =
            (currentProgressMinutes / totalCycleDuration) * 2 * math.pi;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRingRadius),
          startAngleOffset,
          progressAngle,
          false,
          progressPaint,
        );
      }
    }

    // 5. Desenhar o texto no centro
    final textPainter = TextPainter(
      text: TextSpan(
        text: studyHours,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
