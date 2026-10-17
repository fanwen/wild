import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wild/pages/novel/font_family_cubit.dart';
import 'package:wild/l10n/ui_language.dart';

/// 设置里的「字体」一行：显示当前字体名，点「选择」弹出字体选择框。
///
/// [cubit] 显式传进来（`context.read<FontFamilyCubit>()` 或 `context.read<UiFontFamilyCubit>()`）——
/// 两份字体是不同实例，别靠泛型上下文查找，写死才不会有歧义。
///
/// [onFontChanged] 在字体真的变了之后调用 —— 普通阅读器要重新分页（字宽变了），
/// HTML 阅读器要重新取一次正文；界面字体不用传（主题跟着重建）。
class ReaderFontRow extends StatelessWidget {
  /// 行标题，也是选择框的标题。
  final String label;

  /// 要改的那份字体：正文用 `FontFamilyCubit`，界面用 `UiFontFamilyCubit`。
  final FontFamilyCubit cubit;

  final Future<void> Function()? onFontChanged;

  const ReaderFontRow({
    super.key,
    required this.cubit,
    this.label = '字体',
    this.onFontChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FontFamilyCubit, ReaderFont>(
      bloc: cubit,
      builder: (context, font) {
        return Row(
          children: [
            Text(l10n(label)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n(font.label),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontFamily: font.isCustom ? font.family : null,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showFontDialog(context, onFontChanged),
              child: Text(l10n('选择')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFontDialog(
    BuildContext context,
    Future<void> Function()? onFontChanged,
  ) async {
    final cubit = this.cubit;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BlocBuilder<FontFamilyCubit, ReaderFont>(
          bloc: cubit,
          builder: (context, font) {
            return AlertDialog(
              title: Text(l10n(label)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      l10n('中文预览效果：轻小说文库 Aa 123'),
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: font.isCustom ? font.family : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    dense: true,
                    title: Text(l10n('系统默认')),
                    trailing: font.isCustom ? null : const Icon(Icons.check),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      await cubit.useSystemFont();
                      if (onFontChanged != null) await onFontChanged();
                    },
                  ),
                  if (font.isCustom)
                    ListTile(
                      dense: true,
                      title: Text(
                        l10n(font.label),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: font.family),
                      ),
                      trailing: const Icon(Icons.check),
                    ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_open),
                    title: Text(l10n('从文件选择（.ttf / .otf）')),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      final error = await cubit.pickCustomFont();
                      if (error != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n(error))),
                        );
                        return;
                      }
                      if (onFontChanged != null) await onFontChanged();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
