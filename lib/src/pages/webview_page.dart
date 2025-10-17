import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/ntut_api_service.dart';

/// WebView 頁面 - 完全參考 TAT 的 TATWebView 實作
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final bool shouldUseCookies;
  final NtutApiService apiService; // 直接傳入 apiService

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
    required this.apiService,
    this.shouldUseCookies = true,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  final _cookieManager = CookieManager.instance();
  late InAppWebViewController _controller;
  final _progress = ValueNotifier<double>(0.0);
  
  @override
  void initState() {
    super.initState();
    debugPrint('[WebViewPage] 初始化: ${widget.url}');
    
    // 驗證 URL 格式
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      debugPrint('[WebViewPage] URL 解析失敗: ${widget.url}');
    } else {
      debugPrint('[WebViewPage] URL 解析成功 - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
    }
  }

  /// 設定初始 cookies - 完全參考 TAT 的做法
  Future<void> _setInitialCookies() async {
    if (!widget.shouldUseCookies) {
      debugPrint('[WebViewPage] 不需要設定 cookies');
      return;
    }

    try {
      final initialUrl = Uri.parse(widget.url);
      
      // 從 NtutApiService 的 CookieJar 讀取 cookies
      final cookies = await widget.apiService.getCookiesForUrl(initialUrl);
      
      debugPrint('[WebViewPage] 找到 ${cookies.length} 個 cookies');
      
      // 設定每個 cookie 到 WebView
      for (final cookie in cookies) {
        debugPrint('[WebViewPage] 設定 cookie: ${cookie.name}=${cookie.value.substring(0, cookie.value.length > 10 ? 10 : cookie.value.length)}...');
        
        await _cookieManager.setCookie(
          url: WebUri.uri(initialUrl),
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain,
          path: cookie.path ?? '/',
          maxAge: cookie.maxAge,
          isSecure: cookie.secure,
          isHttpOnly: cookie.httpOnly,
        );
      }
      
      debugPrint('[WebViewPage] Cookies 設定完成');
    } catch (e, stackTrace) {
      debugPrint('[WebViewPage] 設定 cookies 失敗: $e');
      debugPrint('[WebViewPage] StackTrace: $stackTrace');
    }
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    debugPrint('[WebViewPage] WebView 已創建');
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    _progress.value = progress / 100.0;
    debugPrint('[WebViewPage] 載入進度: $progress%');
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    debugPrint('[WebViewPage] 開始載入: $url');
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    debugPrint('[WebViewPage] 載入完成: $url');
  }

  void _onLoadError(InAppWebViewController controller, Uri? url, int code, String message) {
    debugPrint('[WebViewPage] 載入錯誤: $message (code: $code)');
  }

  Future<ServerTrustAuthResponse?> _onReceivedServerTrustAuthRequest(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) async {
    // 信任所有證書（開發用，生產環境應該驗證）
    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 進度條
            ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, progress, _) {
                return progress < 1.0
                    ? LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
            // WebView
            Expanded(
              child: FutureBuilder(
                future: _setInitialCookies(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  return InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      cacheEnabled: true,
                      useOnLoadResource: true,
                      useShouldOverrideUrlLoading: false,
                      mediaPlaybackRequiresUserGesture: false,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                    ),
                    onWebViewCreated: _onWebViewCreated,
                    onLoadStart: _onLoadStart,
                    onLoadStop: _onLoadStop,
                    onProgressChanged: _onProgressChanged,
                    onLoadError: _onLoadError,
                    onReceivedServerTrustAuthRequest: _onReceivedServerTrustAuthRequest,
                  );
                },
              ),
            ),
            // 底部按鈕列
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      if (await _controller.canGoBack()) {
                        _controller.goBack();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () async {
                      if (await _controller.canGoForward()) {
                        _controller.goForward();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _controller.reload();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () {
                      _controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(widget.url)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }
}
