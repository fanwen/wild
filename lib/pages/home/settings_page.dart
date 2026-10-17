import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/cubits/screen_up_on_reading_property.dart';
import 'package:wild/cubits/screen_up_on_scroll_property.dart';
import 'package:wild/pages/auth_cubit.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:wild/pages/novel/font_family_cubit.dart';
import 'package:wild/widgets/reader_font_row.dart';
import 'package:wild/cubits/ui_locale_cubit.dart';
import 'package:wild/l10n/ui_language.dart';
import 'package:wild/l10n/content_language.dart';
import 'package:wild/cubits/content_language_cubit.dart';
import 'package:wild/pages/novel/reader_type_cubit.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'package:wild/cubits/api_host_cubit.dart';
import 'package:wild/cubits/volume_control_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n('设置'))),
      body: BlocBuilder<ThemeCubit, ReaderTheme>(
        builder: (context, theme) {
          return ListView(
            children: [
              const SizedBox(height: 8),
              // 阅读器设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('阅读器设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    BlocBuilder<ReaderTypeCubit, ReaderType>(
                      builder: (context, type) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n('阅读器类型')),
                              const SizedBox(height: 8),
                              SegmentedButton<ReaderType>(
                                segments: [
                                  ButtonSegment<ReaderType>(
                                    value: ReaderType.normal,
                                    label: Text(l10n('普通阅读器')),
                                    icon: Icon(Icons.book),
                                  ),
                                  ButtonSegment<ReaderType>(
                                    value: ReaderType.html,
                                    label: Text(l10n('HTML阅读器')),
                                    icon: Icon(Icons.html),
                                  ),
                                ],
                                selected: {type},
                                onSelectionChanged: (
                                  Set<ReaderType> types,
                                ) async {
                                  await context
                                      .read<ReaderTypeCubit>()
                                      .updateType(types.first);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (Platform.isAndroid || Platform.isIOS) ...[
                      screenUpOnReadingSetting(),
                      screenUpOnScrollSetting(),
                      const SizedBox(height: 16),
                    ],
                    // 音量键控制设置（安卓 & iOS）
                    if (Platform.isAndroid || Platform.isIOS) ...[
                      BlocBuilder<VolumeControlCubit, bool>(
                        builder: (context, isEnabled) {
                          return SwitchListTile(
                            title: Text(l10n('音量键翻页')),
                            value: isEnabled,
                            onChanged: (value) {
                              context
                                  .read<VolumeControlCubit>()
                                  .updateVolumeControl(value);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              // 界面设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('界面设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // 界面字体：只作用于 app 的界面文字，和阅读正文的字体互不影响
                      child: ReaderFontRow(
                        label: l10n('界面字体'),
                        cubit: context.read<UiFontFamilyCubit>(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        l10n('只改 app 界面文字；阅读正文的字体在阅读器的「设置」里单独选。'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        l10n('语言'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    BlocBuilder<UiLocaleCubit, UiLanguage>(
                      builder: (context, language) {
                        return Column(
                          children: [
                            RadioListTile<UiLanguage>(
                              title: Text(l10n('跟随系统')),
                              value: UiLanguage.system,
                              groupValue: language,
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<UiLocaleCubit>().setLanguage(
                                    value,
                                  );
                                }
                              },
                            ),
                            RadioListTile<UiLanguage>(
                              title: Text(l10n('繁體中文')),
                              value: UiLanguage.zhTW,
                              groupValue: language,
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<UiLocaleCubit>().setLanguage(
                                    value,
                                  );
                                }
                              },
                            ),
                            RadioListTile<UiLanguage>(
                              title: Text(l10n('简体中文')),
                              value: UiLanguage.zhCN,
                              groupValue: language,
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<UiLocaleCubit>().setLanguage(
                                    value,
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // 主题设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('主题设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: Text(l10n('跟随系统')),
                      value: ReaderThemeMode.auto,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: Text(l10n('浅色')),
                      value: ReaderThemeMode.light,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderThemeMode>(
                      title: Text(l10n('深色')),
                      value: ReaderThemeMode.dark,
                      groupValue: theme.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ThemeCubit>().setThemeMode(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              // 内容设置（正文/书名/章节名等网页文字）
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('内容设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        l10n('网页原文是简体。转成繁体时，正文、书名、作者、简介、章节名等都会跟着转（台湾用词）。'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    BlocBuilder<ContentLanguageCubit, ContentLanguage>(
                      builder: (context, contentLanguage) {
                        return Column(
                          children: [
                            RadioListTile<ContentLanguage>(
                              title: Text(l10n('跟随界面语言')),
                              value: ContentLanguage.followUi,
                              groupValue: contentLanguage,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<ContentLanguageCubit>()
                                      .setLanguage(value);
                                }
                              },
                            ),
                            RadioListTile<ContentLanguage>(
                              title: Text(l10n('繁體中文')),
                              value: ContentLanguage.zhTW,
                              groupValue: contentLanguage,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<ContentLanguageCubit>()
                                      .setLanguage(value);
                                }
                              },
                            ),
                            RadioListTile<ContentLanguage>(
                              title: Text(l10n('简体中文（原文）')),
                              value: ContentLanguage.zhCN,
                              groupValue: contentLanguage,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<ContentLanguageCubit>()
                                      .setLanguage(value);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // API Host 设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('API Host 设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    BlocBuilder<ApiHostCubit, String>(
                      builder: (context, apiHost) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n('API 主机地址')),
                              const SizedBox(height: 8),
                              TextField(
                                controller: TextEditingController(
                                  text: apiHost,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n('留空使用默认地址'),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link),
                                ),
                                onSubmitted: (value) async {
                                  try {
                                    await context
                                        .read<ApiHostCubit>()
                                        .updateApiHost(value);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(l10n('API Host 已更新')),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('${l10n('更新失败: ')}$e'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await context
                                              .read<ApiHostCubit>()
                                              .resetToDefault();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n('已重置为默认地址')),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${l10n('重置失败: ')}$e',
                                                ),
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: Text(l10n('重置为默认')),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // 缓存设置
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n('缓存设置'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: Text(l10n('清除接口缓存')),
                      subtitle: Text(l10n('清除所有网络请求的缓存数据')),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(l10n('清除缓存')),
                                content: Text(l10n('确定要清除所有接口缓存吗？')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(l10n('取消')),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      try {
                                        await cleanAllWebCache();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(l10n('缓存已清除')),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${l10n('清除缓存失败: ')}$e',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(l10n('确定')),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // 退出登录
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    l10n('退出登录'),
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(l10n('退出登录')),
                            content: Text(l10n('确定要退出登录吗？')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(l10n('取消')),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await logout();
                                  if (context.mounted) {
                                    // 更新 AuthCubit 状态
                                    context.read<AuthCubit>().logout();
                                    // 清空导航栈并跳转到登录页
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                },
                                child: Text(l10n('确定')),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
