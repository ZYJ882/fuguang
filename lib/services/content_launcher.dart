import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/recommendation.dart';
import '../utils/app_utils.dart';

class ContentLauncher {
  static Future<void> openContent(Recommendation rec) async {
    final url = rec.contentUrl;
    if (url.isEmpty) return;

    final platform = rec.sourcePlatform;
    final packageName = SourcePlatform.packageNames[platform];

    if (packageName != null) {
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
          package: packageName,
        );
        await intent.launch();
        return;
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  static Future<void> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  static Future<void> openAuthorProfile(String platform, String authorName) async {
    String? url;
    switch (platform) {
      case 'bilibili':
        url = 'https://search.bilibili.com/upuser?keyword=${Uri.encodeComponent(authorName)}';
        break;
      case 'xiaohongshu':
        url = 'https://www.xiaohongshu.com/search_result?keyword=${Uri.encodeComponent(authorName)}';
        break;
      case 'zhihu':
        url = 'https://www.zhihu.com/search?type=people&q=${Uri.encodeComponent(authorName)}';
        break;
      default:
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(authorName)}';
    }
    await openUrl(url);
  }
}
