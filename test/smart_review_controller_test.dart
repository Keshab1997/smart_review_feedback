import 'package:flutter_test/flutter_test.dart';
import 'package:smart_review_feedback/smart_review_feedback.dart';

void main() {
  group('SmartReviewController', () {
    test('enforces minDays, minLaunches, minPositiveEvents and cooldowns',
        () async {
      var now = DateTime.utc(2026, 11, 1, 10, 0);
      final storage = InMemoryReviewStorage();
      final sink = MemoryFeedbackSink();
      final store = FakeStoreReviewAdapter();

      SmartReviewController makeCtrl({String version = '1.0.0'}) =>
          SmartReviewController(
            feedbackSink: sink,
            storage: storage,
            storeAdapter: store,
            appName: 'DemoApp',
            appVersion: version,
            buildNumber: '1',
            rules: const ReviewTriggerRules(
              minDaysSinceInstall: 3,
              minLaunchCount: 2,
              minPositiveEvents: 3,
              cooldownAfterDismiss: Duration(days: 14),
              cooldownAfterFeedback: Duration(days: 60),
              askAgainOnNewVersion: true,
            ),
            clock: () => now,
          );

      // Day 0, launch 1 -> not eligible.
      final c1 = makeCtrl();
      await c1.init();
      await c1.recordPositiveEvent(count: 3);
      expect(c1.shouldPromptNow, isFalse);
      c1.dispose();

      // Day 4, launch 2 -> eligible!
      now = now.add(const Duration(days: 4));
      final c2 = makeCtrl();
      await c2.init();
      expect(c2.shouldPromptNow, isTrue);

      // Dismiss -> cooled down for 14 days.
      await c2.markDismissed();
      expect(c2.shouldPromptNow, isFalse);

      now = now.add(const Duration(days: 15));
      expect(c2.shouldPromptNow, isTrue);

      // Submit 2-star feedback -> cooled down for 60 days.
      final report = await c2.submitFeedback(
        rating: 2,
        categories: const <String>['Slow'],
        message: 'Startup feels slow',
        screenName: 'HomeScreen',
      );
      expect(sink.reports, hasLength(1));
      expect(report.diagnostics.appVersion, '1.0.0');
      expect(report.diagnostics.screenName, 'HomeScreen');
      expect(c2.shouldPromptNow, isFalse);

      // After 61 days -> eligible again.
      now = now.add(const Duration(days: 61));
      expect(c2.shouldPromptNow, isTrue);

      // Trigger store review -> stops prompting on same version.
      await c2.triggerStoreReview();
      expect(store.requestReviewCalls, 1);
      expect(c2.shouldPromptNow, isFalse);
      c2.dispose();

      // On new app version (askAgainOnNewVersion=true) -> eligible again.
      final c3 = makeCtrl(version: '1.1.0');
      await c3.init(recordLaunch: false);
      expect(c3.shouldPromptNow, isTrue);
      c3.dispose();
    });

    test('falls back to openStoreListing when in-app review is unavailable',
        () async {
      final store = FakeStoreReviewAdapter(inAppAvailable: false);
      final ctrl = SmartReviewController(
        feedbackSink: MemoryFeedbackSink(),
        storage: InMemoryReviewStorage(),
        storeAdapter: store,
        appName: 'Demo',
        appVersion: '1.0.0',
        buildNumber: '1',
        fallbackStoreUrl: 'https://play.google.com/store/apps/details?id=a.b',
      );
      await ctrl.init();

      final ok = await ctrl.triggerStoreReview();
      expect(ok, isTrue);
      expect(store.requestReviewCalls, 1);
      expect(store.openStoreListingCalls, 1);
      expect(
        store.lastFallbackUrl,
        'https://play.google.com/store/apps/details?id=a.b',
      );
      ctrl.dispose();
    });
  });
}
