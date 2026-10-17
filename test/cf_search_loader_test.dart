import 'package:flutter_test/flutter_test.dart';
import 'package:wild/widgets/cf_search_loader.dart';

/// 隐藏 WebView 抠出来的搜索结果是 JSON，映射成 Rust 模型的这段逻辑在这里测。
/// 选择器与 Rust 的 parse_books 一致（table.grid tr td > div → a[title][href] > img）。
void main() {
  test('正常结果 + 翻页信息', () {
    const json = '{"items":['
        '{"aid":"1269","title":"龍蛋","img":"http://img.wenku8.com/image/1/1269/1269s.jpg",'
        '"detailUrl":"https://www.wenku8.net/book/1269.htm"},'
        '{"aid":"2070","title":"轉生後的大聖女","img":"http://img.wenku8.com/image/2/2070/2070s.jpg",'
        '"detailUrl":"https://www.wenku8.net/book/2070.htm"}'
        '],"stats":"1/3"}';

    final page = mapSearchJson(json, 1);

    expect(page.currentPage, 1);
    expect(page.maxPage, 3);
    expect(page.records.length, 2);
    expect(page.records.first.aid, '1269');
    expect(page.records.first.title, '龍蛋');
    expect(page.records.first.img, contains('1269s.jpg'));
    expect(page.records.first.detailUrl, contains('/book/1269.htm'));
  });

  test('没有结果 / 没有翻页信息时不炸（按请求页兜底）', () {
    final page = mapSearchJson('{"items":[],"stats":""}', 2);
    expect(page.records, isEmpty);
    expect(page.currentPage, 2);
    expect(page.maxPage, 2);
  });

  test('丢掉没有 aid 的脏行（例如广告位）', () {
    const json = '{"items":['
        '{"aid":"","title":"广告","img":"","detailUrl":""},'
        '{"aid":"100","title":"正经书","img":"x.jpg","detailUrl":"/book/100.htm"}'
        '],"stats":"1/1"}';
    final page = mapSearchJson(json, 1);
    expect(page.records.length, 1);
    expect(page.records.single.aid, '100');
  });
}
