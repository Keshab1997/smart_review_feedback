import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_review_feedback/smart_review_feedback.dart';

void main() {
  group('SmartReviewSheet', () {
    testWidgets('5-star rating routes to Store Review adapter',
        (WidgetTester tester) async {
      final sink = MemoryFeedbackSink();
      final store = FakeStoreReviewAdapter();
      final ctrl = SmartReviewController(
        feedbackSink: sink,
        storage: InMemoryReviewStorage(),
        storeAdapter: store,
        appName: 'Quizbaaz',
        appVersion: '2.0.0',
        buildNumber: '20',
      );
      await ctrl.init();

      SmartReviewOutcome? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) => FilledButton(
                onPressed: () async {
                  outcome = await ctrl.showNow(ctx);
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('review_star_5')));
      await tester.pump();
      expect(find.text('Love it!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(store.requestReviewCalls, 1);
      expect(sink.reports, isEmpty);
      expect(find.text('Thank you!'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(outcome, SmartReviewOutcome.routedToStore);
      ctrl.dispose();
    });

    testWidgets('2-star rating opens Bangla feedback form and submits report',
        (WidgetTester tester) async {
      final sink = MemoryFeedbackSink();
      final store = FakeStoreReviewAdapter();
      final ctrl = SmartReviewController(
        feedbackSink: sink,
        storage: InMemoryReviewStorage(),
        storeAdapter: store,
        appName: 'খরচ ডায়েরি',
        appVersion: '1.2.0',
        buildNumber: '12',
      );
      await ctrl.init();

      SmartReviewOutcome? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) => FilledButton(
                onPressed: () async {
                  outcome = await ctrl.showNow(
                    ctx,
                    strings: const ReviewStrings.bn(appName: 'খরচ ডায়েরি'),
                    screenName: 'AddEntryScreen',
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('review_star_2')));
      await tester.pump();
      await tester.tap(find.text('এগিয়ে যান'));
      await tester.pumpAndSettle();

      expect(store.requestReviewCalls, 0);
      expect(find.text('আমাদের আরও ভালো হতে সাহায্য করুন'), findsOneWidget);

      await tester.tap(find.text('স্লো চলছে'));
      await tester.enterText(
        find.byKey(const ValueKey<String>('feedback_message_field')),
        'Backup button slow',
      );
      await tester.tap(find.text('মতামত পাঠান'));
      await tester.pumpAndSettle();

      expect(sink.reports, hasLength(1));
      expect(sink.reports.single.rating, 2);
      expect(sink.reports.single.categories, contains('স্লো চলছে'));
      expect(sink.reports.single.diagnostics.screenName, 'AddEntryScreen');
      expect(find.text('অসংখ্য ধন্যবাদ!'), findsOneWidget);

      await tester.tap(find.text('ঠিক আছে'));
      await tester.pumpAndSettle();
      expect(outcome, SmartReviewOutcome.submittedFeedback);
      ctrl.dispose();
    });
  });
}
