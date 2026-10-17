import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wild/l10n/content_language.dart';
import 'package:wild/l10n/content_converter.dart';
import 'package:wild/src/rust/api/database.dart';

/// 内容语言设置（属性键 `content_language`）：跟随界面语言 / 繁體中文 / 简体中文。
///
/// 只决定「要不要把网页原文（简体）转成繁体」，
/// 具体转换在 [cv] 里按当前标志做，所以切换后重建界面即可见效。
class ContentLanguageCubit extends Cubit<ContentLanguage> {
  static const String _key = 'content_language';

  ContentLanguageCubit() : super(ContentLanguage.followUi);

  Future<void> load() async {
    var language = ContentLanguage.followUi;
    try {
      language = contentLanguageFromStorage(await loadProperty(key: _key));
    } catch (e) {
      print('[内容语言] 读取失败: $e');
    }
    setContentTraditional(contentIsTraditional(language));
    emit(language);
  }

  Future<void> setLanguage(ContentLanguage language) async {
    setContentTraditional(contentIsTraditional(language));
    emit(language);
    try {
      await saveProperty(key: _key, value: contentLanguageToStorage(language));
    } catch (e) {
      print('[内容语言] 保存失败: $e');
    }
  }

  /// 转换表是 assets，首次用之前先加载好（界面语言/内容语言都还没读，先不改变行为）。
  static Future<void> initConverter() async {
    if (ContentConverter.isLoaded) return;
    try {
      await ContentConverter.load();
    } catch (e) {
      print('[内容语言] 转换表加载失败: $e');
    }
  }
}
