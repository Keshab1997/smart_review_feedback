import 'package:shared_preferences/shared_preferences.dart';

/// Persisted engagement & cooldown state tracked by [SmartReviewController].
class ReviewStateSnapshot {
  const ReviewStateSnapshot({
    this.firstInstallAtUtc,
    this.launchCount = 0,
    this.positiveEventCount = 0,
    this.lastDismissedAtUtc,
    this.lastFeedbackAtUtc,
    this.storeReviewCompleted = false,
    this.storeReviewedVersion,
  });

  final DateTime? firstInstallAtUtc;
  final int launchCount;
  final int positiveEventCount;
  final DateTime? lastDismissedAtUtc;
  final DateTime? lastFeedbackAtUtc;
  final bool storeReviewCompleted;
  final String? storeReviewedVersion;

  ReviewStateSnapshot copyWith({
    DateTime? firstInstallAtUtc,
    int? launchCount,
    int? positiveEventCount,
    DateTime? lastDismissedAtUtc,
    DateTime? lastFeedbackAtUtc,
    bool? storeReviewCompleted,
    String? storeReviewedVersion,
  }) {
    return ReviewStateSnapshot(
      firstInstallAtUtc: firstInstallAtUtc ?? this.firstInstallAtUtc,
      launchCount: launchCount ?? this.launchCount,
      positiveEventCount: positiveEventCount ?? this.positiveEventCount,
      lastDismissedAtUtc: lastDismissedAtUtc ?? this.lastDismissedAtUtc,
      lastFeedbackAtUtc: lastFeedbackAtUtc ?? this.lastFeedbackAtUtc,
      storeReviewCompleted: storeReviewCompleted ?? this.storeReviewCompleted,
      storeReviewedVersion: storeReviewedVersion ?? this.storeReviewedVersion,
    );
  }
}

/// Persistence interface for [ReviewStateSnapshot].
abstract class ReviewStorage {
  Future<ReviewStateSnapshot> read();
  Future<void> write(ReviewStateSnapshot snapshot);
  Future<void> clear();
}

/// Default persistent storage backed by [SharedPreferences].
class SharedPrefsReviewStorage implements ReviewStorage {
  SharedPrefsReviewStorage({
    this.keyPrefix = 'smart_review_feedback',
    SharedPreferences? preferences,
  }) : _prefs = preferences;

  final String keyPrefix;
  SharedPreferences? _prefs;

  String get _kInstall => '${keyPrefix}_install_ms';
  String get _kLaunches => '${keyPrefix}_launches';
  String get _kEvents => '${keyPrefix}_positive_events';
  String get _kDismissed => '${keyPrefix}_dismissed_ms';
  String get _kFeedback => '${keyPrefix}_feedback_ms';
  String get _kStoreDone => '${keyPrefix}_store_done';
  String get _kStoreVer => '${keyPrefix}_store_ver';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<ReviewStateSnapshot> read() async {
    final prefs = await _getPrefs();
    return ReviewStateSnapshot(
      firstInstallAtUtc: _fromMs(prefs.getInt(_kInstall)),
      launchCount: prefs.getInt(_kLaunches) ?? 0,
      positiveEventCount: prefs.getInt(_kEvents) ?? 0,
      lastDismissedAtUtc: _fromMs(prefs.getInt(_kDismissed)),
      lastFeedbackAtUtc: _fromMs(prefs.getInt(_kFeedback)),
      storeReviewCompleted: prefs.getBool(_kStoreDone) ?? false,
      storeReviewedVersion: prefs.getString(_kStoreVer),
    );
  }

  @override
  Future<void> write(ReviewStateSnapshot snapshot) async {
    final prefs = await _getPrefs();
    if (snapshot.firstInstallAtUtc != null) {
      await prefs.setInt(
        _kInstall,
        snapshot.firstInstallAtUtc!.toUtc().millisecondsSinceEpoch,
      );
    }
    await prefs.setInt(_kLaunches, snapshot.launchCount);
    await prefs.setInt(_kEvents, snapshot.positiveEventCount);
    if (snapshot.lastDismissedAtUtc != null) {
      await prefs.setInt(
        _kDismissed,
        snapshot.lastDismissedAtUtc!.toUtc().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_kDismissed);
    }
    if (snapshot.lastFeedbackAtUtc != null) {
      await prefs.setInt(
        _kFeedback,
        snapshot.lastFeedbackAtUtc!.toUtc().millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_kFeedback);
    }
    await prefs.setBool(_kStoreDone, snapshot.storeReviewCompleted);
    if (snapshot.storeReviewedVersion != null) {
      await prefs.setString(_kStoreVer, snapshot.storeReviewedVersion!);
    } else {
      await prefs.remove(_kStoreVer);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPrefs();
    for (final String key in <String>[
      _kInstall,
      _kLaunches,
      _kEvents,
      _kDismissed,
      _kFeedback,
      _kStoreDone,
      _kStoreVer,
    ]) {
      await prefs.remove(key);
    }
  }

  DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// Ephemeral storage ideal for unit/widget tests.
class InMemoryReviewStorage implements ReviewStorage {
  ReviewStateSnapshot _state = const ReviewStateSnapshot();

  @override
  Future<ReviewStateSnapshot> read() async => _state;

  @override
  Future<void> write(ReviewStateSnapshot snapshot) async {
    _state = snapshot;
  }

  @override
  Future<void> clear() async {
    _state = const ReviewStateSnapshot();
  }
}
