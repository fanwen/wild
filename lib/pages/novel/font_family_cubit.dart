import 'package:wild/l10n/ui_language.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wild/src/rust/api/database.dart';

/// 阅读器字体：「系统默认」或用户从手机里选的字体文件（.ttf/.otf）。
class ReaderFont {
  static const String systemLabel = '系统默认';

  /// 注册到引擎的字体族名，空串 = 系统默认字体。
  final String family;

  /// 界面上显示的名字（文件名）。
  final String label;

  const ReaderFont({this.family = '', this.label = systemLabel});

  bool get isCustom => family.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderFont &&
          runtimeType == other.runtimeType &&
          family == other.family &&
          label == other.label;

  @override
  int get hashCode => family.hashCode ^ label.hashCode;
}

/// 用户自选字体的加载/持久化。
///
/// 字体文件被拷进 app 数据目录（`$root/<fileBaseName>.*`），读取时用 [FontLoader] 以
/// 「内容指纹」为族名注册 —— 族名随内容变化，所以换字体就是换族名，引擎不会拿到旧字形；
/// 同一份文件重复加载族名不变，也不会越用越多。
///
/// 同一套逻辑有两份实例（`keyPrefix` / `fileBaseName` 不同，互不干扰）：
/// - [FontFamilyCubit] —— 阅读正文的字体（属性 `reader_font_*`，文件 `reader_font.*`）
/// - [UiFontFamilyCubit] —— app 界面（MaterialApp 主题）的字体（属性 `ui_font_*`）
class FontFamilyCubit extends Cubit<ReaderFont> {
  final String _keyPath;
  final String _keyLabel;
  final String _keyFamily;
  final String _fileBaseName;

  String? _rootPath;
  Future<void> _ready = Future.value();

  FontFamilyCubit({
    String keyPrefix = 'reader_font',
    String fileBaseName = 'reader_font',
  }) : _keyPath = '${keyPrefix}_path',
       _keyLabel = '${keyPrefix}_label',
       _keyFamily = '${keyPrefix}_family',
       _fileBaseName = fileBaseName,
       super(const ReaderFont());

  /// 分页（TextPainter 量高度）之前必须等字体真的注册好，否则量出来的行高跟渲染出来的不一致。
  Future<void> get ready => _ready;

  Future<void> init(String root) async {
    _rootPath = root;
    _ready = loadFont();
    await _ready;
  }

  Future<void> loadFont() async {
    try {
      final path = await loadProperty(key: _keyPath);
      final label = await loadProperty(key: _keyLabel);
      final family = await loadProperty(key: _keyFamily);
      if (family.isEmpty || path.isEmpty || !File(path).existsSync()) {
        emit(const ReaderFont());
        return;
      }
      await _register(family, await File(path).readAsBytes());
      emit(ReaderFont(family: family, label: label.isEmpty ? '自定义字体' : label));
    } catch (e) {
      print('[字体] 加载已保存字体失败: $e');
      emit(const ReaderFont());
    }
  }

  /// 让用户选一个字体文件。返回错误文案（成功返回 null）。
  Future<String?> pickCustomFont() async {
    if (_rootPath == null) return l10n('字体目录未就绪，请重启应用后再试');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null; // 用户取消

      final picked = result.files.single;
      final bytes =
          picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) return l10n('读不到字体文件内容');

      final reject = _rejectReason(bytes);
      if (reject != null) return reject;

      final extension = _looksLikeCff(bytes) ? 'otf' : 'ttf';
      final destination = File('$_rootPath/$_fileBaseName.$extension');
      await destination.writeAsBytes(bytes, flush: true);

      final family = '${_fileBaseName}_${_fingerprint(bytes)}';
      try {
        await _register(family, bytes);
      } catch (e) {
        try {
          await destination.delete();
        } catch (_) {
          // 删不掉就算了，下次选择会覆盖
        }
        print('[字体] 注册字体失败: $e');
        return l10n('字体加载失败，请换一个字体文件');
      }

      final label = picked.name.isEmpty ? '自定义字体' : picked.name;
      await saveProperty(key: _keyPath, value: destination.path);
      await saveProperty(key: _keyLabel, value: label);
      await saveProperty(key: _keyFamily, value: family);

      emit(ReaderFont(family: family, label: label));
      return null;
    } catch (e) {
      print('[字体] 选择字体失败: $e');
      return '${l10n('选择字体失败：')}$e';
    }
  }

  /// 回到系统默认字体（保留已下载的字体文件，方便再切回来）。
  Future<void> useSystemFont() async {
    await saveProperty(key: _keyPath, value: '');
    await saveProperty(key: _keyLabel, value: '');
    await saveProperty(key: _keyFamily, value: '');
    emit(const ReaderFont());
  }

  Future<void> _register(String family, Uint8List bytes) async {
    final loader = FontLoader(family);
    loader.addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  }

  /// ttc（字体集合）Flutter 加载不了，先跟用户说清楚，别静默失败。
  String? _rejectReason(Uint8List bytes) {
    if (bytes.length < 4) return l10n('字体文件不完整');
    final tag = String.fromCharCodes(bytes.sublist(0, 4));
    if (tag == 'ttcf') return l10n('不支持字体集合（.ttc），请选单个 .ttf / .otf 文件');
    final isTtf =
        bytes[0] == 0x00 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00;
    final isOtto = tag == 'OTTO';
    final isTrue = tag == 'true';
    if (!isTtf && !isOtto && !isTrue) return l10n('这不是字体文件（仅支持 .ttf / .otf）');
    return null;
  }

  bool _looksLikeCff(Uint8List bytes) =>
      String.fromCharCodes(bytes.sublist(0, 4)) == 'OTTO';

  /// FNV-1a：同样的文件永远得到同样的族名，换文件就换族名。
  String _fingerprint(Uint8List bytes) {
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// app 界面（MaterialApp 主题）的字体，和阅读正文的 [FontFamilyCubit] 各自独立。
///
/// 单独一个类型是为了 `context.read<...>()` 不会跟 [FontFamilyCubit] 撞在一起
/// （provider 按精确的泛型参数查找）。
class UiFontFamilyCubit extends FontFamilyCubit {
  UiFontFamilyCubit() : super(keyPrefix: 'ui_font', fileBaseName: 'ui_font');
}

/// 把界面字体套到主题上：只改字体族，颜色/圆角/组件样式都不动。
///
/// 同时改 `textTheme` 和 `primaryTextTheme`（AppBar 标题走后者），
/// 这样按钮、对话框、列表项这些「从主题取默认字号」的文字都会跟着换。
ThemeData applyUiFontToTheme(ThemeData base, ReaderFont font) {
  if (!font.isCustom) return base;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: font.family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: font.family),
  );
}
