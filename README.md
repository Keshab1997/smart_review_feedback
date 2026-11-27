# `smart_review_feedback`

Drop-in Flutter **smart rating gate & feedback collector** — routes **4–5 star** users to Google Play / App Store In-App Review and **1–3 star** users to a structured in-app feedback sheet with **automatic app & device diagnostics** — with built-in **English & Bengali (বাংলা)** UI.

---

## Why `smart_review_feedback`?

- **Protect your Play Store rating**: Happy users get a smooth path to the native Google Play / App Store review sheet; unhappy users get heard directly inside your app instead of leaving a 1-star public review.
- **Smart timing (never nags)**: Only prompts after configurable milestones (default: `3+ days`, `3+ launches`, `5+ happy actions`) with automatic dismiss & feedback cooldowns.
- **Zero backend lock-in**:
  - `CallbackFeedbackSink` — plug **Firestore / Supabase** in 3 lines (zero Firebase bloat!)
  - `WebhookFeedbackSink` — POST JSON to Cloudflare Worker, Discord, Slack, Make, n8n, or Google Apps Script
  - `TelegramFeedbackSink` — instant Telegram Bot notifications
  - `EmailFeedbackSink` — zero-server `mailto:` fallback
  - `MultiFeedbackSink` — send to multiple destinations at once
- **Auto diagnostics**: Every feedback report automatically includes app name, version, build number, platform, screen name, locale, and UTC timestamp.
- **Built-in EN & বাংলা UI**: Use `ReviewStrings.en()` or `ReviewStrings.bn()`.

---

## Installation

Add directly from GitHub in your app's `pubspec.yaml`:

```yaml
dependencies:
  smart_review_feedback:
    git:
      url: https://github.com/Keshab1997/smart_review_feedback.git
```

---

## Quick Start (3 Steps)

### 1. Initialize once in `main()`

```dart
import 'package:smart_review_feedback/smart_review_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SmartReview.init(
    // Pick ANY sink: Webhook, Email, Telegram, or Firestore Callback!
    feedbackSink: const EmailFeedbackSink(toEmail: 'support@example.com'),
    rules: const ReviewTriggerRules(
      minDaysSinceInstall: 3,
      minLaunchCount: 3,
      minPositiveEvents: 5,
    ),
  );

  runApp(const MyApp());
}
```

### 2. Trigger at a happy moment

```dart
// e.g. after saving a khata entry, completing a quiz, or scanning a document:
await SmartReview.instance.recordPositiveEvent();
if (context.mounted) {
  await SmartReview.instance.maybePrompt(
    context,
    strings: const ReviewStrings.bn(appName: 'খরচ ডায়েরি'), // or ReviewStrings.en()
    screenName: 'AddEntryScreen',
  );
}
```

### 3. Add a manual "Rate & Feedback" button in Settings

```dart
ListTile(
  leading: const Icon(Icons.star_rate_rounded),
  title: const Text('Rate & Feedback'),
  onTap: () => SmartReview.instance.showNow(
    context,
    screenName: 'SettingsScreen',
  ),
)
```

---

## Firestore Example (3 lines, no Firebase dependency in package)

```dart
await SmartReview.init(
  feedbackSink: CallbackFeedbackSink((FeedbackReport report) async {
    await FirebaseFirestore.instance
        .collection('app_feedback')
        .add(report.toJson());
  }),
);
```

---

## License

MIT © Keshab Sarkar
