# AGENTS.md — `smart_review_feedback`

## Package Overview
`smart_review_feedback` is a lightweight, zero-backend-lock-in Flutter package providing:
1. Engagement-aware rating eligibility rules (`ReviewTriggerRules`)
2. 2-step Material 3 rating + feedback bottom sheet (`SmartReviewSheet`)
3. Google Play / App Store In-App Review routing for 4–5 star ratings
4. In-app improvement feedback with automatic `ReviewDiagnostics` for 1–3 star ratings
5. Pluggable sinks (`CallbackFeedbackSink`, `WebhookFeedbackSink`, `TelegramFeedbackSink`, `EmailFeedbackSink`, `MultiFeedbackSink`)
6. Built-in English (`ReviewStrings.en`) and Bengali (`ReviewStrings.bn`) UI copy

## Check Policy
| Change | Check |
|---|---|
| Anything | `python3 tool/preflight.py` |
| Single Dart edit | `flutter test test/<name>_test.dart` |
| Shared surface | `flutter analyze --fatal-infos` + `flutter test` |

## Package Guardrails
- Do **not** add `cloud_firestore` or `firebase_core` as hard dependencies — Firestore apps connect in 3 lines via `CallbackFeedbackSink`.
- Keep `deprecated_member_use: ignore` in `analysis_options.yaml` until host apps migrate off `package:flutter/material.dart`.
