# Changelog

## 0.1.0 - 2026-11-27

Initial release of `smart_review_feedback`:

- **Smart Trigger Gate (`ReviewTriggerRules`)**: Configurable minimum days since install, launch count, positive event count, dismiss/feedback cooldowns, and optional re-prompt on new app versions.
- **2-Step Material 3 Sheet (`SmartReviewSheet`)**: Interactive 1–5 star prompt routing 4–5 star ratings to Google Play / App Store In-App Review (with store URL fallback) and 1–3 star ratings to a structured in-app feedback form.
- **Auto Diagnostics (`ReviewDiagnostics`)**: Automatically attaches app version, build number, platform, screen name, and UTC timestamp to feedback reports.
- **Pluggable Sinks (`FeedbackSink`)**: Built-in `CallbackFeedbackSink` (3-line Firestore/Supabase wiring), `WebhookFeedbackSink`, `TelegramFeedbackSink`, `EmailFeedbackSink`, `MultiFeedbackSink`, and `MemoryFeedbackSink`.
- **Built-in EN + বাংলা UI**: `ReviewStrings.en()` and `ReviewStrings.bn()`.
