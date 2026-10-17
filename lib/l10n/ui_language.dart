import 'dart:ui' show Locale;

import 'package:wild/l10n/zh_tw_strings.dart';

/// 界面语言设置项：跟随系统 / 繁體中文 / 简体中文。
enum UiLanguage { system, zhTW, zhCN }

/// app 支持的界面语言。
///
/// 顺序即「跟随系统」时匹配不到设备语言后的兜底 —— 简中是 app 的原生文案。
const List<Locale> kSupportedLocales = [Locale('zh', 'CN'), Locale('zh', 'TW')];

/// 对应 MaterialApp.locale：`null` = 交给 Flutter 按设备语言在 [kSupportedLocales] 里挑。
Locale? materialLocaleOf(UiLanguage language) => switch (language) {
  UiLanguage.system => null,
  UiLanguage.zhTW => const Locale('zh', 'TW'),
  UiLanguage.zhCN => const Locale('zh', 'CN'),
};

/// 当前该不该显示繁体。
///
/// 明确选了就按选的；跟随系统时看设备语言：zh-Hant / zh-TW、HK、MO 才是繁体，
/// 其他语言（含 en，以及 zh-Hans）都回落到简中。
bool useTraditionalOf(UiLanguage language, Locale deviceLocale) {
  switch (language) {
    case UiLanguage.zhTW:
      return true;
    case UiLanguage.zhCN:
      return false;
    case UiLanguage.system:
      if (deviceLocale.languageCode != 'zh') return false;
      if (deviceLocale.scriptCode == 'Hant') return true;
      if (deviceLocale.scriptCode == 'Hans') return false;
      return const {'TW', 'HK', 'MO'}.contains(deviceLocale.countryCode);
  }
}

bool _traditional = false;

/// 当前是否繁体。只给测试和 [l10n] 用。
bool get uiIsTraditional => _traditional;

/// 由 [UiLocaleCubit] / main 在构建界面前设置。
///
/// 这里用普通全局变量而不是 InheritedWidget：界面文字的调用点有几百处，
/// 传 context 太吵；切换语言时 MaterialApp 会整体重建（locale 变了），
/// 所以不需要额外的通知机制。
void setUiTraditional(bool value) => _traditional = value;

/// 界面文字：调用点照写简体原文（app 原生文案），
/// 繁体模式下查表转换，表里没有的原样返回。
String l10n(String zhHans) =>
    _traditional ? (kZhTwStrings[zhHans] ?? zhHans) : zhHans;
