import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wild/l10n/zh_tw_strings.dart';
import 'package:wild/l10n/ui_language.dart';

/// 界面文案的「查表覆盖率」：代码里出现的每个 l10n('…') 键都必须能在繁体表里查到。
///
/// 漏了会怎样：繁体界面下那一处原样吐简体（用户直接看得到）。
/// 表是 gen_table3.py 生成的（把 lib/ 里所有 l10n 键收全），这个测试是它的守门员。
final _callPattern = RegExp(
  r"""l10n\(\s*(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")\s*[,)]""",
);

List<(String, String)> _sourceKeys() {
  final found = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('zh_tw_strings.dart')) continue;
    final src = entity.readAsStringSync();
    for (final m in _callPattern.allMatches(src)) {
      final raw = (m.group(1) ?? m.group(2))!;
      final key = raw.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
      found.putIfAbsent(key, () => entity.path);
    }
  }
  return found.entries.map((e) => (e.key, e.value)).toList();
}

void main() {
  final keys = _sourceKeys();

  test('代码里能找到 l10n 调用点', () {
    expect(keys.length, greaterThan(150));
  });

  test('每个 l10n 键都能在繁体表里查到', () {
    final missing = keys.where((e) => !kZhTwStrings.containsKey(e.$1)).toList();
    expect(
      missing.map((e) => '${e.$1}  ← ${e.$2}').toList(),
      isEmpty,
      reason: '这些文案在繁体界面下会漏出简体，跑 gen_table3.py 重新生成表',
    );
  });

  test('键里不该再有 \$ 插值（插值必须拆成静态片段）', () {
    final bad = keys.where((e) => e.$1.contains(r'$')).toList();
    expect(bad.map((e) => '${e.$1} ← ${e.$2}').toList(), isEmpty);
  });

  test('抽查：翻译结果符合台湾用词', () {
    expect(kZhTwStrings['设置浅色背景'], '設定淺色背景');
    expect(kZhTwStrings['更新浅色背景'], '更新淺色背景');
    expect(kZhTwStrings['内容设置'], '內容設定');
    expect(kZhTwStrings['跟随界面语言'], '跟隨介面語言');
    expect(kZhTwStrings['设置'], '設定');
  });

  test('繁体模式下这些键真的会转（不再漏简体）', () {
    setUiTraditional(true);
    addTearDown(() => setUiTraditional(false));
    expect(l10n('设置浅色背景'), '設定淺色背景');
    expect(l10n('内容设置'), '內容設定');
    expect(l10n('删除失败: '), '刪除失敗: ');
    expect(l10n('未设置'), '未設定');
  });
}
