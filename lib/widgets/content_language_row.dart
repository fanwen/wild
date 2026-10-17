import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/cubits/content_language_cubit.dart';
import 'package:wild/l10n/content_language.dart';
import 'package:wild/l10n/ui_language.dart';

/// 内容字形的显示名（给设置页和阅读器菜单共用）。
String contentLanguageName(ContentLanguage language) => switch (language) {
  ContentLanguage.followUi => l10n('跟随界面语言'),
  ContentLanguage.zhTW => l10n('繁體中文'),
  ContentLanguage.zhCN => l10n('简体中文（原文）'),
};

/// 内容字形选择弹窗：跟随界面语言 / 繁體中文 / 简体中文（原文）。
///
/// 选完立刻生效：内容语言 cubit 一 emit，阅读器发现 `loadedScript` 和当前字形不同
/// 就会重读本章（正文、章节名跟着换）。
Future<void> showContentLanguageDialog(BuildContext context) {
  final cubit = context.read<ContentLanguageCubit>();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => BlocBuilder<ContentLanguageCubit, ContentLanguage>(
      bloc: cubit,
      builder: (context, language) => AlertDialog(
        title: Text(l10n('内容语言')),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final value in ContentLanguage.values)
              RadioListTile<ContentLanguage>(
                dense: true,
                title: Text(contentLanguageName(value)),
                value: value,
                groupValue: language,
                onChanged: (picked) {
                  if (picked != null) cubit.setLanguage(picked);
                  Navigator.of(dialogContext).pop();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n('关闭')),
          ),
        ],
      ),
    ),
  );
}

/// 阅读器设置菜单里的「内容语言」一行：显示当前值，点开选择。
class ContentLanguageRow extends StatelessWidget {
  const ContentLanguageRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentLanguageCubit, ContentLanguage>(
      builder: (context, language) => InkWell(
        onTap: () => showContentLanguageDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(l10n('内容语言')),
              const Spacer(),
              Text(
                contentLanguageName(language),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
