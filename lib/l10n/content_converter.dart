import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// 内容文字的简繁转换（两个方向）。
///
/// 词表离线用 OpenCC 预先算好（`lib/assets/l10n/`，注意 asset key 带 `lib/` 前缀）：
/// - `s2twp.txt` + `s2twp_extra.txt`：简 → 繁（台湾用词），OpenCC 的 `s2twp`
/// - `tw2sp.txt` + `tw2sp_extra.txt`：繁（台湾）→ 简，OpenCC 的 `tw2sp`
///
/// 运行期就是把 OpenCC 的多趟转换压成「一趟最长匹配」：命中就替换，
/// 命中不了就把原字符抄过去（非中文整段直接抄，网址/数字零开销）。
class ContentConverter {
  ContentConverter._(
    this._toTraditional,
    this._toTraditionalMax,
    this._toSimplified,
    this._toSimplifiedMax,
  );

  static const List<String> _toTraditionalAssets = [
    'lib/assets/l10n/s2twp.txt',
    'lib/assets/l10n/s2twp_extra.txt',
  ];
  static const List<String> _toSimplifiedAssets = [
    'lib/assets/l10n/tw2sp.txt',
    'lib/assets/l10n/tw2sp_extra.txt',
  ];

  final Map<String, String> _toTraditional;
  final int _toTraditionalMax;
  final Map<String, String> _toSimplified;
  final int _toSimplifiedMax;

  static ContentConverter? _instance;

  /// 还没加载完时是 null（[convertToTraditional] 会原样返回）。
  static ContentConverter? get instance => _instance;

  static bool get isLoaded => _instance != null;

  static Future<ContentConverter> load() async {
    final existing = _instance;
    if (existing != null) return existing;
    final toTraditional = await _read(_toTraditionalAssets);
    final toSimplified = await _read(_toSimplifiedAssets);
    return _instance = ContentConverter._(
      toTraditional.$1,
      toTraditional.$2,
      toSimplified.$1,
      toSimplified.$2,
    );
  }

  /// 读一份或几份词表（后面覆盖前面），返回 (表, 最长键长)。
  static Future<(Map<String, String>, int)> _read(List<String> paths) async {
    final map = <String, String>{};
    var maxLength = 1;
    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      for (final line in const LineSplitter().convert(raw)) {
        if (line.isEmpty || line.startsWith('#')) continue;
        final tab = line.indexOf('\t');
        if (tab <= 0) continue;
        final key = line.substring(0, tab);
        map[key] = line.substring(tab + 1);
        if (key.length > maxLength) maxLength = key.length;
      }
    }
    return (map, maxLength);
  }

  /// 同一个字符串的结果是确定的，缓存起来避免重排/滚动时反复重算。
  final Map<String, String> _cache = {};
  static const int _cacheLimit = 64;

  /// [toTraditional] true = 转成繁体（台湾用词），false = 转成简体。
  String convert(String input, {required bool toTraditional}) {
    if (input.isEmpty || !_hasCjk(input)) return input;
    final cacheKey = '${toTraditional ? 'T' : 'S'}$input';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final result = _convert(
      input,
      toTraditional ? _toTraditional : _toSimplified,
      toTraditional ? _toTraditionalMax : _toSimplifiedMax,
    );
    if (_cache.length >= _cacheLimit) _cache.clear();
    _cache[cacheKey] = result;
    return result;
  }

  String _convert(String input, Map<String, String> table, int maxKeyLength) {
    final buffer = StringBuffer();
    final length = input.length;
    var i = 0;
    while (i < length) {
      final unit = input.codeUnitAt(i);
      final highSurrogate = _isHighSurrogate(unit);
      if (!highSurrogate && !_isCjkToConvert(unit)) {
        // 整段非中文（标点、ASCII）直接抄
        buffer.writeCharCode(unit);
        i++;
        continue;
      }
      final limit = math.min(maxKeyLength, length - i);
      var matched = false;
      for (var size = limit; size >= (highSurrogate ? 2 : 1); size--) {
        // 别把代理对（罕用字、emoji）切开
        if (size > 1 && _isHighSurrogate(input.codeUnitAt(i + size - 1)))
          continue;
        final value = table[input.substring(i, i + size)];
        if (value != null) {
          buffer.write(value);
          i += size;
          matched = true;
          break;
        }
      }
      if (matched) continue;
      buffer.writeCharCode(unit);
      if (highSurrogate && i + 1 < length) {
        buffer.writeCharCode(input.codeUnitAt(i + 1));
        i += 2;
      } else {
        i++;
      }
    }
    return buffer.toString();
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xd800 && unit <= 0xdbff;

  /// 需要查表的码位：CJK 统一表意文字（含扩展 A）、兼容表意文字、注音/拼音扩展。
  static bool _isCjkToConvert(int unit) =>
      (unit >= 0x3400 && unit <= 0x4dbf) ||
      (unit >= 0x4e00 && unit <= 0x9fff) ||
      (unit >= 0xf900 && unit <= 0xfaff);

  static bool _hasCjk(String input) {
    for (var i = 0; i < input.length; i++) {
      final unit = input.codeUnitAt(i);
      if (_isCjkToConvert(unit) || _isHighSurrogate(unit)) return true;
    }
    return false;
  }
}
