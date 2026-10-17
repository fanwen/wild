import 'package:flutter_test/flutter_test.dart';
import 'package:wild/pages/novel/reader_markers.dart';

void main() {
  test('没有标记的一行原样当一个文字片段', () {
    final parts = splitImageMarkers('这是一段正文。');
    expect(parts.length, 1);
    expect(parts[0].isImage, isFalse);
    expect(parts[0].text, '这是一段正文。');
  });

  test('标记在行首（插图独占一行）——不会死循环', () {
    final parts = splitImageMarkers(
      '<!--image-->https://pic.777743.xyz/1/1269/40162/48046.jpg<!--image-->',
    );
    expect(parts.length, 1);
    expect(parts[0].isImage, isTrue);
    expect(parts[0].imageUrl, 'https://pic.777743.xyz/1/1269/40162/48046.jpg');
  });

  test('一行里多张插图（插图章节就是连续 20 张）', () {
    final parts = splitImageMarkers(
      '<!--image-->http://a/1.jpg<!--image--><!--image-->http://a/2.jpg<!--image-->',
    );
    expect(parts.map((p) => p.imageUrl).toList(), [
      'http://a/1.jpg',
      'http://a/2.jpg',
    ]);
  });

  test('文字 + 插图 + 文字，顺序保持不变', () {
    final parts = splitImageMarkers(
      '第一段<!--image-->http://a/1.jpg<!--image-->后面的话',
    );
    expect(parts.length, 3);
    expect(parts[0].text, '第一段');
    expect(parts[1].imageUrl, 'http://a/1.jpg');
    expect(parts[2].text, '后面的话');
  });

  test('空行 / 只有空白：不产生片段', () {
    expect(splitImageMarkers(''), isEmpty);
    expect(splitImageMarkers('   '), isEmpty);
    expect(splitImageMarkers('<!--image-->  <!--image-->'), isEmpty);
  });

  test('真实章节内容（带水印被 Rust 剔掉后的形状）切出来是图 + 文', () {
    const content = '<!--image-->https://pic.777743.xyz/1/1269/40162/48046.jpg<!--image-->\n'
        '&#160;&#160;&#160;&#160;——很久很久以前。\n';
    final parts = content.split('\n').expand(splitImageMarkers).toList();
    expect(parts.where((p) => p.isImage).length, 1);
    expect(parts.where((p) => !p.isImage).length, 1);
    expect(parts.first.imageUrl,
        'https://pic.777743.xyz/1/1269/40162/48046.jpg');
    expect(parts.last.text, '&#160;&#160;&#160;&#160;——很久很久以前。');
  });
}
