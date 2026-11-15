import 'package:flutter_test/flutter_test.dart';
import 'package:safe_to_spend/services/category_classifier.dart';
import 'package:safe_to_spend/models/transaction_model.dart';

TransactionModel _tx(String note, String category) => TransactionModel(
      id: 't-${note.hashCode}',
      amount: 100,
      type: TransactionType.expense,
      category: category,
      date: DateTime.now(),
      note: note,
      createdAt: DateTime.now(),
    );

void main() {
  group('CategoryClassifier (Naive Bayes)', () {
    test('tokenizes, lowercases, strips punctuation, drops stop words', () {
      final tokens = CategoryClassifier.tokenize(
          'Spent 250 on Biryani, at Behrouz! #dinner');
      expect(tokens, containsAll(['biryani', 'behrouz', 'dinner']));
      expect(tokens, isNot(contains('on')));
      expect(tokens, isNot(contains('spent')));
    });

    test('classifies unseen notes from learned word probabilities', () {
      final c = CategoryClassifier();
      c.trainFrom([
        _tx('biryani lunch', 'food'),
        _tx('swiggy dinner', 'food'),
        _tx('pizza margherita', 'food'),
        _tx('ola ride to office', 'transport'),
        _tx('metro card recharge', 'transport'),
        _tx('petrol for bike', 'transport'),
        _tx('milk and vegetables', 'groceries'),
        _tx('zepto kirana order', 'groceries'),
      ]);

      // Words never seen in the keyword map — pure ML inference.
      final r1 = c.classify('behrouz kebab feast');
      expect(r1, isNotNull);
      expect(r1!.category, 'food');

      final r2 = c.classify('rapido bike taxi');
      expect(r2!.category, 'transport');

      final r3 = c.classify('blinkit milk delivery');
      expect(r3!.category, 'groceries');
    });

    test('confidence rises with more on-topic words', () {
      final c = CategoryClassifier();
      c.trainFrom([
        _tx('biryani', 'food'),
        _tx('swiggy biryani order', 'food'),
        _tx('ola ride', 'transport'),
        _tx('metro ride', 'transport'),
      ]);
      final weak = c.classify('zomato')!;
      final strong = c.classify('zomato biryani dinner swiggy')!;
      expect(strong.confidence, greaterThan(weak.confidence));
    });

    test('hybrid guess prefers keywords, falls back to model, then other', () {
      final c = CategoryClassifier();
      c.trainFrom([
        _tx('biryani', 'food'),
        _tx('behrouz kebab feast', 'food'),
        _tx('swiggy biryani order', 'food'),
        _tx('ola ride', 'transport'),
        _tx('metro ride', 'transport'),
      ]);
      // keyword hit wins even though model says food too
      expect(c.guessWithFallback('spent 60 on coffee', (t) => 'food'), 'food');
      // model rescue when keywords are silent (learned word: kebab)
      expect(c.guessWithFallback('kebab special', (t) => 'other'), 'food');
      // completely unknown vocabulary, weak prior signal -> other
      expect(c.guessWithFallback('random xyzzy stuff', (t) => 'other'), 'other');
    });

    test('correction records (_learn:) persist and outweigh old examples', () {
      final c = CategoryClassifier();
      c.trainFrom([
        _tx('biryani', 'food'),
        _tx('rapido', 'transport'),
        // user corrected: "kebab was food" → stored as _learn record
        _tx('_learn: kebab platter', 'food'),
      ]);
      final r = c.classify('kebab platter with naan')!;
      expect(r.category, 'food');
      expect(r.confidence, greaterThan(0.25));
    });

    test("'other' transactions never poison the vocabulary", () {
      final c = CategoryClassifier();
      c.trainFrom([
        _tx('random junk', 'other'),
        _tx('unknown thing', 'other'),
      ]);
      expect(c.isTrained, isFalse); // nothing learnable
      expect(c.classify('random junk'), isNull);
    });

    test('untrained model never guesses', () {
      final c = CategoryClassifier();
      expect(c.classify('biryani'), isNull);
      expect(c.isTrained, isFalse);
      expect(c.guessWithFallback('biryani', (t) => 'other'), 'other');
    });

    test('income transactions are not used for training', () {
      final c = CategoryClassifier();
      c.learn('salary credit november', 'food', isExpense: false);
      expect(c.isTrained, isFalse);
    });

    test('empty and punctuation-only notes are ignored safely', () {
      final c = CategoryClassifier();
      c.learn('', 'food');
      c.learn('!!!', 'food');
      c.learn('the of and', 'food');
      expect(c.isTrained, isFalse);
    });
  });
}
