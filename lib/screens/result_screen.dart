// lib/screens/result_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/question.dart';

class ResultScreen extends StatefulWidget {
  final QuizResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleAnim;
  late Animation<double> _fadeAnim;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _circleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _gradeColor {
    final pct = widget.result.percentage;
    if (pct >= 90) return const Color(0xFF4CAF50);
    if (pct >= 75) return const Color(0xFF2196F3);
    if (pct >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Résultats'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.home, color: Colors.white),
            label: const Text(
              'Accueil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score card
            FadeTransition(
              opacity: _fadeAnim,
              child: _ScoreCard(
                result: widget.result,
                circleAnim: _circleAnim,
                gradeColor: _gradeColor,
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            FadeTransition(
              opacity: _fadeAnim,
              child: _StatsRow(result: widget.result),
            ),
            const SizedBox(height: 16),

            // Toggle detail button
            FadeTransition(
              opacity: _fadeAnim,
              child: GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showDetails ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showDetails
                            ? 'Masquer le détail'
                            : 'Voir le détail des réponses',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Detailed results
            if (_showDetails) ...[
              const SizedBox(height: 16),
              ...widget.result.questionResults.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _QuestionReviewCard(
                        index: entry.key,
                        result: entry.value,
                      ),
                    ),
                  ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            FadeTransition(
              opacity: _fadeAnim,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      ),
                      icon: const Icon(Icons.home),
                      label: const Text('Accueil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final QuizResult result;
  final Animation<double> circleAnim;
  final Color gradeColor;

  const _ScoreCard({
    required this.result,
    required this.circleAnim,
    required this.gradeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D47A1),
            const Color(0xFF1565C0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            result.moduleTitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          // Animated circle
          AnimatedBuilder(
            animation: circleAnim,
            builder: (context, child) {
              return SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _CircleProgressPainter(
                        progress: circleAnim.value * (result.percentage / 100),
                        color: gradeColor,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          result.gradeEmoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        Text(
                          '${(circleAnim.value * result.percentage).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gradeColor.withOpacity(0.5)),
            ),
            child: Text(
              result.grade,
              style: TextStyle(
                color: gradeColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.correctAnswers} / ${result.totalQuestions} réponses correctes',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter old) => old.progress != progress;
}

class _StatsRow extends StatelessWidget {
  final QuizResult result;

  const _StatsRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final wrongCount = result.totalQuestions - result.correctAnswers;
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            value: '${result.correctAnswers}',
            label: 'Correctes',
            color: const Color(0xFF4CAF50),
            icon: '✅',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: '$wrongCount',
            label: 'Incorrectes',
            color: const Color(0xFFF44336),
            icon: '❌',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            value: '${result.totalQuestions}',
            label: 'Total',
            color: const Color(0xFF2196F3),
            icon: '📝',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final String icon;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final int index;
  final QuestionResult result;

  const _QuestionReviewCard({
    required this.index,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = result.isCorrect;
    final borderColor =
        isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final bgColor =
        isCorrect ? const Color(0xFFF1F8E9) : const Color(0xFFFFF3E0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCorrect ? 'Bonne réponse ✅' : 'Mauvaise réponse ❌',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.question.category,
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              result.question.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Answers display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: result.question.options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                final isUserChoice = i == result.selectedIndex;
                final isCorrectChoice = i == result.question.correctIndex;

                Color? optBg;
                Color? optBorder;
                Widget? trailingIcon;

                if (isCorrectChoice) {
                  optBg = const Color(0xFFE8F5E9);
                  optBorder = const Color(0xFF4CAF50);
                  trailingIcon = const Icon(Icons.check_circle,
                      color: Color(0xFF4CAF50), size: 18);
                } else if (isUserChoice && !isCorrect) {
                  optBg = const Color(0xFFFFEBEE);
                  optBorder = const Color(0xFFF44336);
                  trailingIcon = const Icon(Icons.cancel,
                      color: Color(0xFFF44336), size: 18);
                }

                if (optBg == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: optBorder!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCorrectChoice && isUserChoice)
                                const Text(
                                  'Votre réponse :',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFC62828),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (isCorrectChoice)
                                const Text(
                                  'Bonne réponse :',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              Text(
                                opt,
                                style:
                                    const TextStyle(fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        if (trailingIcon != null) trailingIcon,
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Explanation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.question.explanation,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
