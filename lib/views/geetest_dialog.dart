import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

/// 极验验证码对话框 —— 复刻 PiliPlus GeetestWebviewDialog
///
/// 使用 webview_flutter 加载极验验证页面，用户完成验证后返回结果。
class GeetestDialog extends StatefulWidget {
  final String gt;
  final String challenge;
  final String? recaptchaToken;

  const GeetestDialog({
    super.key,
    required this.gt,
    required this.challenge,
    this.recaptchaToken,
  });

  /// 显示极验验证码对话框，返回验证结果
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String gt,
    required String challenge,
    String? recaptchaToken,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GeetestDialog(
        gt: gt,
        challenge: challenge,
        recaptchaToken: recaptchaToken,
      ),
    );
  }

  @override
  State<GeetestDialog> createState() => _GeetestDialogState();
}

class _GeetestDialogState extends State<GeetestDialog> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  String? _configJson;

  static const String _geetestJsUri =
      'https://static.geetest.com/static/js/fullpage.0.0.0.js';

  @override
  void initState() {
    super.initState();
    _initConfig();
  }

  /// 获取极验配置（复刻 PiliPlus _getConfig）
  Future<void> _initConfig() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.geetest.com/gettype.php')
            .replace(queryParameters: {'gt': widget.gt}),
      );
      if (res.statusCode == 200) {
        String data = res.body;
        if (data.startsWith('(') && data.endsWith(')')) {
          data = data.substring(1, data.length - 1);
        }
        final config = jsonDecode(data);
        if (config['status'] == 'success') {
          final configData = Map<String, dynamic>.from(config['data']);
          configData.addAll({
            'gt': widget.gt,
            'challenge': widget.challenge,
            'offline': false,
            'new_captcha': true,
            'product': 'bind',
            'width': '100%',
            'https': true,
            'protocol': 'https://',
          });
          _configJson = jsonEncode(configData);
          _initWebView();
          return;
        }
      }
      setState(() => _error = '获取验证码配置失败');
    } catch (e) {
      setState(() => _error = '获取验证码配置失败: $e');
    }
  }

  /// 初始化 WebView
  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'GeetestResult',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsResult(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (_configJson != null) {
              _controller?.runJavaScript(_showJs(_configJson!));
            }
          },
        ),
      )
      ..loadHtmlString(_buildHtml());

    setState(() => _loading = false);
  }

  /// 构建 HTML 页面
  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 300px; }
    #captcha { width: 100%; max-width: 300px; }
  </style>
</head>
<body>
  <div id="captcha"></div>
  <script src="$_geetestJsUri"></script>
  <script>
    function sendResult(type, data) {
      GeetestResult.postMessage(JSON.stringify({type: type, data: data}));
    }
  </script>
</body>
</html>
''';
  }

  /// 极验初始化 JS（复刻 PiliPlus _showJs）
  String _showJs(String config) {
    return '''
    (function() {
      try {
        initGeetest($config, function(captchaObj) {
          captchaObj.appendTo('#captcha');
          captchaObj.onSuccess(function() {
            var result = captchaObj.getValidate();
            sendResult('success', {
              geetest_challenge: result.geetest_challenge,
              geetest_validate: result.geetest_validate,
              geetest_seccode: result.geetest_seccode
            });
          });
          captchaObj.onError(function(err) {
            sendResult('error', {message: err ? err.toString() : '验证失败'});
          });
          captchaObj.onClose(function() {
            sendResult('close', {});
          });
          captchaObj.onReady(function() {
            captchaObj.verify();
          });
        });
      } catch(e) {
        sendResult('error', {message: e.toString()});
      }
    })();
    ''';
  }

  /// 处理 JS 返回结果
  void _handleJsResult(String message) {
    try {
      final result = jsonDecode(message);
      final type = result['type'];
      final data = result['data'];

      if (type == 'success') {
        Navigator.of(context).pop({
          'geetest_challenge': data['geetest_challenge'],
          'geetest_validate': data['geetest_validate'],
          'geetest_seccode': data['geetest_seccode'],
          'recaptcha_token': widget.recaptchaToken,
        });
      } else if (type == 'error') {
        setState(() => _error = data['message'] ?? '验证失败');
      } else if (type == 'close') {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('安全验证'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _controller!),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
