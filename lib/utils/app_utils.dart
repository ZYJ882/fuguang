import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AppUtils {
  static String decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String formatCount(int value) {
    if (value >= 100000000) {
      final v = value / 100000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}亿';
    }
    if (value >= 10000) {
      final v = value / 10000;
      return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}万';
    }
    return value.toString();
  }

  static String formatTimeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final now = DateTime.now();
    final diff = now.difference(parsed.toLocal());
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (parsed.year == now.year) {
      return DateFormat('M月d日').format(parsed);
    }
    return DateFormat('yyyy-M-d').format(parsed);
  }

  static String md5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        '_' +
        UniqueKey().toString().substring(2, 8);
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static List<String> parseTags(String? tags) {
    if (tags == null || tags.isEmpty) return [];
    return tags
        .split(RegExp(r'[,，、\s]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static double clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }

  static String secondsToDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class SourcePlatform {
  static const String bilibili = 'bilibili';
  static const String xiaohongshu = 'xiaohongshu';
  static const String douyin = 'douyin';
  static const String youtube = 'youtube';
  static const String twitter = 'twitter';
  static const String zhihu = 'zhihu';
  static const String reddit = 'reddit';
  static const String bangumi = 'bangumi';
  static const String linuxdo = 'linuxdo';
  static const String v2ex = 'v2ex';
  static const String weibo = 'weibo';
  static const String web = 'web';

  static const Map<String, String> labels = {
    bilibili: 'B站',
    xiaohongshu: '小红书',
    douyin: '抖音',
    youtube: 'YouTube',
    twitter: 'X',
    zhihu: '知乎',
    reddit: 'Reddit',
    bangumi: 'Bangumi',
    linuxdo: 'Linux.do',
    v2ex: 'V2EX',
    weibo: '微博',
    web: '网页',
  };

  static const Map<String, String> packageNames = {
    bilibili: 'tv.danmaku.bili',
    xiaohongshu: 'com.xingin.xhs',
    douyin: 'com.ss.android.ugc.aweme',
    youtube: 'com.google.android.youtube',
    twitter: 'com.twitter.android',
    zhihu: 'com.zhihu.android',
    reddit: 'com.reddit.frontpage',
    weibo: 'com.sina.weibo',
  };

  static String normalize(String value, {String contentUrl = '', String bvid = ''}) {
    final source = value.trim().toLowerCase();
    const aliases = {
      'bili': bilibili, 'bilibili': bilibili,
      'xhs': xiaohongshu, 'xiaohongshu': xiaohongshu, 'rednote': xiaohongshu,
      'dy': douyin, 'douyin': douyin, 'tiktok': douyin,
      'wb': weibo, 'weibo': weibo,
      'yt': youtube, 'youtube': youtube,
      'x': twitter, 'twitter': twitter,
      'zh': zhihu, 'zhihu': zhihu,
      'rd': reddit, 'reddit': reddit,
      'bgm': bangumi, 'bangumi': bangumi,
      'linuxdo': linuxdo, 'linux.do': linuxdo,
      'v2': v2ex, 'v2ex': v2ex,
      'web': web,
    };
    if (aliases.containsKey(source)) return aliases[source]!;
    if (source.isEmpty && bvid.contains(':')) {
      final ns = bvid.split(':').first.trim().toLowerCase();
      if (aliases.containsKey(ns)) return aliases[ns]!;
    }
    final uri = Uri.tryParse(contentUrl.contains('://') ? contentUrl : 'https://$contentUrl');
    final host = uri?.host.toLowerCase() ?? '';
    bool matches(String d) => host == d || host.endsWith('.$d');
    if (matches('bilibili.com') || matches('b23.tv')) return bilibili;
    if (matches('xiaohongshu.com') || matches('xhslink.com')) return xiaohongshu;
    if (matches('douyin.com')) return douyin;
    if (matches('weibo.com') || matches('weibo.cn')) return weibo;
    if (matches('youtube.com') || matches('youtu.be')) return youtube;
    if (matches('x.com') || matches('twitter.com')) return twitter;
    if (matches('zhihu.com')) return zhihu;
    if (matches('reddit.com') || matches('redd.it')) return reddit;
    if (matches('bgm.tv') || matches('bangumi.tv')) return bangumi;
    if (matches('linux.do')) return linuxdo;
    if (matches('v2ex.com')) return v2ex;
    if (bvid.isNotEmpty && !bvid.contains(':')) return bilibili;
    return source.isEmpty ? web : source;
  }

  static String label(String source) => labels[normalize(source)] ?? source;
}
