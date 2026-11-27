import 'package:flutter/foundation.dart';

/// User-facing strings for [SmartReviewSheet].
///
/// Includes built-in [ReviewStrings.en] (English) and [ReviewStrings.bn]
/// (Bengali / বাংলা) presets.
@immutable
class ReviewStrings {
  const ReviewStrings({
    required this.rateTitle,
    required this.rateSubtitle,
    required this.starLabels,
    required this.continueButton,
    required this.notNowButton,
    required this.feedbackTitle,
    required this.feedbackSubtitle,
    required this.categories,
    required this.messageHint,
    required this.contactHint,
    required this.diagnosticsNote,
    required this.submitButton,
    required this.submittingLabel,
    required this.backButton,
    required this.thankYouTitle,
    required this.thankYouFeedbackMessage,
    required this.thankYouStoreMessage,
    required this.openStoreButton,
    required this.doneButton,
    required this.submitErrorMessage,
    required this.emptyMessageError,
  }) : assert(starLabels.length == 5);

  final String rateTitle;
  final String rateSubtitle;
  final List<String> starLabels;
  final String continueButton;
  final String notNowButton;

  final String feedbackTitle;
  final String feedbackSubtitle;
  final List<String> categories;
  final String messageHint;
  final String contactHint;
  final String diagnosticsNote;
  final String submitButton;
  final String submittingLabel;
  final String backButton;

  final String thankYouTitle;
  final String thankYouFeedbackMessage;
  final String thankYouStoreMessage;
  final String openStoreButton;
  final String doneButton;
  final String submitErrorMessage;
  final String emptyMessageError;

  /// Default English copy.
  const ReviewStrings.en({String appName = 'this app'})
      : rateTitle = 'Enjoying $appName?',
        rateSubtitle = 'Tap a star to let us know how your experience has been.',
        starLabels = const <String>[
          'Needs work',
          'Could be better',
          'It is okay',
          'Really good!',
          'Love it!',
        ],
        continueButton = 'Continue',
        notNowButton = 'Not now',
        feedbackTitle = 'Help us improve',
        feedbackSubtitle =
            'Sorry it was not a 5-star experience. Tell us what we should fix.',
        categories = const <String>[
          'Bug / Crash',
          'Slow',
          'Missing feature',
          'Design / UI',
          'Other',
        ],
        messageHint = 'What went wrong or what would make it better?',
        contactHint = 'Email or phone (optional, if you want a reply)',
        diagnosticsNote = 'App version and device info are attached automatically.',
        submitButton = 'Send feedback',
        submittingLabel = 'Sending...',
        backButton = 'Back',
        thankYouTitle = 'Thank you!',
        thankYouFeedbackMessage =
            'Your feedback has been sent directly to the developer.',
        thankYouStoreMessage =
            'We are glad you love it! A quick rating on the store helps us grow.',
        openStoreButton = 'Rate on Store',
        doneButton = 'Done',
        submitErrorMessage = 'Could not send feedback right now. Please try again.',
        emptyMessageError = 'Please select a tag or write a short note.';

  /// Built-in Bengali (বাংলা) copy.
  const ReviewStrings.bn({String appName = 'এই অ্যাপটি'})
      : rateTitle = '$appName কেমন লাগছে?',
        rateSubtitle = 'আপনার অভিজ্ঞতা জানাতে নিচে স্টার দিন।',
        starLabels = const <String>[
          'ভালো লাগেনি',
          'আরও ভালো হতে পারত',
          'মোটামুটি',
          'বেশ ভালো!',
          'অসাধারণ!',
        ],
        continueButton = 'এগিয়ে যান',
        notNowButton = 'পরে করব',
        feedbackTitle = 'আমাদের আরও ভালো হতে সাহায্য করুন',
        feedbackSubtitle =
            'আপনার অসুবিধার জন্য দুঃখিত। কী ঠিক করলে ভালো হবে জানান।',
        categories = const <String>[
          'বাগ / ক্র্যাশ',
          'স্লো চলছে',
          'নতুন ফিচার চাই',
          'ডিজাইন / UI',
          'অন্যান্য',
        ],
        messageHint = 'কী সমস্যা হচ্ছে বা কী যোগ করলে ভালো হয় লিখুন...',
        contactHint = 'ইমেইল বা ফোন (ঐচ্ছিক, উত্তর চাইলে)',
        diagnosticsNote = 'অ্যাপ ভার্সন ও ডিভাইসের তথ্য স্বয়ংক্রিয়ভাবে যুক্ত হবে।',
        submitButton = 'মতামত পাঠান',
        submittingLabel = 'পাঠানো হচ্ছে...',
        backButton = 'পিছনে',
        thankYouTitle = 'অসংখ্য ধন্যবাদ!',
        thankYouFeedbackMessage = 'আপনার মতামত সরাসরি ডেভেলপারের কাছে পৌঁছে গেছে।',
        thankYouStoreMessage =
            'আপনার ভালো লেগেছে জেনে আনন্দিত! স্টোরে একটা রেটিং দিলে আমাদের অনেক উপকার হয়।',
        openStoreButton = 'স্টোরে রেটিং দিন',
        doneButton = 'ঠিক আছে',
        submitErrorMessage = 'এই মুহূর্তে পাঠানো যায়নি। আবার চেষ্টা করুন।',
        emptyMessageError = 'দয়া করে একটি ট্যাগ বেছে নিন অথবা ছোট করে লিখুন।';
}
