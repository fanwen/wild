import 'package:wild/l10n/content_converter.dart';
import 'package:wild/l10n/ui_language.dart';

/// 内容文字（正文、书名、作者、简介、章节名……）的语言设置。
enum ContentLanguage { followUi, zhTW, zhCN }

/// 存进数据库（属性键 `content_language`）的值。
String contentLanguageToStorage(ContentLanguage language) => switch (language) {
  ContentLanguage.followUi => 'follow_ui',
  ContentLanguage.zhTW => 'zh_TW',
  ContentLanguage.zhCN => 'zh_CN',
};

ContentLanguage contentLanguageFromStorage(String raw) => switch (raw) {
  'zh_TW' => ContentLanguage.zhTW,
  'zh_CN' => ContentLanguage.zhCN,
  _ => ContentLanguage.followUi,
};

/// 内容该用哪种字形（网页原文简繁混杂，所以两个方向都要能转）。
enum ContentScript { traditional, simplified }

/// 内容目标字形：繁体 = 台湾用词（OpenCC s2twp），简体 = 大陆用词（tw2sp）。
ContentScript contentScriptOf(ContentLanguage language) => switch (language) {
  ContentLanguage.followUi =>
    uiIsTraditional ? ContentScript.traditional : ContentScript.simplified,
  ContentLanguage.zhTW => ContentScript.traditional,
  ContentLanguage.zhCN => ContentScript.simplified,
};

/// 兼容旧调用：内容是不是繁体。
bool contentIsTraditional(ContentLanguage language) =>
    contentScriptOf(language) == ContentScript.traditional;

ContentScript _script = ContentScript.simplified;

/// 当前内容字形。给测试用。
ContentScript get contentScriptNow => _script;

/// 兼容旧调用：当前内容是不是繁体。
bool get contentIsTraditionalNow => _script == ContentScript.traditional;

/// 由 [ContentLanguageCubit] / main 在构建界面前设置。
void setContentScript(ContentScript script) => _script = script;

/// 兼容旧调用。
void setContentTraditional(bool traditional) => setContentScript(
  traditional ? ContentScript.traditional : ContentScript.simplified,
);

/// 内容文字入口：调用点照写原文，
/// 按当前设置转成繁体（台湾用词）或简体；词表还没加载时原样返回。
String cv(String text) {
  final converter = ContentConverter.instance;
  if (converter == null) return text;
  return converter.convert(
    text,
    toTraditional: _script == ContentScript.traditional,
  );
}

/// 列表版（标签、章节名列表等）。
List<String> cvAll(Iterable<String> texts) => [
  for (final text in texts) cv(text),
];
