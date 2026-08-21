import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart' show RSAPublicKey;

/// B站认证服务 —— 完整复刻 PiliPlus 四种登录方式
///
/// 登录方式：
/// 1. 密码登录：getWebKey获取salt+pubkey → RSA加密密码 → loginByPwd
/// 2. 短信登录：sendSmsCode发送验证码 → loginBySms验证
/// 3. 扫码登录：TV端auth_code二维码 → 轮询poll获取token+cookie
/// 4. Cookie登录：手动粘贴Cookie → 验证有效性
class BilibiliAuthService {
  static final BilibiliAuthService _instance = BilibiliAuthService._internal();
  factory BilibiliAuthService() => _instance;
  BilibiliAuthService._internal();

  static const String _appKey = 'dfca71928277209b';
  static const String _appSec = 'b5475a8825547a4fc26c7d518eaaa02e';

  static const String _passBaseUrl = 'https://passport.bilibili.com';
  static const String _getTVCode =
      '$_passBaseUrl/x/passport-tv-login/qrcode/auth_code';
  static const String _qrcodePoll =
      '$_passBaseUrl/x/passport-tv-login/qrcode/poll';
  static const String _getWebKey = '$_passBaseUrl/x/passport-login/web/key';
  static const String _loginByPwd =
      '$_passBaseUrl/x/passport-login/oauth2/login';
  static const String _appSmsCode = '$_passBaseUrl/x/passport-login/sms/send';
  static const String _loginBySms = '$_passBaseUrl/x/passport-login/login/sms';
  static const String _preCapture = '$_passBaseUrl/x/safecenter/captcha/pre';
  static const String _safeCenterGetInfo =
      '$_passBaseUrl/x/safecenter/user/info';
  static const String _safeCenterSmsCode =
      '$_passBaseUrl/x/safecenter/common/sms/send';
  static const String _safeCenterSmsVerify =
      '$_passBaseUrl/x/safecenter/login/tel/verify';
  static const String _oauth2AccessToken =
      '$_passBaseUrl/x/passport-login/oauth2/access_token';
  static const String _userInfoEndpoint =
      'https://api.bilibili.com/x/web-interface/nav';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2',
    'env': 'prod',
    'app-key': 'android_hd',
    'bili-http-engine': 'cronet',
    'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
  };

  static const String _statistics =
      '{"appId":5,"platform":3,"version":"2.0.1","abtest":""}';

  final http.Client _client = http.Client();
  String? _buvid;
  String? _deviceId;
  String? _accessToken;
  String? _refreshToken;
  String? _cookies;
  Map<String, dynamic>? _userInfo;
  bool _isLoggedIn = false;

  String? _geeValidate;
  String? _geeSeccode;
  String? _geeChallenge;
  String? _recaptchaToken;

  String get buvid => _buvid ??= _generateBuvid();
  String get deviceId => _deviceId ??= _generateDeviceId();
  bool get isLoggedIn => _isLoggedIn;
  String? get cookies => _cookies;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userInfo => _userInfo;

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

  String _generateBuvid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final md5Str = md5.convert(bytes).toString();
    return 'XY${md5Str[2]}${md5Str[12]}${md5Str[22]}$md5Str';
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final time = DateTime.now();
    int dec2bcd(int dec) => ((dec ~/ 10) << 4) | (dec % 10);
    final bytes = [
      ...List.generate(16, (_) => random.nextInt(256)),
      dec2bcd(time.year ~/ 100),
      dec2bcd(time.year % 100),
      dec2bcd(time.month),
      dec2bcd(time.day),
      dec2bcd(time.hour),
      dec2bcd(time.minute),
      dec2bcd(time.second),
      ...List.generate(8, (_) => random.nextInt(256)),
    ];
    final check = (bytes.reduce((a, b) => a + b) & 0xFF)
        .toRadixString(16)
        .padLeft(2, '0');
    return md5.convert(bytes).toString() + check;
  }

  String _generateRandomString(int length) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  void setGeetestResult({
    required String challenge,
    required String validate,
    required String seccode,
    String? recaptchaToken,
  }) {
    _geeChallenge = challenge;
    _geeValidate = validate;
    _geeSeccode = seccode;
    _recaptchaToken = recaptchaToken;
  }

  void clearGeetestResult() {
    _geeChallenge = null;
    _geeValidate = null;
    _geeSeccode = null;
    _recaptchaToken = null;
  }

  // === 1. 二维码扫码登录 ===
  Future<Map<String, String>> getQRCode() async {
    final params = {
      'local_id': '0',
      'platform': 'android',
      'mobi_app': 'android_hd',
    };
    _appSign(params);
    final uri = Uri.parse(_getTVCode).replace(queryParameters: params);
    final response = await _client.post(uri, headers: _headers);
    if (response.statusCode != 200)
      throw Exception('HTTP ${response.statusCode}');
    final data = json.decode(response.body);
    if (data['code'] != 0) throw Exception(data['message']);
    return {
      'authCode': data['data']['auth_code'].toString(),
      'url': data['data']['url'].toString(),
    };
  }

  Future<Map<String, dynamic>> pollQRCode(String authCode) async {
    final params = {'auth_code': authCode, 'local_id': '0'};
    _appSign(params);
    final uri = Uri.parse(_qrcodePoll).replace(queryParameters: params);
    final response = await _client.post(uri, headers: _headers);
    if (response.statusCode != 200)
      return {'status': false, 'code': -1, 'msg': '网络错误'};
    final data = json.decode(response.body);
    if (data['code'] == 0) {
      _parseLoginResult(data['data']);
      return {'status': true, 'code': 0, 'data': data['data']};
    }
    return {
      'status': false,
      'code': data['code'],
      'msg': data['message'] ?? '等待扫码',
    };
  }

  // === 2. 账号密码登录 ===
  Future<Map<String, dynamic>> getWebKey() async {
    final response = await _client.get(
      Uri.parse(_getWebKey),
      headers: _headers,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final data = json.decode(response.body);
    if (data['code'] == 0) return {'status': true, 'data': data['data']};
    return {'status': false, 'msg': data['message']};
  }

  Future<Map<String, dynamic>> loginByPassword({
    required String username,
    required String password,
  }) async {
    final webKeyRes = await getWebKey();
    if (!webKeyRes['status'])
      return {'status': false, 'msg': webKeyRes['msg'] ?? '获取密钥失败'};
    final salt = webKeyRes['data']['hash'];
    final key = webKeyRes['data']['key'];
    final publicKey = RSAKeyParser().parse(key) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: publicKey));
    final passwordEncrypted = encrypter.encrypt(salt + password).base64;
    final dt = Uri.encodeComponent(
      encrypter.encrypt(_generateRandomString(16)).base64,
    );

    final data = {
      'bili_local_id': deviceId,
      'build': '2001100',
      'buvid': buvid,
      'c_locale': 'zh_CN',
      'channel': 'master',
      'device': 'phone',
      'device_id': deviceId,
      'device_name': 'vivo',
      'device_platform': 'Android14vivo',
      'disable_rcmd': '0',
      'dt': dt,
      'from_pv': 'main.homepage.avatar-nologin.all.click',
      'from_url': Uri.encodeComponent('bilibili://pegasus/promo'),
      'gee_challenge': _geeChallenge,
      'gee_seccode': _geeSeccode,
      'gee_validate': _geeValidate,
      'local_id': buvid,
      'mobi_app': 'android_hd',
      'password': passwordEncrypted,
      'permission': 'ALL',
      'platform': 'android',
      'recaptcha_token': _recaptchaToken,
      's_locale': 'zh_CN',
      'statistics': _statistics,
      'username': username,
    };
    _appSign(data);

    final response = await _client.post(
      Uri.parse(_loginByPwd),
      headers: _headers,
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) {
      final resultData = res['data'];
      if (resultData != null && resultData['status'] == 2) {
        return {
          'status': false,
          'code': 2,
          'msg': resultData['message'],
          'data': resultData,
          'needRiskVerify': true,
        };
      }
      if (resultData != null && resultData['token_info'] != null) {
        _parseLoginResult(resultData);
        return {'status': true, 'data': resultData};
      }
      return {'status': false, 'msg': '登录异常'};
    }
    return {
      'status': false,
      'code': res['code'],
      'msg': res['message'] ?? '登录失败',
      'data': res['data'],
      'needGeetest': res['code'] == -105,
    };
  }

  // === 3. 手机短信验证码登录 ===
  Future<Map<String, dynamic>> sendSmsCode({
    required String tel,
    String cid = '86',
  }) async {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'build': '2001100',
      'buvid': buvid,
      'c_locale': 'zh_CN',
      'channel': 'master',
      'cid': cid,
      'disable_rcmd': '0',
      'gee_challenge': _geeChallenge,
      'gee_seccode': _geeSeccode,
      'gee_validate': _geeValidate,
      'local_id': buvid,
      'login_session_id':
          md5.convert(ascii.encode(buvid + timestamp.toString())).toString(),
      'mobi_app': 'android_hd',
      'platform': 'android',
      'recaptcha_token': _recaptchaToken,
      's_locale': 'zh_CN',
      'statistics': _statistics,
      'tel': tel,
      'ts': (timestamp ~/ 1000).toString(),
    };
    _appSign(data);
    final response = await _client.post(
      Uri.parse(_appSmsCode),
      headers: _headers,
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0 &&
        (res['data']['recaptcha_url'] == '' ||
            res['data']['recaptcha_url'] == null)) {
      return {'status': true, 'data': res['data']};
    }
    return {
      'status': false,
      'code': res['code'],
      'msg': res['message'] ?? '发送失败',
      'data': res['data'],
      'needGeetest': res['code'] == -105 ||
          (res['data']?['recaptcha_url']?.isNotEmpty == true),
    };
  }

  Future<Map<String, dynamic>> loginBySms({
    required String tel,
    required String code,
    required String captchaKey,
    String cid = '86',
  }) async {
    final webKeyRes = await getWebKey();
    if (!webKeyRes['status'])
      return {'status': false, 'msg': webKeyRes['msg'] ?? '获取密钥失败'};
    final publicKey =
        RSAKeyParser().parse(webKeyRes['data']['key']) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: publicKey));
    final dt = Uri.encodeComponent(
      encrypter.encrypt(_generateRandomString(16)).base64,
    );

    final data = {
      'bili_local_id': deviceId,
      'build': '2001100',
      'buvid': buvid,
      'c_locale': 'zh_CN',
      'captcha_key': captchaKey,
      'channel': 'master',
      'cid': cid,
      'code': code,
      'device': 'phone',
      'device_id': deviceId,
      'device_name': 'vivo',
      'device_platform': 'Android14vivo',
      'disable_rcmd': '0',
      'dt': dt,
      'from_pv': 'main.my-information.my-login.0.click',
      'from_url': Uri.encodeComponent('bilibili://user_center/mine'),
      'local_id': buvid,
      'mobi_app': 'android_hd',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': _statistics,
      'tel': tel,
    };
    _appSign(data);
    final response = await _client.post(
      Uri.parse(_loginBySms),
      headers: _headers,
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) {
      _parseLoginResult(res['data']);
      return {'status': true, 'data': res['data']};
    }
    return {
      'status': false,
      'code': res['code'],
      'msg': res['message'] ?? '登录失败',
    };
  }

  // === 4. Cookie登录 ===
  Future<bool> loginByCookie(String cookieString) async {
    _cookies = cookieString.trim();
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

  // === 极验 & 风控验证 ===
  Future<Map<String, dynamic>> preCapture() async {
    final response = await _client.post(
      Uri.parse(_preCapture),
      headers: _headers,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) return {'status': true, 'data': res['data']};
    return {'status': false, 'code': res['code'], 'msg': res['message']};
  }

  Future<Map<String, dynamic>> safeCenterGetInfo({
    required String tmpCode,
  }) async {
    final uri = Uri.parse(_safeCenterGetInfo)
        .replace(queryParameters: {'tmp_code': tmpCode});
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) return {'status': true, 'data': res['data']};
    return {'status': false, 'code': res['code'], 'msg': res['message']};
  }

  Future<Map<String, dynamic>> safeCenterSmsCode({
    required String tmpCode,
    required String refererUrl,
  }) async {
    final data = {
      'disable_rcmd': '0',
      'sms_type': 'loginTelCheck',
      'tmp_code': tmpCode,
      'gee_challenge': _geeChallenge,
      'gee_seccode': _geeSeccode,
      'gee_validate': _geeValidate,
      'recaptcha_token': _recaptchaToken,
    };
    _appSign(data);
    final response = await _client.post(
      Uri.parse(_safeCenterSmsCode),
      headers: {..._headers, 'Referer': refererUrl},
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) return {'status': true, 'data': res['data']};
    return {'status': false, 'code': res['code'], 'msg': res['message']};
  }

  Future<Map<String, dynamic>> safeCenterSmsVerify({
    required String code,
    required String tmpCode,
    required String requestId,
    required String source,
    required String captchaKey,
    required String refererUrl,
  }) async {
    final data = {
      'type': 'loginTelCheck',
      'code': code,
      'tmp_code': tmpCode,
      'request_id': requestId,
      'source': source,
      'captcha_key': captchaKey,
    };
    _appSign(data);
    final response = await _client.post(
      Uri.parse(_safeCenterSmsVerify),
      headers: {..._headers, 'Referer': refererUrl},
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) return {'status': true, 'data': res['data']};
    return {'status': false, 'code': res['code'], 'msg': res['message']};
  }

  Future<Map<String, dynamic>> oauth2AccessToken({required String code}) async {
    final data = {
      'build': '2001100',
      'buvid': buvid,
      'code': code,
      'disable_rcmd': '0',
      'grant_type': 'authorization_code',
      'local_id': buvid,
      'mobi_app': 'android_hd',
      'platform': 'android',
    };
    _appSign(data);
    final response = await _client.post(
      Uri.parse(_oauth2AccessToken),
      headers: _headers,
      body: data,
    );
    if (response.statusCode != 200) return {'status': false, 'msg': '网络错误'};
    final res = json.decode(response.body);
    if (res['code'] == 0) {
      _parseLoginResult(res['data']);
      return {'status': true, 'data': res['data']};
    }
    return {'status': false, 'code': res['code'], 'msg': res['message']};
  }

  // === 通用 ===
  void _parseLoginResult(Map<String, dynamic> data) {
    if (data['token_info'] != null) {
      _accessToken = data['token_info']['access_token'];
      _refreshToken = data['token_info']['refresh_token'];
    }
    if (data['cookie_info'] != null && data['cookie_info']['cookies'] != null) {
      _cookies = (data['cookie_info']['cookies'] as List)
          .map((c) => '${c['name']}=${c['value']}')
          .join('; ');
    }
    _isLoggedIn = true;
  }

  Future<Map<String, dynamic>?> fetchUserInfo() async {
    if (!_isLoggedIn || _cookies == null) return null;
    final headers = {
      'User-Agent': 'Mozilla/5.0',
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

  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _cookies = null;
    _userInfo = null;
    _isLoggedIn = false;
    clearGeetestResult();
  }

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

  void dispose() => _client.close();
}

class BilibiliLoginCode {
  static const int success = 0;
  static const int scanned = 86090;
  static const int expired = 86038;
  static const int waiting = 86101;
  static const int needGeetest = -105;
}
