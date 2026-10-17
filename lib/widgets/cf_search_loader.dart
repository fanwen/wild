import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wild/l10n/ui_language.dart';
import 'package:wild/src/rust/api/wenku8.dart'
    show PageStatsNovelCover, getSessionCookieString;
import 'package:wild/src/rust/wenku8/models.dart';

/// 用隐藏 WebView 做搜索 —— 绕 Cloudflare 用。
///
/// 为什么不能用 reqwest 直连：搜索页 `/modules/article/search.php` 被 CF 的 WAF 规则
/// 挡死（直连必 403，返回 "Attention Required! you have been blocked"），
/// 而浏览器内核能过。书架页早就是这么处理 CF 的（`CfBookshelfLoader`），
/// 这里用同一条路子：
///   1. 先加载首页 → 过 CF 挑战、注入 Rust 侧的 session cookie（等于已登录的浏览器）
///   2. 在页面里建一个 form 提交搜索 —— 让浏览器按页面 charset(gbk) 编码关键词，
///      免得 Dart 侧自己去做 GBK 编码
///   3. 结果页上用 JS 把书列表抠成 JSON（选择器与 Rust 的 parse_books 一致：
///      `table.grid tr td > div` → `a[title][href] > img[src]`），翻页信息取 `em#pagestats`
///
/// 抠出来的 JSON 在 Dart 侧映射成 Rust 的 `PageStatsNovelCover`，这样搜索页的
/// 分页/渲染逻辑完全不用改。
class CfSearchLoader extends StatefulWidget {
  const CfSearchLoader({
    super.key,
    required this.apiHost,
    required this.searchType,
    required this.searchKey,
    required this.page,
    required this.onResult,
    required this.onError,
  });

  final String apiHost;

  /// `articlename`（书名）或 `author`（作者）
  final String searchType;
  final String searchKey;
  final int page;

  final void Function(PageStatsNovelCover result) onResult;
  final void Function(String error) onError;

  @override
  State<CfSearchLoader> createState() => _CfSearchLoaderState();
}

/// 把结果页抠出来的 JSON 映射成 Rust 模型（纯函数，方便测）。
PageStatsNovelCover mapSearchJson(String json, int requestedPage) {
  final data = jsonDecode(json) as Map;
  final records =
      (data['items'] as List)
          .map(
            (e) => NovelCover(
              title: (e['title'] ?? '') as String,
              img: (e['img'] ?? '') as String,
              detailUrl: (e['detailUrl'] ?? '') as String,
              aid: (e['aid'] ?? '') as String,
            ),
          )
          .where((n) => n.aid.isNotEmpty)
          .toList();

  var currentPage = requestedPage;
  var maxPage = requestedPage;
  final stats = (data['stats'] ?? '').toString();
  final parts = stats.split('/');
  if (parts.length >= 2) {
    currentPage = int.tryParse(parts[0].trim()) ?? currentPage;
    maxPage = int.tryParse(parts[1].trim()) ?? maxPage;
  }
  if (maxPage < currentPage) maxPage = currentPage;

  return PageStatsNovelCover(
    currentPage: currentPage,
    maxPage: maxPage,
    records: records,
  );
}

class _CfSearchLoaderState extends State<CfSearchLoader> {
  late final WebViewController _controller;
  bool _done = false;
  bool _warmed = false;
  bool _cookiesInjected = false;

  static const _jsExtract = r"""
(function () {
  var items = [];
  var blocks = document.querySelectorAll('table.grid tr td > div');
  for (var i = 0; i < blocks.length; i++) {
    var div = blocks[i];
    var a = div.querySelector('a');
    var img = div.querySelector('img');
    if (!a || !img) continue;
    var href = a.getAttribute('href') || '';
    var aid = href.split('/').pop().replace('.htm', '');
    items.push({
      aid: aid,
      title: a.getAttribute('title') || (a.textContent || '').trim(),
      img: img.getAttribute('src') || '',
      detailUrl: href
    });
  }
  var em = document.querySelector('em#pagestats');
  return JSON.stringify({items: items, stats: em ? (em.textContent || '').trim() : ''});
})()
""";

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: _onPageFinished,
              onWebResourceError: (err) {
                if (!_done) {
                  _done = true;
                  widget.onError('${l10n('WebView 载入失败: ')}${err.description}');
                }
              },
            ),
          )
          ..loadRequest(Uri.parse('${widget.apiHost}/'));
  }

  Future<void> _injectCookies() async {
    if (_cookiesInjected) return;
    try {
      final cookieStr = await getSessionCookieString();
      if (cookieStr.isNotEmpty) {
        final domain = Uri.tryParse(widget.apiHost)?.host ?? 'wenku8.net';
        for (final part in cookieStr.split('; ')) {
          final eq = part.indexOf('=');
          if (eq > 0) {
            final name = part.substring(0, eq);
            final value = part.substring(eq + 1);
            await _controller.runJavaScript(
              'document.cookie = "$name=$value; path=/; domain=.$domain";',
            );
          }
        }
      }
      _cookiesInjected = true;
    } catch (_) {}
  }

  /// 在页面里建 form 提交搜索（浏览器会按 GBK 编码 searchkey）。
  Future<void> _submitSearch() async {
    final type = jsonEncode(widget.searchType);
    final key = jsonEncode(widget.searchKey);
    final js = '''
(function () {
  var f = document.createElement('form');
  f.method = 'GET';
  f.action = '/modules/article/search.php';
  f.innerHTML = '<input name="searchtype" value=' + $type + '>' +
                '<input name="searchkey" value=' + $key + '>' +
                '<input name="page" value="${widget.page}">' +
                '<input name="charset" value="gbk">';
  document.body.appendChild(f);
  f.submit();
  return 'submitted';
})()
''';
    await _controller.runJavaScript(js);
  }

  Future<void> _onPageFinished(String url) async {
    if (_done) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (_done) return;

    final blocked = await _controller.runJavaScriptReturningResult(
      'document.title.toLowerCase().includes("blocked") || '
      '(document.body ? document.body.innerText.includes("Sorry, you have been blocked") : false) '
      '? "yes" : "no"',
    );
    if (blocked.toString().contains('yes')) {
      _done = true;
      widget.onError(l10n('IP 被 Cloudflare 封锁，请尝试更换网络或使用 VPN'));
      return;
    }

    if (!_warmed) {
      final challenge = await _controller.runJavaScriptReturningResult(
        'document.getElementById("challenge-form") !== null ? "yes" : "no"',
      );
      if (challenge.toString().contains('yes')) return; // 等挑战自己过
      _warmed = true;
      await _injectCookies();
      await _submitSearch();
      return;
    }

    if (!url.contains('search.php')) {
      // 提交后没落到搜索页：多半是被弹去登录页
      _done = true;
      widget.onError(l10n('需要先登录才能搜索'));
      return;
    }

    try {
      final raw = await _controller.runJavaScriptReturningResult(_jsExtract);
      final json = _unwrapJsonString(raw.toString());
      _done = true;
      widget.onResult(mapSearchJson(json, widget.page));
    } catch (e) {
      _done = true;
      widget.onError('${l10n('解析结果失败: ')} $e');
    }
  }

  /// webview 的 JS 返回值是 JSON 编码过的字符串（带引号和转义）。
  String _unwrapJsonString(String s) {
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try {
        return jsonDecode(s) as String;
      } catch (_) {
        return s;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: _controller),
    );
  }
}
