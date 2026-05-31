// lib/screens/quiz_screen.dart

import 'package:flutter/material.dart';
import '../models/question.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final QuizModule module;

  const QuizScreen({super.key, required this.module});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  final List<QuestionResult> _results = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Question get _currentQuestion => widget.module.questions[_currentIndex];

  int get _totalQuestions => widget.module.questions.length;

  Color get _moduleColor => Color(int.parse(widget.module.color));

  void _selectAnswer(int index) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
    });
    _results.add(QuestionResult(
      question: _currentQuestion,
      selectedIndex: index,
      isCorrect: index == _currentQuestion.correctIndex,
    ));
  }

  void _nextQuestion() async {
    if (_currentIndex < _totalQuestions - 1) {
      await _animController.reverse();
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      _animController.forward();
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final correctCount = _results.where((r) => r.isCorrect).length;
    final result = QuizResult(
      moduleId: widget.module.id,
      moduleTitle: widget.module.title,
      totalQuestions: _totalQuestions,
      correctAnswers: correctCount,
      completedAt: DateTime.now(),
      questionResults: List.from(_results),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(result: result),
      ),
    );
  }

  Color _getOptionColor(int index) {
    if (!_answered) return Colors.white;
    if (index == _currentQuestion.correctIndex) {
      return const Color(0xFFE8F5E9);
    }
    if (index == _selectedAnswer &&
        !(_selectedAnswer == _currentQuestion.correctIndex)) {
      return const Color(0xFFFFEBEE);
    }
    return Colors.white;
  }

  Color _getOptionBorderColor(int index) {
    if (!_answered) {
      return _selectedAnswer == index ? _moduleColor : const Color(0xFFE0E0E0);
    }
    if (index == _currentQuestion.correctIndex) {
      return const Color(0xFF4CAF50);
    }
    if (index == _selectedAnswer && index != _currentQuestion.correctIndex) {
      return const Color(0xFFF44336);
    }
    return const Color(0xFFE0E0E0);
  }

  Widget _getOptionIcon(int index) {
    if (!_answered) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedAnswer == index
                ? _moduleColor
                : const Color(0xFFBDBDBD),
            width: 2,
          ),
          color: _selectedAnswer == index
              ? _moduleColor.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            ['A', 'B', 'C', 'D'][index],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedAnswer == index ? _moduleColor : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    if (index == _currentQuestion.correctIndex) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF4CAF50),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 18),
      );
    }
    if (index == _selectedAnswer && index != _currentQuestion.correctIndex) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF44336),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFBDBDBD),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          ['A', 'B', 'C', 'D'][index],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _moduleColor,
        title: Text(widget.module.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/$_totalQuestions',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            color: _moduleColor.withOpacity(0.1),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.3),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  width: MediaQuery.of(context).size.width * progress,
                  decoration: BoxDecoration(
                    color: _moduleColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _moduleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _moduleColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _currentQuestion.category,
                          style: TextStyle(
                            color: _moduleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Question
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _currentQuestion.text,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Options
                      ...List.generate(
                        _currentQuestion.options.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _selectAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getOptionColor(index),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getOptionBorderColor(index),
                                  width: _answered &&
                                          index == _currentQuestion.correctIndex
                                      ? 2
                                      : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  _getOptionIcon(index),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _currentQuestion.options[index],
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                        fontWeight: _answered &&
                                                index ==
                                                    _currentQuestion
                                                        .correctIndex
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _answered &&
                                                index ==
                                                    _currentQuestion
                                                        .correctIndex
                                            ? const Color(0xFF2E7D32)
                                            : _answered &&
                                                    index == _selectedAnswer &&
                                                    index !=
                                                        _currentQuestion
                                                            .correctIndex
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF333333),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Explanation
                      if (_answered) ...[
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (_selectedAnswer ==
                                    _currentQuestion.correctIndex)
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_selectedAnswer ==
                                      _currentQuestion.correctIndex)
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFFFCC02),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    (_selectedAnswer ==
                                            _currentQuestion.correctIndex)
                                        ? '✅'
                                        : '💡',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (_selectedAnswer ==
                                            _currentQuestion.correctIndex)
                                        ? 'Bonne réponse !'
                                        : 'Explication',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: (_selectedAnswer ==
                                              _currentQuestion.correctIndex)
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFF57F17),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentQuestion.explanation,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Color(0xFF424242),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _answered
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _moduleColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _currentIndex < _totalQuestions - 1
                      ? 'Question suivante →'
                      : 'Voir les résultats 🏆',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
