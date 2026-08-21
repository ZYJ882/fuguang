import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/bilibili_auth.dart';

/// B站登录页面 —— 复刻 PiliPlus 登录方式
///
/// 提供两种登录方式：
/// 1. 二维码扫码登录（推荐）：TV端 auth_code 方式，用B站官方App扫码
/// 2. Cookie登录（备用）：手动粘贴从浏览器获取的Cookie
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

  // === 二维码登录状态 ===
  String? _qrAuthCode;
  String? _qrUrl;
  bool _qrLoading = false;
  String _qrStatus = '正在获取二维码...';
  int _qrCountdown = 180; // 二维码有效期180秒
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _qrLoggedIn = false;

  // === Cookie登录状态 ===
  final TextEditingController _cookieController = TextEditingController();
  bool _cookieLoading = false;
  String _cookieStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchQRCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _tabController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  // === 获取二维码 ===
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

  // === 轮询登录状态（每2秒一次） ===
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_qrAuthCode == null || _qrLoggedIn) {
        timer.cancel();
        return;
      }

      final result = await _auth.pollQRCode(_qrAuthCode!);
      final code = result['code'];

      if (result['status'] == true) {
        // 登录成功
        timer.cancel();
        _countdownTimer?.cancel();
        setState(() {
          _qrLoggedIn = true;
          _qrStatus = '登录成功！';
        });
        // 获取用户信息
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
      // 其他状态继续等待
    });
  }

  // === 倒计时 ===
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_qrCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _qrCountdown--);
    });
  }

  // === Cookie登录 ===
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

  // === 复制登录链接 ===
  void _copyLoginUrl() {
    if (_qrUrl != null) {
      Clipboard.setData(ClipboardData(text: _qrUrl!));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('登录链接已复制到剪贴板')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B站登录'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: '扫码登录'),
            Tab(icon: Icon(Icons.cookie_outlined), text: 'Cookie登录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildQRCodeTab(), _buildCookieTab()],
      ),
    );
  }

  // === 二维码登录Tab ===
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
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),

          // 二维码区域
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
                        child: Text('二维码获取失败',
                            style: TextStyle(color: Colors.red)),
                      ),
          ),

          const SizedBox(height: 16),
          Text(
            _qrStatus,
            style: TextStyle(
              fontSize: 14,
              color: _qrLoggedIn
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _qrLoading ? null : _fetchQRCode,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新二维码'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _qrUrl == null ? null : _copyLoginUrl,
                icon: const Icon(Icons.copy),
                label: const Text('复制链接'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // 安全提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '登录方式复刻自 PiliPlus 开源项目，采用B站TV端官方扫码登录接口。\n'
              '登录凭证仅存储在本地，不会上传至任何服务器。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              '注意：Cookie登录方式下，部分需要App端access_token的功能将不可用。'
              '建议优先使用扫码登录。\n\n'
              '获取方法：在浏览器登录B站后，按F12打开开发者工具，'
              '在Application/存储 → Cookies中复制全部Cookie字符串。',
              style: TextStyle(fontSize: 12, height: 1.5, color: Colors.orange),
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
                onPressed: () => _cookieController.clear(),
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
                fontSize: 14,
                color: _cookieStatus.contains('成功') ? Colors.green : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
