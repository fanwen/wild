import 'dart:async';

import 'package:flutter/material.dart';
import '../src/rust/api/wenku8.dart';
import '../src/rust/wenku8/models.dart';
import '../widgets/cached_image.dart';
import '../widgets/cf_search_loader.dart';
import 'package:wild/l10n/ui_language.dart';
import 'package:wild/l10n/content_language.dart';

class SearchPage extends StatefulWidget {
  final String? initialSearchType;
  final String? initialSearchKey;

  const SearchPage({super.key, this.initialSearchType, this.initialSearchKey});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  late String _searchType;
  PageStatsNovelCover? _searchResults;
  bool _isLoading = false;
  List<SearchHistory>? _searchHistories;
  String? _errorMessage;

  /// 非空时在页面里挂一个隐藏 WebView 去搜索（直连被 CF 拦时的兜底）
  _WebViewSearch? _webViewSearch;
  Completer<PageStatsNovelCover> _resultCompleter =
      Completer<PageStatsNovelCover>();

  /// 直连被 CF 403 过 → 后面翻页直接走 WebView，不再白等一次 403
  bool _directBlocked = false;

  /// 站点地址（WebView 兜底要用）
  String _apiHost = 'https://www.wenku8.net';

  @override
  void initState() {
    super.initState();
    _searchType = widget.initialSearchType ?? 'articlename';
    getApiHost()
        .then((host) {
          if (mounted && host.isNotEmpty) setState(() => _apiHost = host);
        })
        .catchError((_) {});
    if (widget.initialSearchKey != null) {
      _searchController.text = widget.initialSearchKey!;
      _search(refresh: true);
    }
    _loadSearchHistories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistories() async {
    try {
      final histories = await searchHistories();
      setState(() {
        _searchHistories = histories;
      });
    } catch (e) {
      // 忽略加载历史记录失败
    }
  }

  Future<void> _search({bool refresh = false}) async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _errorMessage = null;
        _searchResults = null;
      });
      return;
    }
    if (_isLoading) return;

    print(
      '开始搜索: type=${_searchType}, key=${_searchController.text}, refresh=$refresh',
    );

    setState(() {
      _isLoading = true;
      if (refresh) {
        _searchResults = null;
        _errorMessage = null;
      }
    });

    final page = refresh ? 1 : (_searchResults?.currentPage ?? 0) + 1;
    try {
      PageStatsNovelCover results;
      if (_directBlocked) {
        results = await _searchViaWebView(page);
      } else {
        try {
          results = await search(
            searchType: _searchType,
            searchKey: _searchController.text,
            page: page,
          );
        } catch (e) {
          // 搜索页被 Cloudflare WAF 拦（直连必 403）→ 换隐藏 WebView 抓 HTML，
          // 再交给 Rust 的解析器（和直连同一条解析路径）
          print('直连搜索失败，改用 WebView: $e');
          _directBlocked = true;
          results = await _searchViaWebView(page);
        }
      }

      print('搜索成功: 找到 ${results.records.length} 条结果');

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _searchResults = results;
        } else {
          _searchResults = PageStatsNovelCover(
            currentPage: results.currentPage,
            maxPage: results.maxPage,
            records: [..._searchResults!.records, ...results.records],
          );
        }
        _isLoading = false;
        _errorMessage = null;
      });

      // 刷新搜索历史
      _loadSearchHistories();
    } catch (e) {
      print('搜索失败: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyError(e);
        _searchResults = null; // 确保清除搜索结果
      });
    }
  }

  /// 用隐藏 WebView 搜索（直连被 CF WAF 403，只能走浏览器内核）。
  Future<PageStatsNovelCover> _searchViaWebView(int page) async {
    if (!mounted) {
      return PageStatsNovelCover(
        currentPage: page,
        maxPage: page,
        records: const [],
      );
    }
    _resultCompleter = Completer<PageStatsNovelCover>();
    final completer = _resultCompleter;
    setState(() {
      _webViewSearch = _WebViewSearch(
        searchType: _searchType,
        searchKey: _searchController.text,
        page: page,
      );
    });
    try {
      return await completer.future.timeout(const Duration(seconds: 60));
    } finally {
      if (mounted) setState(() => _webViewSearch = null);
    }
  }

  /// 错误信息只留要点：AnyhowException + backtrace 太吵
  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('403')) {
      return l10n('搜索被 Cloudflare 拦截，请稍后重试或更换网络');
    }
    final firstLine = text.split('\n').first;
    return firstLine.length > 200 ? firstLine.substring(0, 200) : firstLine;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_webViewSearch != null)
          Positioned(
            left: 0,
            top: 0,
            child: CfSearchLoader(
              apiHost: _apiHost,
              searchType: _webViewSearch!.searchType,
              searchKey: _webViewSearch!.searchKey,
              page: _webViewSearch!.page,
              onResult: (result) {
                if (!_resultCompleter.isCompleted) {
                  _resultCompleter.complete(result);
                }
              },
              onError: (error) {
                if (!_resultCompleter.isCompleted) {
                  _resultCompleter.completeError(error);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n('搜索')),
        actions: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'articlename', label: Text(l10n('书名'))),
              ButtonSegment(value: 'author', label: Text(l10n('作者'))),
            ],
            selected: {_searchType},
            onSelectionChanged: (Set<String> selection) {
              setState(() {
                _searchType = selection.first;
                _searchController.clear();
                _searchResults = null;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n('搜索小说或作者'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _search(refresh: true);
                }
              },
            ),
          ),
          // 搜索结果或搜索历史
          if (_searchController.text.isEmpty &&
              _searchHistories != null &&
              _searchHistories!.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchHistories!.length,
                itemBuilder: (context, index) {
                  final history = _searchHistories![index];
                  return ListTile(
                    leading: Icon(
                      history.searchType == 'articlename'
                          ? Icons.book
                          : Icons.person,
                      color:
                          history.searchType == 'articlename'
                              ? Colors.blue
                              : Colors.green,
                    ),
                    title: Text(
                      history.searchKey,
                      style: TextStyle(
                        color:
                            history.searchType == 'articlename'
                                ? Colors.blue
                                : Colors.green,
                      ),
                    ),
                    subtitle: Text(
                      history.searchType == 'articlename'
                          ? l10n('书名搜索')
                          : l10n('作者搜索'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      _searchController.text = history.searchKey;
                      setState(() {
                        _searchType = history.searchType;
                      });
                      _search(refresh: true);
                    },
                  );
                },
              ),
            )
          // 错误状态
          else if (_errorMessage != null)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _search(refresh: true),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n('搜索失败 (下拉刷新)'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // 搜索结果
          else if (_searchResults != null)
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 200 &&
                      !_isLoading &&
                      _searchResults!.currentPage < _searchResults!.maxPage) {
                    _search();
                  }
                  return true;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 207 / 307,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount:
                      _searchResults!.records.length +
                      (_searchResults!.currentPage < _searchResults!.maxPage
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index >= _searchResults!.records.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final novel = _searchResults!.records[index];
                    return _NovelCoverCard(novel: novel);
                  },
                ),
              ),
            )
          // 空状态
          else
            Center(child: Center(child: Text(l10n('输入关键词开始搜索')))),
        ],
      ),
    );
  }
}

class _NovelCoverCard extends StatelessWidget {
  final NovelCover novel;

  const _NovelCoverCard({required this.novel});

  @override
  Widget build(BuildContext context) {
    var card = Card(
      clipBehavior: Clip.antiAlias,
      elevation: .5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: CachedImage(url: novel.img, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              cv(novel.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/novel/info', arguments: novel.aid);
      },
      child: card,
    );
  }
}

/// 隐藏 WebView 搜索的参数
class _WebViewSearch {
  const _WebViewSearch({
    required this.searchType,
    required this.searchKey,
    required this.page,
  });

  final String searchType;
  final String searchKey;
  final int page;
}
