import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abstraction over platform store review APIs so tests never hit native channels.
abstract class StoreReviewAdapter {
  const StoreReviewAdapter();

  /// Requests the native Google Play / App Store in-app review sheet.
  ///
  /// Returns `true` if the native flow was invoked, `false` if unavailable.
  Future<bool> requestInAppReview();

  /// Opens the public store listing page as a fallback (or when explicitly tapped).
  Future<bool> openStoreListing({
    String? androidPackageName,
    String? appStoreId,
    String? fallbackUrl,
  });
}

/// Default production adapter backed by `in_app_review` + `url_launcher`.
class InAppReviewAdapter extends StoreReviewAdapter {
  InAppReviewAdapter({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> requestInAppReview() async {
    try {
      final available = await _inAppReview.isAvailable();
      if (!available) return false;
      await _inAppReview.requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openStoreListing({
    String? androidPackageName,
    String? appStoreId,
    String? fallbackUrl,
  }) async {
    if (fallbackUrl != null && fallbackUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(fallbackUrl.trim());
      if (uri != null && uri.hasScheme) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return true;
          }
        } catch (_) {
          // Fall through to in_app_review openStoreListing.
        }
      }
    }
    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
      return true;
    } catch (_) {
      if (androidPackageName != null && androidPackageName.trim().isNotEmpty) {
        final playUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=${androidPackageName.trim()}',
        );
        try {
          return await launchUrl(playUri, mode: LaunchMode.externalApplication);
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }
}

/// Deterministic in-memory adapter for unit and widget tests.
class FakeStoreReviewAdapter extends StoreReviewAdapter {
  FakeStoreReviewAdapter({this.inAppAvailable = true});

  bool inAppAvailable;
  int requestReviewCalls = 0;
  int openStoreListingCalls = 0;
  String? lastFallbackUrl;

  @override
  Future<bool> requestInAppReview() async {
    requestReviewCalls++;
    return inAppAvailable;
  }

  @override
  Future<bool> openStoreListing({
    String? androidPackageName,
    String? appStoreId,
    String? fallbackUrl,
  }) async {
    openStoreListingCalls++;
    lastFallbackUrl = fallbackUrl;
    return true;
  }
}
