import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../adapters/feedback_sink.dart';
import '../adapters/store_review_adapter.dart';
import '../models/feedback_report.dart';
import '../models/review_rules.dart';
import '../models/review_strings.dart';
import '../storage/review_storage.dart';
import '../widgets/smart_review_sheet.dart';

/// Clock callback for deterministic testing.
typedef ReviewClock = DateTime Function();

/// Outcome returned when [SmartReviewSheet] closes.
enum SmartReviewOutcome {
  /// User dismissed or tapped "Not now".
  dismissed,

  /// User gave a high rating and was routed to the store review flow.
  routedToStore,

  /// User gave a lower rating and submitted improvement feedback.
  submittedFeedback,
}

/// Central controller tracking engagement milestones, evaluating eligibility
/// rules, routing high ratings to store review, and sending lower-rating
/// feedback with automatic diagnostics.
class SmartReviewController extends ChangeNotifier {
  SmartReviewController({
    required this.feedbackSink,
    this.rules = const ReviewTriggerRules(),
    ReviewStorage? storage,
    StoreReviewAdapter? storeAdapter,
    this.appName,
    this.appVersion,
    this.buildNumber,
    this.androidPackageName,
    this.appStoreId,
    this.fallbackStoreUrl,
    ReviewClock? clock,
  })  : storage = storage ?? SharedPrefsReviewStorage(),
        storeAdapter = storeAdapter ?? InAppReviewAdapter(),
        _clock = clock ?? DateTime.now;

  final FeedbackSink feedbackSink;
  final ReviewTriggerRules rules;
  final ReviewStorage storage;
  final StoreReviewAdapter storeAdapter;

  final String? appName;
  final String? appVersion;
  final String? buildNumber;
  final String? androidPackageName;
  final String? appStoreId;
  final String? fallbackStoreUrl;
  final ReviewClock _clock;

  ReviewStateSnapshot _state = const ReviewStateSnapshot();
  bool _isInitialized = false;
  bool _disposed = false;

  String _resolvedAppName = 'App';
  String _resolvedVersion = '0.0.0';
  String _resolvedBuild = '0';
  String? _resolvedPackageName;

  ReviewStateSnapshot get state => _state;
  bool get isInitialized => _isInitialized;
  String get resolvedAppName => _resolvedAppName;
  String get resolvedVersion => _resolvedVersion;
  String get resolvedBuild => _resolvedBuild;

  /// Loads persisted counters, records the first-install timestamp if missing,
  /// optionally increments the app launch counter, and reads package info.
  Future<void> init({bool recordLaunch = true}) async {
    await _resolvePackageInfo();
    _state = await storage.read();
    final now = _clock().toUtc();
    var updated = _state;
    if (updated.firstInstallAtUtc == null) {
      updated = updated.copyWith(firstInstallAtUtc: now);
    }
    if (recordLaunch) {
      updated = updated.copyWith(launchCount: updated.launchCount + 1);
    }
    _state = updated;
    await storage.write(_state);
    _isInitialized = true;
    _safeNotify();
  }

  /// Records a happy/positive user action (e.g. saved entry, finished quiz,
  /// exported PDF). Call this before [maybePrompt].
  Future<void> recordPositiveEvent({int count = 1}) async {
    if (count <= 0) return;
    _state = _state.copyWith(
      positiveEventCount: _state.positiveEventCount + count,
    );
    await storage.write(_state);
    _safeNotify();
  }

  /// Evaluates whether the user currently satisfies all [rules] for an
  /// automatic rating prompt.
  bool get shouldPromptNow {
    final now = _clock().toUtc();

    if (_state.storeReviewCompleted && rules.neverAskAgainAfterStoreReview) {
      final versionChanged = rules.askAgainOnNewVersion &&
          _state.storeReviewedVersion != null &&
          _state.storeReviewedVersion != _resolvedVersion;
      if (!versionChanged) return false;
    }

    if (_state.launchCount < rules.minLaunchCount) return false;
    if (_state.positiveEventCount < rules.minPositiveEvents) return false;

    final installAt = _state.firstInstallAtUtc;
    if (installAt != null) {
      final daysElapsed = now.difference(installAt.toUtc()).inDays;
      if (daysElapsed < rules.minDaysSinceInstall) return false;
    } else if (rules.minDaysSinceInstall > 0) {
      return false;
    }

    final lastDismiss = _state.lastDismissedAtUtc;
    if (lastDismiss != null &&
        now.difference(lastDismiss.toUtc()) < rules.cooldownAfterDismiss) {
      return false;
    }

    final lastFeedback = _state.lastFeedbackAtUtc;
    if (lastFeedback != null &&
        now.difference(lastFeedback.toUtc()) < rules.cooldownAfterFeedback) {
      return false;
    }

    return true;
  }

  /// Shows [SmartReviewSheet] ONLY if [shouldPromptNow] is `true`.
  ///
  /// Returns `null` if the user is not currently eligible.
  Future<SmartReviewOutcome?> maybePrompt(
    BuildContext context, {
    ReviewStrings? strings,
    String? screenName,
    Map<String, Object?> extraDiagnostics = const <String, Object?>{},
  }) async {
    if (!shouldPromptNow) return null;
    return showNow(
      context,
      strings: strings,
      screenName: screenName,
      extraDiagnostics: extraDiagnostics,
    );
  }

  /// Opens [SmartReviewSheet] immediately regardless of cooldowns (ideal for a
  /// Settings -> "Rate & Feedback" button).
  Future<SmartReviewOutcome> showNow(
    BuildContext context, {
    ReviewStrings? strings,
    String? screenName,
    Map<String, Object?> extraDiagnostics = const <String, Object?>{},
  }) async {
    final resolvedStrings = strings ?? ReviewStrings.en(appName: _resolvedAppName);
    final outcome = await SmartReviewSheet.show(
      context,
      controller: this,
      strings: resolvedStrings,
      screenName: screenName,
      extraDiagnostics: extraDiagnostics,
    );
    if (outcome == null || outcome == SmartReviewOutcome.dismissed) {
      await markDismissed();
      return SmartReviewOutcome.dismissed;
    }
    return outcome;
  }

  /// Triggers the store review flow (native In-App Review, falling back to
  /// store listing URL) and records completion.
  Future<bool> triggerStoreReview() async {
    var invoked = await storeAdapter.requestInAppReview();
    if (!invoked) {
      invoked = await storeAdapter.openStoreListing(
        androidPackageName: androidPackageName ?? _resolvedPackageName,
        appStoreId: appStoreId,
        fallbackUrl: fallbackStoreUrl,
      );
    }
    _state = _state.copyWith(
      storeReviewCompleted: true,
      storeReviewedVersion: _resolvedVersion,
    );
    await storage.write(_state);
    _safeNotify();
    return invoked;
  }

  /// Opens the public store listing directly (e.g. "Rate on Store" CTA).
  Future<bool> openStoreListing() {
    return storeAdapter.openStoreListing(
      androidPackageName: androidPackageName ?? _resolvedPackageName,
      appStoreId: appStoreId,
      fallbackUrl: fallbackStoreUrl,
    );
  }

  /// Builds a [FeedbackReport] with automatic [ReviewDiagnostics] and delivers
  /// it to [feedbackSink].
  Future<FeedbackReport> submitFeedback({
    required int rating,
    required String message,
    List<String> categories = const <String>[],
    String? contact,
    String? screenName,
    String? locale,
    Map<String, Object?> extraDiagnostics = const <String, Object?>{},
  }) async {
    final now = _clock().toUtc();
    final report = FeedbackReport(
      rating: rating,
      categories: List<String>.unmodifiable(categories),
      message: message.trim(),
      contact: contact?.trim().isEmpty == true ? null : contact?.trim(),
      diagnostics: ReviewDiagnostics(
        appName: _resolvedAppName,
        appVersion: _resolvedVersion,
        buildNumber: _resolvedBuild,
        platform: defaultTargetPlatform.name,
        submittedAtUtc: now,
        screenName: screenName,
        locale: locale,
        extras: extraDiagnostics,
      ),
    );
    await feedbackSink.send(report);
    _state = _state.copyWith(lastFeedbackAtUtc: now);
    await storage.write(_state);
    _safeNotify();
    return report;
  }

  /// Records a dismissal timestamp to enforce [ReviewTriggerRules.cooldownAfterDismiss].
  Future<void> markDismissed() async {
    _state = _state.copyWith(lastDismissedAtUtc: _clock().toUtc());
    await storage.write(_state);
    _safeNotify();
  }

  /// Clears all persisted counters & cooldowns (useful for QA testing).
  Future<void> reset() async {
    await storage.clear();
    _state = const ReviewStateSnapshot();
    _safeNotify();
  }

  Future<void> _resolvePackageInfo() async {
    _resolvedAppName = appName ?? _resolvedAppName;
    _resolvedVersion = appVersion ?? _resolvedVersion;
    _resolvedBuild = buildNumber ?? _resolvedBuild;
    _resolvedPackageName = androidPackageName;

    if (appName != null && appVersion != null && buildNumber != null) {
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      if (appName == null && info.appName.trim().isNotEmpty) {
        _resolvedAppName = info.appName.trim();
      }
      if (appVersion == null && info.version.trim().isNotEmpty) {
        _resolvedVersion = info.version.trim();
      }
      if (buildNumber == null && info.buildNumber.trim().isNotEmpty) {
        _resolvedBuild = info.buildNumber.trim();
      }
      if (_resolvedPackageName == null && info.packageName.trim().isNotEmpty) {
        _resolvedPackageName = info.packageName.trim();
      }
    } catch (_) {
      // Safe fallback in unit tests without native channel.
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Optional singleton convenience facade for one-line setup:
/// `await SmartReview.init(feedbackSink: ...)`
class SmartReview {
  SmartReview._();

  static SmartReviewController? _instance;

  static SmartReviewController get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'SmartReview has not been initialized. Call SmartReview.init(...) first.',
      );
    }
    return current;
  }

  static bool get isConfigured => _instance != null;

  static Future<SmartReviewController> init({
    required FeedbackSink feedbackSink,
    ReviewTriggerRules rules = const ReviewTriggerRules(),
    ReviewStorage? storage,
    StoreReviewAdapter? storeAdapter,
    String? appName,
    String? appVersion,
    String? buildNumber,
    String? androidPackageName,
    String? appStoreId,
    String? fallbackStoreUrl,
    bool recordLaunch = true,
  }) async {
    final controller = SmartReviewController(
      feedbackSink: feedbackSink,
      rules: rules,
      storage: storage,
      storeAdapter: storeAdapter,
      appName: appName,
      appVersion: appVersion,
      buildNumber: buildNumber,
      androidPackageName: androidPackageName,
      appStoreId: appStoreId,
      fallbackStoreUrl: fallbackStoreUrl,
    );
    _instance?.dispose();
    _instance = controller;
    await controller.init(recordLaunch: recordLaunch);
    return controller;
  }

  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
