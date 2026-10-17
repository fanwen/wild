import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wild/l10n/ui_language.dart';
import 'package:wild/src/rust/api/database.dart';

/// 界面语言的读写（属性键 `ui_language`）。
///
/// 语言决定两件事：
/// - MaterialApp 的 locale（系统级文案、日期选择器等跟着变）
/// - [l10n] 走简体还是繁体（app 自己的界面文字）
class UiLocaleCubit extends Cubit<UiLanguage> {
  static const String _key = 'ui_language';

  UiLocaleCubit() : super(UiLanguage.system);

  static Locale get _deviceLocale =>
      WidgetsBinding.instance.platformDispatcher.locale;

  Future<void> loadLanguage() async {
    var language = UiLanguage.system;
    try {
      final raw = await loadProperty(key: _key);
      language = switch (raw) {
        'zh_TW' => UiLanguage.zhTW,
        'zh_CN' => UiLanguage.zhCN,
        _ => UiLanguage.system,
      };
    } catch (e) {
      print('[界面语言] 读取失败: $e');
    }
    _apply(language);
  }

  Future<void> setLanguage(UiLanguage language) async {
    _apply(language);
    try {
      await saveProperty(key: _key, value: _storageValue(language));
    } catch (e) {
      print('[界面语言] 保存失败: $e');
    }
  }

  void _apply(UiLanguage language) {
    setUiTraditional(useTraditionalOf(language, _deviceLocale));
    emit(language);
  }

  static String _storageValue(UiLanguage language) => switch (language) {
    UiLanguage.system => 'system',
    UiLanguage.zhTW => 'zh_TW',
    UiLanguage.zhCN => 'zh_CN',
  };
}
