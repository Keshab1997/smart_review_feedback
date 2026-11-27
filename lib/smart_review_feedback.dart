/// Drop-in Flutter smart rating gate & feedback collector.
///
/// Routes 4–5 star ratings to Google Play / App Store In-App Review and 1–3
/// star ratings to a structured in-app feedback sheet with automatic diagnostics.
library smart_review_feedback;

export 'src/adapters/feedback_sink.dart';
export 'src/adapters/store_review_adapter.dart';
export 'src/controller/smart_review_controller.dart';
export 'src/models/feedback_report.dart';
export 'src/models/review_rules.dart';
export 'src/models/review_strings.dart';
export 'src/storage/review_storage.dart';
export 'src/widgets/smart_review_sheet.dart';
