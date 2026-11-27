import 'package:flutter/foundation.dart';

/// Non-PII diagnostic metadata automatically attached to a [FeedbackReport].
@immutable
class ReviewDiagnostics {
  const ReviewDiagnostics({
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.submittedAtUtc,
    this.screenName,
    this.locale,
    this.extras = const <String, Object?>{},
  });

  final String appName;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final DateTime submittedAtUtc;
  final String? screenName;
  final String? locale;
  final Map<String, Object?> extras;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appName': appName,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'platform': platform,
      'submittedAtUtc': submittedAtUtc.toUtc().toIso8601String(),
      if (screenName != null && screenName!.isNotEmpty) 'screenName': screenName,
      if (locale != null && locale!.isNotEmpty) 'locale': locale,
      if (extras.isNotEmpty) 'extras': extras,
    };
  }

  String toSummaryString() {
    final parts = <String>[
      '$appName v$appVersion+$buildNumber',
      'Platform: $platform',
      if (screenName != null && screenName!.isNotEmpty) 'Screen: $screenName',
      if (locale != null && locale!.isNotEmpty) 'Locale: $locale',
      'UTC: ${submittedAtUtc.toUtc().toIso8601String()}',
    ];
    return parts.join(' | ');
  }
}

/// Structured improvement feedback submitted by a user from [SmartReviewSheet].
@immutable
class FeedbackReport {
  const FeedbackReport({
    required this.rating,
    required this.message,
    required this.diagnostics,
    this.categories = const <String>[],
    this.contact,
  });

  /// Selected star rating (1–5).
  final int rating;

  /// Selected issue categories (e.g. `Bug / Crash`, `Slow`).
  final List<String> categories;

  /// Free-text user message.
  final String message;

  /// Optional user contact (email or phone) if provided.
  final String? contact;

  /// Auto-attached app & platform diagnostics.
  final ReviewDiagnostics diagnostics;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rating': rating,
      'categories': categories,
      'message': message,
      if (contact != null && contact!.trim().isNotEmpty)
        'contact': contact!.trim(),
      'diagnostics': diagnostics.toJson(),
    };
  }

  /// Human-readable summary suitable for Telegram, Slack, Discord, or email.
  String toFormattedText() {
    final stars = List<String>.filled(rating.clamp(0, 5), '★').join();
    final buf = StringBuffer()
      ..writeln('${diagnostics.appName} — $rating/5 $stars')
      ..writeln('Version: v${diagnostics.appVersion}+${diagnostics.buildNumber} (${diagnostics.platform})');
    if (categories.isNotEmpty) {
      buf.writeln('Tags: ${categories.join(', ')}');
    }
    if (diagnostics.screenName != null && diagnostics.screenName!.isNotEmpty) {
      buf.writeln('Screen: ${diagnostics.screenName}');
    }
    buf
      ..writeln('')
      ..writeln(message.trim().isEmpty ? '(no comment provided)' : message.trim());
    if (contact != null && contact!.trim().isNotEmpty) {
      buf
        ..writeln('')
        ..writeln('Contact: ${contact!.trim()}');
    }
    return buf.toString().trim();
  }
}
