import 'package:flutter/foundation.dart';

/// Eligibility thresholds and cooldowns controlling when [SmartReviewController]
/// automatically prompts the user.
@immutable
class ReviewTriggerRules {
  const ReviewTriggerRules({
    this.minDaysSinceInstall = 3,
    this.minLaunchCount = 3,
    this.minPositiveEvents = 5,
    this.minStoreRating = 4,
    this.cooldownAfterDismiss = const Duration(days: 30),
    this.cooldownAfterFeedback = const Duration(days: 90),
    this.neverAskAgainAfterStoreReview = true,
    this.askAgainOnNewVersion = false,
  })  : assert(minDaysSinceInstall >= 0),
        assert(minLaunchCount >= 0),
        assert(minPositiveEvents >= 0),
        assert(minStoreRating >= 1 && minStoreRating <= 5);

  /// Minimum days elapsed since the first recorded app launch.
  final int minDaysSinceInstall;

  /// Minimum number of recorded app launches.
  final int minLaunchCount;

  /// Minimum number of recorded positive/happy moments (e.g. completed quiz,
  /// saved entry, exported file).
  final int minPositiveEvents;

  /// Star rating threshold (inclusive) that routes to the official store review
  /// flow instead of the in-app improvement feedback sheet (default: 4).
  final int minStoreRating;

  /// Quiet period after the user taps "Not now" or dismisses the sheet.
  final Duration cooldownAfterDismiss;

  /// Quiet period after the user submits 1–3 star improvement feedback.
  final Duration cooldownAfterFeedback;

  /// If `true`, do not automatically prompt again after sending the user to the
  /// store review flow (unless [askAgainOnNewVersion] triggers on a newer version).
  final bool neverAskAgainAfterStoreReview;

  /// If `true`, a new installed app version resets store-review completion so
  /// loyal users may be gently asked again after a major upgrade.
  final bool askAgainOnNewVersion;
}
