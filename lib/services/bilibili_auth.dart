import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// B站认证服务 —— 复刻 PiliPlus 的 TV端二维码扫码登录 + Cookie登录
///
/// 登录方式：
/// 1. 二维码扫码登录（推荐）：调用TV端API获取auth_code，生成二维码，
///    用户用B站官方App扫码确认，轮询poll接口获取access_token和cookie
/// 2. Cookie登录（备用）：用户手动粘贴从浏览器获取的Cookie字符串
class BilibiliAuthService {
  static final BilibiliAuthService _instance = BilibiliAuthService._internal();
  factory BilibiliAuthService() => _instance;
  BilibiliAuthService._internal();

  // === PiliPlus 同款 HD版 appKey/appSec ===
  static const String _appKey = 'dfca71928277209b';
  static const String _appSec = 'b5475a8825547a4fc26c7d518eaaa02e';

  // === API 端点（复刻 PiliPlus） ===
  static const String _passBaseUrl = 'https://passport.bilibili.com';
  static const String _getTVCode =
      '$_passBaseUrl/x/passport-tv-login/qrcode/auth_code';
  static const String _qrcodePoll =
      '$_passBaseUrl/x/passport-tv-login/qrcode/poll';
  static const String _userInfoEndpoint =
      'https://api.bilibili.com/x/web-interface/nav';

  // === 请求头（复刻 PiliPlus android_hd） ===
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2',
    'env': 'prod',
    'app-key': 'android_hd',
    'bili-http-engine': 'cronet',
    'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
  };

  final http.Client _client = http.Client();
  String? _buvid;
  String? _accessToken;
  String? _refreshToken;
  String? _cookies;
  Map<String, dynamic>? _userInfo;
  bool _isLoggedIn = false;

  String get buvid => _buvid ??= _generateBuvid();
  bool get isLoggedIn => _isLoggedIn;
  String? get cookies => _cookies;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userInfo => _userInfo;

  // === appSign 签名（复刻 PiliPlus AppSign.appSign） ===
  /// 对参数进行MD5签名：按key排序 → 拼接queryString + appSec → MD5
  void _appSign(Map<String, dynamic> params) {
    params['appkey'] = _appKey;
    params['ts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final query = sorted
        .where((e) => e.value != null)
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
        )
        .join('&');
    params['sign'] = md5.convert(utf8.encode('$query$_appSec')).toString();
  }

  // === buvid 生成（复刻 PiliPlus LoginUtils.generateBuvid） ===
  String _generateBuvid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final md5Str = md5.convert(bytes).toString();
    return 'XY${md5Str[2]}${md5Str[12]}${md5Str[22]}$md5Str';
  }

  // === 1. 获取二维码（TV端 auth_code） ===
  /// 返回 {authCode, url}，url用于生成二维码供B站App扫码
  Future<Map<String, String>> getQRCode() async {
    final params = {
      'local_id': '0',
      'platform': 'android',
      'mobi_app': 'android_hd',
    };
    _appSign(params);

    final uri = Uri.parse(_getTVCode).replace(queryParameters: params);
    final response = await _client.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('获取二维码失败: HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body);
    if (data['code'] != 0) {
      throw Exception('获取二维码失败: ${data['message']}');
    }

    final result = data['data'];
    return {
      'authCode': result['auth_code'].toString(),
      'url': result['url'].toString(),
    };
  }

  // === 2. 轮询二维码登录状态 ===
  /// 返回登录状态：
  /// - status: true=登录成功, false=未成功
  /// - code: 0=成功, 86038=二维码失效, 86090=已扫码未确认, 其他=等待
  /// - data: 登录成功时包含token_info和cookie_info
  Future<Map<String, dynamic>> pollQRCode(String authCode) async {
    final params = {'auth_code': authCode, 'local_id': '0'};
    _appSign(params);

    final uri = Uri.parse(_qrcodePoll).replace(queryParameters: params);
    final response = await _client.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      return {'status': false, 'code': -1, 'msg': '网络错误'};
    }

    final data = json.decode(response.body);
    final code = data['code'];

    if (code == 0) {
      // 登录成功，解析token和cookie
      final result = data['data'];
      _parseLoginResult(result);
      return {'status': true, 'code': 0, 'data': result};
    }

    return {'status': false, 'code': code, 'msg': data['message'] ?? '等待扫码'};
  }

  // === 解析登录成功结果 ===
  void _parseLoginResult(Map<String, dynamic> data) {
    // token_info: {access_token, refresh_token, expires_in}
    if (data.containsKey('token_info')) {
      final tokenInfo = data['token_info'];
      _accessToken = tokenInfo['access_token'];
      _refreshToken = tokenInfo['refresh_token'];
    }

    // cookie_info: {cookies: [{name, value, expires, ...}], domains}
    if (data.containsKey('cookie_info')) {
      final cookieInfo = data['cookie_info'];
      if (cookieInfo.containsKey('cookies')) {
        final cookieList = cookieInfo['cookies'] as List;
        _cookies =
            cookieList.map((c) => '${c['name']}=${c['value']}').join('; ');
      }
    }

    _isLoggedIn = true;
  }

  // === 3. Cookie登录（备用方式） ===
  /// 验证Cookie有效性并获取用户信息
  Future<bool> loginByCookie(String cookieString) async {
    _cookies = cookieString.trim();
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Cookie': _cookies!,
      'Referer': 'https://www.bilibili.com/',
    };

    try {
      final response = await _client.get(
        Uri.parse(_userInfoEndpoint),
        headers: headers,
      );
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      if (data['code'] == 0 && data['data']['isLogin'] == true) {
        _userInfo = data['data'];
        _isLoggedIn = true;
        return true;
      }
      _cookies = null;
      return false;
    } catch (e) {
      _cookies = null;
      return false;
    }
  }

  // === 4. 获取当前登录用户信息 ===
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    if (!_isLoggedIn || _cookies == null) return null;

    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Cookie': _cookies!,
      'Referer': 'https://www.bilibili.com/',
    };

    try {
      final response = await _client.get(
        Uri.parse(_userInfoEndpoint),
        headers: headers,
      );
      final data = json.decode(response.body);
      if (data['code'] == 0) {
        _userInfo = data['data'];
        return _userInfo;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // === 5. 登出 ===
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _cookies = null;
    _userInfo = null;
    _isLoggedIn = false;
  }

  // === 6. 从持久化数据恢复登录状态 ===
  void restoreFromStorage({
    required String cookies,
    String? accessToken,
    String? refreshToken,
  }) {
    _cookies = cookies;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _isLoggedIn = true;
  }

  void dispose() {
    _client.close();
  }
}

/// 二维码登录状态码
class BilibiliLoginCode {
  static const int success = 0;
  static const int scanned = 86090; // 已扫码，未确认
  static const int expired = 86038; // 二维码已失效
  static const int waiting = 86101; // 未扫码
}
