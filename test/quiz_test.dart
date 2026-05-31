// test/quiz_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ffessm_qcm/models/question.dart';
import 'package:ffessm_qcm/data/quiz_data.dart';

void main() {
  group('QuizModule', () {
    test('tous les modules ont des questions', () {
      for (final module in quizModules) {
        expect(module.questions.isNotEmpty, true,
            reason: '${module.title} doit avoir des questions');
      }
    });

    test('4 modules sont disponibles', () {
      expect(quizModules.length, 4);
    });

    test('les IDs de modules sont uniques', () {
      final ids = quizModules.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('Question', () {
    test('chaque question a 4 options', () {
      for (final module in quizModules) {
        for (final q in module.questions) {
          expect(q.options.length, 4,
              reason: 'Question ${q.id} doit avoir 4 options');
        }
      }
    });

    test('correctIndex est entre 0 et 3', () {
      for (final module in quizModules) {
        for (final q in module.questions) {
          expect(q.correctIndex >= 0 && q.correctIndex <= 3, true,
              reason: 'Question ${q.id} correctIndex invalide');
        }
      }
    });

    test('les IDs de questions sont uniques', () {
      final allIds = quizModules
          .expand((m) => m.questions)
          .map((q) => q.id)
          .toList();
      expect(allIds.toSet().length, allIds.length,
          reason: 'Des IDs de questions sont dupliqués');
    });

    test('aucune question n\'a de champ vide', () {
      for (final module in quizModules) {
        for (final q in module.questions) {
          expect(q.text.isNotEmpty, true);
          expect(q.explanation.isNotEmpty, true);
          expect(q.category.isNotEmpty, true);
          for (final opt in q.options) {
            expect(opt.isNotEmpty, true);
          }
        }
      }
    });
  });

  group('QuizResult', () {
    test('percentage calcul correct', () {
      final result = QuizResult(
        moduleId: 'test',
        moduleTitle: 'Test',
        totalQuestions: 10,
        correctAnswers: 8,
        completedAt: DateTime.now(),
        questionResults: [],
      );
      expect(result.percentage, 80.0);
    });

    test('grade Excellent pour >= 90%', () {
      final result = QuizResult(
        moduleId: 'test',
        moduleTitle: 'Test',
        totalQuestions: 10,
        correctAnswers: 9,
        completedAt: DateTime.now(),
        questionResults: [],
      );
      expect(result.grade, 'Excellent');
    });

    test('grade Bien pour >= 75%', () {
      final result = QuizResult(
        moduleId: 'test',
        moduleTitle: 'Test',
        totalQuestions: 4,
        correctAnswers: 3,
        completedAt: DateTime.now(),
        questionResults: [],
      );
      expect(result.grade, 'Bien');
    });

    test('grade À revoir pour < 60%', () {
      final result = QuizResult(
        moduleId: 'test',
        moduleTitle: 'Test',
        totalQuestions: 10,
        correctAnswers: 5,
        completedAt: DateTime.now(),
        questionResults: [],
      );
      expect(result.grade, 'À revoir');
    });

    test('correctAnswer retourne la bonne option', () {
      final q = quizModules.first.questions.first;
      expect(q.correctAnswer, q.options[q.correctIndex]);
    });
  });

  group('Niveau 1 - PE20', () {
    late QuizModule n1Module;

    setUpAll(() {
      n1Module = quizModules.firstWhere((m) => m.id == 'niveau1');
    });

    test('module niveau1 existe', () {
      expect(n1Module, isNotNull);
    });

    test('au moins 10 questions pour N1', () {
      expect(n1Module.questions.length, greaterThanOrEqualTo(10));
    });

    test('profondeur PE20 est 20m', () {
      final q = n1Module.questions.firstWhere((q) => q.id == 'n1_01');
      expect(q.correctAnswer, contains('20'));
    });
  });

  group('Niveau 4 - GP-N4', () {
    late QuizModule n4Module;

    setUpAll(() {
      n4Module = quizModules.firstWhere((m) => m.id == 'niveau4');
    });

    test('module niveau4 existe', () {
      expect(n4Module, isNotNull);
    });

    test('au moins 12 questions pour N4', () {
      expect(n4Module.questions.length, greaterThanOrEqualTo(12));
    });

    test('âge minimum examen GP-N4 est 17 ans', () {
      final q = n4Module.questions.firstWhere((q) => q.id == 'n4_01');
      expect(q.correctAnswer, contains('17'));
    });

    test('total points examen est 600', () {
      final q = n4Module.questions.firstWhere((q) => q.id == 'n4_12');
      expect(q.correctAnswer, contains('600'));
    });
  });
}
