import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/bilibili_auth.dart';
import 'geetest_dialog.dart';

/// B站登录页面 —— 完整复刻 PiliPlus 四种登录方式
///
/// 四个Tab：密码、短信、扫码、Cookie
class BilibiliLoginView extends StatefulWidget {
  final Function(bool success, Map<String, dynamic>? userInfo)? onLoginResult;

  const BilibiliLoginView({super.key, this.onLoginResult});

  @override
  State<BilibiliLoginView> createState() => _BilibiliLoginViewState();
}

class _BilibiliLoginViewState extends State<BilibiliLoginView>
    with SingleTickerProviderStateMixin {
  final BilibiliAuthService _auth = BilibiliAuthService();
  late TabController _tabController;

  // === 通用 ===
  bool _loggingIn = false;

  // === 密码登录 ===
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  String _pwdStatus = '';

  // === 短信登录 ===
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  String _selectedCid = '86';
  String _captchaKey = '';
  int _smsCooldown = 0;
  Timer? _smsTimer;
  String _smsStatus = '';

  // === 扫码登录 ===
  String? _qrAuthCode;
  String? _qrUrl;
  bool _qrLoading = false;
  String _qrStatus = '正在获取二维码...';
  int _qrCountdown = 180;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _qrLoggedIn = false;

  // === Cookie登录 ===
  final TextEditingController _cookieController = TextEditingController();
  bool _cookieLoading = false;
  String _cookieStatus = '';

  static const List<Map<String, String>> _countryCodes = [
    {'cname': '中国大陆', 'countryId': '86'},
    {'cname': '中国香港', 'countryId': '852'},
    {'cname': '中国澳门', 'countryId': '853'},
    {'cname': '中国台湾', 'countryId': '886'},
    {'cname': '美国', 'countryId': '1'},
    {'cname': '日本', 'countryId': '81'},
    {'cname': '韩国', 'countryId': '82'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchQRCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _smsTimer?.cancel();
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  // ============================================================
  // 密码登录
  // ============================================================
  Future<void> _loginByPassword() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _pwdStatus = '用户名或密码不能为空');
      return;
    }

    setState(() {
      _loggingIn = true;
      _pwdStatus = '正在登录...';
    });

    final res = await _auth.loginByPassword(
      username: username,
      password: password,
    );

    if (!mounted) return;
    setState(() => _loggingIn = false);

    if (res['status'] == true) {
      _pwdStatus = '登录成功';
      final userInfo = await _auth.fetchUserInfo();
      widget.onLoginResult?.call(true, userInfo);
      if (mounted) Navigator.of(context).pop(true);
    } else if (res['needRiskVerify'] == true) {
      _pwdStatus = '需要风控验证';
      _handleRiskVerify(res['data']);
    } else if (res['needGeetest'] == true) {
      _pwdStatus = '需要安全验证';
      _handleGeetest(res['data'], isPassword: true);
    } else {
      _pwdStatus = res['msg'] ?? '登录失败';
    }
  }

  // ============================================================
  // 短信登录
  // ============================================================
  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _smsStatus = '手机号不能为空');
      return;
    }

    setState(() => _smsStatus = '正在发送验证码...');

    final res = await _auth.sendSmsCode(tel: phone, cid: _selectedCid);

    if (!mounted) return;

    if (res['status'] == true) {
      _captchaKey = res['data']['captcha_key'] ?? '';
      _smsStatus = '验证码已发送';
      _startSmsCooldown();
    } else if (res['needGeetest'] == true) {
      _smsStatus = '需要安全验证';
      _handleGeetest(res['data'], isPassword: false);
    } else {
      _smsStatus = res['msg'] ?? '发送失败';
    }
  }

  void _startSmsCooldown() {
    _smsCooldown = 60;
    _smsTimer?.cancel();
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_smsCooldown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _smsCooldown--);
    });
  }

  Future<void> _loginBySms() async {
    final phone = _phoneController.text.trim();
    final code = _smsCodeController.text.trim();
    if (phone.isEmpty) {
      setState(() => _smsStatus = '手机号不能为空');
      return;
    }
    if (_captchaKey.isEmpty) {
      setState(() => _smsStatus = '请先获取验证码');
      return;
    }
    if (code.isEmpty) {
      setState(() => _smsStatus = '验证码不能为空');
      return;
    }

    setState(() {
      _loggingIn = true;
      _smsStatus = '正在登录...';
    });

    final res = await _auth.loginBySms(
      tel: phone,
      code: code,
      captchaKey: _captchaKey,
      cid: _selectedCid,
    );

    if (!mounted) return;
    setState(() => _loggingIn = false);

    if (res['status'] == true) {
      _smsStatus = '登录成功';
      final userInfo = await _auth.fetchUserInfo();
      widget.onLoginResult?.call(true, userInfo);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _smsStatus = res['msg'] ?? '登录失败';
    }
  }

  // ============================================================
  // 极验验证码处理
  // ============================================================
  Future<void> _handleGeetest(
    Map<String, dynamic>? data, {
    required bool isPassword,
  }) async {
    String? gt;
    String? challenge;
    String? recaptchaToken;

    // 从返回数据中提取极验参数
    if (data != null && data['url'] != null) {
      final uri = Uri.parse(data['url']);
      gt = uri.queryParameters['gee_gt'];
      challenge = uri.queryParameters['gee_challenge'];
      recaptchaToken = uri.queryParameters['recaptcha_token'];
    } else if (data != null && data['gee_gt'] != null) {
      gt = data['gee_gt'];
      challenge = data['gee_challenge'];
      recaptchaToken = data['recaptcha_token'];
    }

    // 如果没有从返回数据获取到，调用preCapture
    if (gt == null || challenge == null) {
      final preRes = await _auth.preCapture();
      if (preRes['status'] == true && preRes['data'] != null) {
        gt = preRes['data']['gee_gt'];
        challenge = preRes['data']['gee_challenge'];
        recaptchaToken = preRes['data']['recaptcha_token'];
      }
    }

    if (gt == null || challenge == null) {
      setState(() {
        if (isPassword) {
          _pwdStatus = '获取验证参数失败';
        } else {
          _smsStatus = '获取验证参数失败';
        }
      });
      return;
    }

    if (!mounted) return;
    final result = await GeetestDialog.show(
      context,
      gt: gt!,
      challenge: challenge!,
      recaptchaToken: recaptchaToken,
    );

    if (result != null) {
      _auth.setGeetestResult(
        challenge: result['geetest_challenge'],
        validate: result['geetest_validate'],
        seccode: result['geetest_seccode'],
        recaptchaToken: recaptchaToken,
      );
      // 验证成功后重试
      if (isPassword) {
        _loginByPassword();
      } else {
        _sendSmsCode();
      }
    } else {
      setState(() {
        if (isPassword) {
          _pwdStatus = '验证已取消';
        } else {
          _smsStatus = '验证已取消';
        }
      });
    }
  }

  // ============================================================
  // 风控验证（密码登录返回status=2时）
  // ============================================================
  Future<void> _handleRiskVerify(Map<String, dynamic> data) async {
    final url = data['url'];
    if (url == null) return;

    final uri = Uri.parse(url);
    final tmpCode = uri.queryParameters['tmp_token'];
    final requestId = uri.queryParameters['request_id'];
    final source = uri.queryParameters['source'];

    if (tmpCode == null) return;

    // 获取安全验证信息
    final infoRes = await _auth.safeCenterGetInfo(tmpCode: tmpCode);
    if (!infoRes['status'] || infoRes['data'] == null) return;

    final accountInfo = infoRes['data']['account_info'];
    if (accountInfo == null || accountInfo['tel_verify'] != true) return;

    final hideTel = accountInfo['hide_tel'] ?? '未知手机号';

    if (!mounted) return;

    // 显示风控验证对话框
    final smsCodeController = TextEditingController();
    String riskCaptchaKey = '';

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('本次登录需要验证您的手机号', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hideTel, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: smsCodeController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '请输入短信验证码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('发送验证码'),
            onPressed: () async {
              // 先极验验证
              final preRes = await _auth.preCapture();
              if (preRes['status'] == true && preRes['data'] != null) {
                final gt = preRes['data']['gee_gt'];
                final challenge = preRes['data']['gee_challenge'];
                final recaptchaToken = preRes['data']['recaptcha_token'];
                if (gt != null && challenge != null) {
                  final geeResult = await GeetestDialog.show(
                    dialogContext,
                    gt: gt,
                    challenge: challenge,
                    recaptchaToken: recaptchaToken,
                  );
                  if (geeResult != null) {
                    _auth.setGeetestResult(
                      challenge: geeResult['geetest_challenge'],
                      validate: geeResult['geetest_validate'],
                      seccode: geeResult['geetest_seccode'],
                      recaptchaToken: recaptchaToken,
                    );
                  }
                }
              }
              // 发送风控验证码
              final sendRes = await _auth.safeCenterSmsCode(
                tmpCode: tmpCode,
                refererUrl: url,
              );
              if (sendRes['status'] == true) {
                riskCaptchaKey = sendRes['data']['captcha_key'] ?? '';
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(const SnackBar(content: Text('验证码已发送')));
                }
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            child: const Text('确认'),
            onPressed: () async {
              final code = smsCodeController.text.trim();
              if (code.isEmpty || riskCaptchaKey.isEmpty) return;

              final verifyRes = await _auth.safeCenterSmsVerify(
                code: code,
                tmpCode: tmpCode,
                requestId: requestId ?? '',
                source: source ?? 'risk',
                captchaKey: riskCaptchaKey,
                refererUrl: url,
              );

              if (verifyRes['status'] == true && verifyRes['data'] != null) {
                final oauthCode = verifyRes['data']['code'];
                if (oauthCode != null) {
                  final tokenRes = await _auth.oauth2AccessToken(
                    code: oauthCode,
                  );
                  if (tokenRes['status'] == true) {
                    if (dialogContext.mounted)
                      Navigator.of(dialogContext).pop();
                    final userInfo = await _auth.fetchUserInfo();
                    widget.onLoginResult?.call(true, userInfo);
                    if (mounted) Navigator.of(context).pop(true);
                    return;
                  }
                }
              }
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(verifyRes['msg'] ?? '验证失败')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 扫码登录
  // ============================================================
  Future<void> _fetchQRCode() async {
    setState(() {
      _qrLoading = true;
      _qrStatus = '正在获取二维码...';
      _qrCountdown = 180;
      _qrLoggedIn = false;
    });

    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final result = await _auth.getQRCode();
      setState(() {
        _qrAuthCode = result['authCode'];
        _qrUrl = result['url'];
        _qrLoading = false;
        _qrStatus = '请使用B站官方App扫码登录';
      });
      _startPolling();
      _startCountdown();
    } catch (e) {
      setState(() {
        _qrLoading = false;
        _qrStatus = '获取二维码失败: $e';
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_qrAuthCode == null || _qrLoggedIn) {
        timer.cancel();
        return;
      }
      final result = await _auth.pollQRCode(_qrAuthCode!);
      final code = result['code'];
      if (result['status'] == true) {
        timer.cancel();
        _countdownTimer?.cancel();
        setState(() {
          _qrLoggedIn = true;
          _qrStatus = '登录成功！';
        });
        final userInfo = await _auth.fetchUserInfo();
        if (!mounted) return;
        widget.onLoginResult?.call(true, userInfo);
        Navigator.of(context).pop(true);
      } else if (code == BilibiliLoginCode.scanned) {
        setState(() => _qrStatus = '已扫码，请在App中确认登录');
      } else if (code == BilibiliLoginCode.expired) {
        timer.cancel();
        _countdownTimer?.cancel();
        setState(() => _qrStatus = '二维码已失效，请点击刷新');
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_qrCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _qrCountdown--);
    });
  }

  void _copyLoginUrl() {
    if (_qrUrl != null) {
      Clipboard.setData(ClipboardData(text: _qrUrl!));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('登录链接已复制')));
    }
  }

  // ============================================================
  // Cookie登录
  // ============================================================
  Future<void> _loginByCookie() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) {
      setState(() => _cookieStatus = '请输入Cookie');
      return;
    }
    setState(() {
      _cookieLoading = true;
      _cookieStatus = '正在验证Cookie...';
    });
    final success = await _auth.loginByCookie(cookie);
    if (!mounted) return;
    setState(() {
      _cookieLoading = false;
      _cookieStatus = success ? '登录成功！' : 'Cookie无效或已过期';
    });
    if (success) {
      widget.onLoginResult?.call(true, _auth.userInfo);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.password), text: '密码'),
            Tab(icon: Icon(Icons.sms), text: '短信'),
            Tab(icon: Icon(Icons.qr_code), text: '扫码'),
            Tab(icon: Icon(Icons.cookie_outlined), text: 'Cookie'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPasswordTab(),
          _buildSmsTab(),
          _buildQRCodeTab(),
          _buildCookieTab(),
        ],
      ),
    );
  }

  // === 密码登录Tab ===
  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '使用账号密码登录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person),
              labelText: '账号',
              hintText: '邮箱/手机号',
              border: const UnderlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _usernameController.clear,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock),
              labelText: '密码',
              border: const UnderlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _passwordController.clear,
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: _showPassword,
                onChanged: (v) => setState(() => _showPassword = v!),
              ),
              const Text('显示密码'),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('忘记密码')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loggingIn ? null : _loginByPassword,
              icon: _loggingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loggingIn ? '登录中...' : '登录'),
            ),
          ),
          if (_pwdStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _pwdStatus,
              style: TextStyle(
                color: _pwdStatus.contains('成功') ? Colors.green : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            '根据 bilibili 官方登录接口规范，密码将在本地加盐、加密后传输。\n'
            '盐与公钥均由官方提供；以 RSA/ECB/PKCS1Padding 方式加密。\n'
            '账号密码仅用于该登录接口，不予保存；本地仅存储登录凭证。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // === 短信登录Tab ===
  Widget _buildSmsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '使用手机短信验证码登录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              PopupMenuButton<String>(
                initialValue: _selectedCid,
                onSelected: (v) => setState(() => _selectedCid = v),
                itemBuilder: (_) => _countryCodes
                    .map(
                      (c) => PopupMenuItem(
                        value: c['countryId'],
                        child: Row(
                          children: [
                            Text(c['cname']!),
                            const Spacer(),
                            Text('+${c['countryId']}'),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone),
                    const SizedBox(width: 8),
                    Text('+$_selectedCid'),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _smsCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _smsCooldown > 0 ? null : _sendSmsCode,
                child: Text(_smsCooldown > 0 ? '${_smsCooldown}s' : '获取验证码'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loggingIn ? null : _loginBySms,
              icon: _loggingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loggingIn ? '登录中...' : '登录'),
            ),
          ),
          if (_smsStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _smsStatus,
              style: TextStyle(
                color: _smsStatus.contains('成功') || _smsStatus.contains('已发送')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // === 扫码登录Tab ===
  Widget _buildQRCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '使用B站官方App扫码登录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '剩余有效时间: $_qrCountdown 秒',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _qrLoading
                ? const Center(child: CircularProgressIndicator())
                : _qrUrl != null
                    ? QrImageView(
                        data: _qrUrl!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      )
                    : const Center(
                        child:
                            Text('获取失败', style: TextStyle(color: Colors.red)),
                      ),
          ),
          const SizedBox(height: 16),
          Text(
            _qrStatus,
            style: TextStyle(
              color: _qrLoggedIn
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _qrLoading ? null : _fetchQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _qrUrl == null ? null : _copyLoginUrl,
                icon: const Icon(Icons.copy),
                label: const Text('复制链接'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === Cookie登录Tab ===
  Widget _buildCookieTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '使用Cookie登录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              '注意：Cookie登录方式下，部分需要App端access_token的功能将不可用。建议优先使用扫码登录。\n\n获取方法：在浏览器登录B站后，按F12打开开发者工具，在Application/存储 → Cookies中复制全部Cookie字符串。',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cookieController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Cookie',
              hintText: '粘贴从浏览器获取的Cookie字符串...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _cookieController.clear,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _cookieLoading ? null : _loginByCookie,
              icon: _cookieLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_cookieLoading ? '验证中...' : '登录'),
            ),
          ),
          if (_cookieStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _cookieStatus,
              style: TextStyle(
                color: _cookieStatus.contains('成功') ? Colors.green : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
