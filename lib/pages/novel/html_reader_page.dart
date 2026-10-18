import 'package:wild/widgets/content_language_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../src/rust/wenku8/models.dart';
import 'html_reader_cubit.dart';
import 'package:wild/pages/novel/top_bar_height_cubit.dart';
import 'package:wild/pages/novel/bottom_bar_height_cubit.dart';
import 'package:wild/pages/novel/left_padding_cubit.dart';
import 'package:wild/pages/novel/right_padding_cubit.dart';
import 'package:wild/pages/novel/font_size_cubit.dart';
import 'package:wild/pages/novel/font_family_cubit.dart';
import 'package:wild/widgets/reader_font_row.dart';
import 'package:wild/pages/novel/line_height_cubit.dart';
import 'package:wild/pages/novel/paragraph_spacing_cubit.dart';
import 'package:wild/pages/novel/paragraph_indent_cubit.dart';
import 'package:wild/pages/novel/punctuation_rule_cubit.dart';
import 'package:wild/pages/novel/reader_typography.dart';
import 'package:wild/pages/novel/theme_cubit.dart';
import 'package:wild/pages/novel/reader_type_cubit.dart';
import 'package:wild/cubits/reader_background_cubit.dart';
import 'package:wild/cubits/reader_battery.dart';
import 'package:wild/cubits/reader_clock.dart';
import 'package:wild/widgets/reader_corners.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:wild/pages/novel/fullscreen_cubit.dart';
import 'package:wild/cubits/screen_keep_on.dart';
import 'package:wild/pages/novel/auto_scroll_cubit.dart';
import 'package:wild/pages/novel/auto_scroll_config_cubit.dart';
import 'package:wild/cubits/volume_control_cubit.dart';
import 'package:wild/utils/controller_event.dart';
import 'package:wild/widgets/tappable_reader_image.dart';
import 'dart:async';
import 'dart:io';
import 'package:wild/l10n/ui_language.dart';
import 'package:wild/cubits/content_language_cubit.dart';
import 'package:wild/l10n/content_language.dart';

class HtmlReaderPage extends StatelessWidget {
  final NovelInfo novelInfo;
  final String initialAid;
  final String initialCid;
  final List<Volume> volumes;

  const HtmlReaderPage({
    super.key,
    required this.novelInfo,
    required this.initialAid,
    required this.initialCid,
    required this.volumes,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create:
              (context) => HtmlReaderCubit(
                novelInfo: novelInfo,
                initialAid: initialAid,
                initialCid: initialCid,
                initialVolumes: volumes,
              )..loadChapter(),
        ),
        BlocProvider(create: (context) => FullscreenCubit()),
        BlocProvider(create: (context) => AutoScrollCubit()),
        BlocProvider(
          create: (context) => AutoScrollConfigCubit()..loadConfig(),
        ),
      ],
      child: const _HtmlReaderViewWrapper(),
    );
  }
}

class _HtmlReaderViewWrapper extends StatefulWidget {
  const _HtmlReaderViewWrapper();

  @override
  State<_HtmlReaderViewWrapper> createState() => _HtmlReaderViewWrapperState();
}

class _HtmlReaderViewWrapperState extends State<_HtmlReaderViewWrapper> {
  late final ScrollController _scrollController;
  Timer? _autoScrollTimer;

  /// 滚动式阅读器没有「页」，右下角就报整章滚动进度。
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    setKeepScreenUpOnReading(true);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // 进阅读器即全屏：隐藏状态栏与导航栏（沉浸式，边缘下滑可临时唤出）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 四角信息的数据源
    startBatteryWatch();
    startReaderClock();

    // 监听音量键事件
    if (Platform.isAndroid || Platform.isIOS) {
      final volumeControlCubit = context.read<VolumeControlCubit>();
      if (volumeControlCubit.isEnabled) {
        addVolumeListen();
        readerControllerEvent.subscribe(_onController);
      }
    }
  }

  @override
  void dispose() {
    setKeepScreenUpOnReading(false);
    setKeepScreenUpOnScroll(false);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    _scrollProgress.dispose();

    // 退出阅读器恢复系统栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    stopBatteryWatch();
    stopReaderClock();

    // 取消音量键事件监听
    if (Platform.isAndroid || Platform.isIOS) {
      delVolumeListen();
      readerControllerEvent.unsubscribe(_onController);
    }

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    _scrollProgress.value =
        max <= 0 ? 1 : (position.pixels / max).clamp(0.0, 1.0);
  }

  void _showSettings(BuildContext context) {
    final fontSizeCubit = context.read<FontSizeCubit>();
    final fontFamilyCubit = context.read<FontFamilyCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final topBarHeightCubit = context.read<TopBarHeightCubit>();
    final bottomBarHeightCubit = context.read<BottomBarHeightCubit>();
    final leftPaddingCubit = context.read<LeftPaddingCubit>();
    final rightPaddingCubit = context.read<RightPaddingCubit>();
    final paragraphIndentCubit = context.read<ParagraphIndentCubit>();
    final punctuationRuleCubit = context.read<PunctuationRuleCubit>();
    final readerTypeCubit = context.read<ReaderTypeCubit>();
    final readerBackgroundCubit = context.read<ReaderBackgroundCubit>();
    final autoScrollConfigCubit = context.read<AutoScrollConfigCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: fontSizeCubit),
            BlocProvider.value(value: fontFamilyCubit),
            BlocProvider.value(value: lineHeightCubit),
            BlocProvider.value(value: paragraphSpacingCubit),
            BlocProvider.value(value: themeCubit),
            BlocProvider.value(value: topBarHeightCubit),
            BlocProvider.value(value: bottomBarHeightCubit),
            BlocProvider.value(value: leftPaddingCubit),
            BlocProvider.value(value: rightPaddingCubit),
            BlocProvider.value(value: paragraphIndentCubit),
            BlocProvider.value(value: punctuationRuleCubit),
            BlocProvider.value(value: readerTypeCubit),
            BlocProvider.value(value: readerBackgroundCubit),
            BlocProvider.value(value: autoScrollConfigCubit),
          ],
          child: _ReaderSettings(
            onFontChanged: () => context.read<HtmlReaderCubit>().loadChapter(),
          ),
        );
      },
    );
  }

  void _toggleAutoScroll(BuildContext context) {
    final autoScrollCubit = context.read<AutoScrollCubit>();
    final fullscreenCubit = context.read<FullscreenCubit>();

    if (!autoScrollCubit.state) {
      // Start auto-scroll
      fullscreenCubit.toggle();
      autoScrollCubit.start();
      _startAutoScroll();
    } else {
      // Stop auto-scroll
      autoScrollCubit.stop();
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    setKeepScreenUpOnScroll(true);
    _autoScrollTimer?.cancel();

    final config = context.read<AutoScrollConfigCubit>().state;
    _autoScrollTimer = Timer.periodic(
      Duration(milliseconds: config.scrollInterval),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final currentScroll = _scrollController.offset;

          if (currentScroll >= maxScroll) {
            // Reached the end, stop auto-scroll
            context.read<AutoScrollCubit>().stop();
            _stopAutoScroll();
            return;
          }

          _scrollController.jumpTo(currentScroll + config.scrollSpeed);
        }
      },
    );
  }

  void _stopAutoScroll() {
    setKeepScreenUpOnScroll(false);
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onController(ReaderControllerEventArgs args) {
    if (!_scrollController.hasClients) return;

    if (args.key == "UP") {
      // 音量上键 - 向上滚动
      final currentOffset = _scrollController.offset;
      if (currentOffset <= 0) {
        // 已到达顶部，切换到上一章
        context.read<HtmlReaderCubit>().goToPreviousChapter();
      } else {
        // 向上滚动一屏
        final screenHeight = MediaQuery.of(context).size.height;
        final targetOffset = (currentOffset - screenHeight * 0.8).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(targetOffset);
      }
    } else if (args.key == "DOWN") {
      // 音量下键 - 向下滚动
      final currentOffset = _scrollController.offset;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      if (currentOffset >= maxScrollExtent - 10) {
        // 已到达底部，切换到下一章
        context.read<HtmlReaderCubit>().goToNextChapter();
      } else {
        // 向下滚动一屏
        final screenHeight = MediaQuery.of(context).size.height;
        final targetOffset = (currentOffset + screenHeight * 0.8).clamp(
          0.0,
          maxScrollExtent,
        );
        _scrollController.jumpTo(targetOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HtmlReaderCubit>();
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        final mediaQuery = MediaQuery.of(context);
        bool isDarkMode;
        if (theme.themeMode == ReaderThemeMode.dark) {
          isDarkMode = true;
        } else if (theme.themeMode == ReaderThemeMode.light) {
          isDarkMode = false;
        } else {
          isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
        }

        final backgroundColor =
            isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
        final textColor =
            isDarkMode ? theme.darkTextColor : theme.lightTextColor;

        return BlocListener<ContentLanguageCubit, ContentLanguage>(
          listenWhen: (previous, current) => previous != current,
          listener: (context, language) {
            // 内容语言变了：重读当前章节，正文和章节名按新设置重新转换
            context.read<HtmlReaderCubit>().loadChapter();
          },
          child: BlocBuilder<HtmlReaderCubit, HtmlReaderState>(
            builder: (context, state) {
              // 内容字形（繁/简）换了就重读本章：正文和章节名要按新设置重新转换
              final htmlReaderCubit = context.read<HtmlReaderCubit>();
              if (state is HtmlReaderLoaded &&
                  htmlReaderCubit.loadedScript != contentScriptNow) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  htmlReaderCubit.loadChapter();
                });
              }
              return BlocBuilder<FullscreenCubit, bool>(
                builder: (context, isFullscreen) {
                  return BlocListener<FullscreenCubit, bool>(
                    listener: (context, isFullscreen) {
                      if (!isFullscreen) {
                        // Exit fullscreen, stop auto-scroll
                        context.read<AutoScrollCubit>().stop();
                        _stopAutoScroll();
                      }
                    },
                    child: BlocBuilder<
                      ReaderBackgroundCubit,
                      ReaderBackgroundState
                    >(
                      builder: (context, backgroundState) {
                        String? backgroundImagePath;
                        if (isDarkMode &&
                            backgroundState.darkBackgroundExists) {
                          backgroundImagePath =
                              context
                                  .read<ReaderBackgroundCubit>()
                                  .getDarkBackgroundPath();
                        } else if (!isDarkMode &&
                            backgroundState.lightBackgroundExists) {
                          backgroundImagePath =
                              context
                                  .read<ReaderBackgroundCubit>()
                                  .getLightBackgroundPath();
                        }

                        return Scaffold(
                          backgroundColor: backgroundColor,
                          extendBodyBehindAppBar: true,
                          appBar:
                              isFullscreen
                                  ? null
                                  : AppBar(
                                    backgroundColor: backgroundColor
                                        .withOpacity(0.8),
                                    elevation: 0,
                                    title:
                                        state is HtmlReaderLoaded
                                            ? Text(state.title)
                                            : Text(l10n('加载中...')),
                                    actions: [
                                      BlocBuilder<AutoScrollCubit, bool>(
                                        builder: (context, isAutoScrolling) {
                                          return IconButton(
                                            icon: Icon(
                                              isAutoScrolling
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                            ),
                                            onPressed:
                                                () =>
                                                    _toggleAutoScroll(context),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.settings),
                                        onPressed: () => _showSettings(context),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.menu),
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            builder:
                                                (context) => BlocProvider.value(
                                                  value: cubit,
                                                  child: _ChapterList(
                                                    volumes:
                                                        cubit.initialVolumes,
                                                    currentAid:
                                                        cubit.initialAid,
                                                    currentCid:
                                                        cubit.initialCid,
                                                    onChapterSelected: (
                                                      aid,
                                                      cid,
                                                    ) {
                                                      cubit.loadChapter(
                                                        aid: aid,
                                                        cid: cid,
                                                      );
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                          body: Stack(
                            children: [
                              // 背景图片
                              if (backgroundImagePath != null)
                                Positioned.fill(
                                  child: Image.file(
                                    File(backgroundImagePath),
                                    fit: BoxFit.cover,
                                    opacity: AlwaysStoppedAnimation(
                                      backgroundState.opacity,
                                    ),
                                  ),
                                ),
                              // 底层内容
                              GestureDetector(
                                onTap: () {
                                  context.read<FullscreenCubit>().toggle();
                                },
                                child:
                                    state is HtmlReaderLoading
                                        ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                        : state is HtmlReaderError
                                        ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                state.error,
                                                style: TextStyle(
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton(
                                                onPressed: () {
                                                  context
                                                      .read<HtmlReaderCubit>()
                                                      .loadChapter();
                                                },
                                                child: Text(l10n('重试')),
                                              ),
                                            ],
                                          ),
                                        )
                                        : state is HtmlReaderLoaded
                                        ? _ReaderContent(
                                          parsedContent: state.parsedContent,
                                          onPreviousChapter: () {
                                            context
                                                .read<HtmlReaderCubit>()
                                                .goToPreviousChapter();
                                          },
                                          onNextChapter: () {
                                            context
                                                .read<HtmlReaderCubit>()
                                                .goToNextChapter();
                                          },
                                          scrollController: _scrollController,
                                        )
                                        : const SizedBox.shrink(),
                              ),
                              // 四角信息：左上电量 / 右上章节名 / 左下时间 / 右下滚动进度
                              Positioned.fill(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _scrollProgress,
                                  builder: (context, progress, _) {
                                    // 读 view 的几何：Scaffold 有 AppBar 时会把 MediaQuery 的
                                    // padding/viewPadding.top 清成 0，直接读 MediaQuery.of 会让
                                    // 角标带落进 AppBar 里被盖住（真机表现为「四角不显示」）。
                                    final cornerGeometry =
                                        MediaQueryData.fromView(
                                          WidgetsBinding.instance.window,
                                        );
                                    final cornerLeft = context
                                        .select<LeftPaddingCubit, double>(
                                          (cubit) => cubit.state,
                                        );
                                    final cornerRight = context
                                        .select<RightPaddingCubit, double>(
                                          (cubit) => cubit.state,
                                        );
                                    return ReaderCorners(
                                      chapterTitle:
                                          state is HtmlReaderLoaded
                                              ? state.title
                                              : '',
                                      color: textColor,
                                      // 滚动式阅读器非全屏时顶部有 AppBar、系统栏也可能临时显示：
                                      // 角标带要让开它们，否则会被 AppBar/导航栏盖住（看着像不显示）。
                                      safeTop:
                                          cornerGeometry.viewPadding.top +
                                          (isFullscreen ? 0 : kToolbarHeight),
                                      safeBottom:
                                          cornerGeometry.padding.bottom >
                                              cornerGeometry.viewPadding.bottom
                                          ? cornerGeometry.padding.bottom
                                          : cornerGeometry.viewPadding.bottom,
                                      leftInset: cornerLeft,
                                      rightInset: cornerRight,
                                      progressText:
                                          '${(progress * 100).round()}${l10n('% 已读')}',
                                    );
                                  },
                                ),
                              ),
                              // 顶部和底部导航按钮（仅在隐藏 AppBar 时显示）
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ReaderContent extends StatelessWidget {
  final List<ParsedContent> parsedContent;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ScrollController scrollController;

  const _ReaderContent({
    required this.parsedContent,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.scrollController,
  });

  List<Widget> _buildContentWidgets(
    BuildContext context, {
    required double fontSize,
    required String fontFamily,
    required double lineHeight,
    required double paragraphSpacing,
    required Color textColor,
    required double maxWidth,
    required int indentChars,
    required bool allowPunctuationAtLineStart,
  }) {
    final widgets = <Widget>[];
    final measureStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily.isEmpty ? null : fontFamily,
      height: lineHeight,
    );

    for (var content in parsedContent) {
      if (content is ParsedText) {
        // 全角标点 + 段首缩进 + 行尾排满：和分页阅读器用同一份排版函数
        final text = applyReaderTypography(
          content.text,
          indentChars: indentChars,
          allowPunctuationAtLineStart: allowPunctuationAtLineStart,
          style: measureStyle,
          maxWidth: maxWidth,
        );
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: paragraphSpacing),
            child: Text.rich(
              // 排版过的段落：行结构由排版层定，行尾按版心拉伸对齐
              readerParagraphSpan(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: fontFamily.isEmpty ? null : fontFamily,
                  height: lineHeight,
                  color: textColor,
                ),
                maxWidth: maxWidth,
              ),
            ),
          ),
        );
      } else if (content is ParsedImage) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: paragraphSpacing),
            // 点图片打开全屏看图；图片以外的留白点击照样走原本的手势
            child: TappableReaderImage(imageUrl: content.imageUrl),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = context.select<FontFamilyCubit, String>(
      (cubit) => cubit.state.family,
    );
    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        final mediaQuery = MediaQuery.of(context);
        bool isDarkMode;
        if (theme.themeMode == ReaderThemeMode.dark) {
          isDarkMode = true;
        } else if (theme.themeMode == ReaderThemeMode.light) {
          isDarkMode = false;
        } else {
          isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
        }

        final backgroundColor =
            isDarkMode ? theme.darkBackgroundColor : theme.lightBackgroundColor;
        final textColor =
            isDarkMode ? theme.darkTextColor : theme.lightTextColor;

        return BlocBuilder<FontSizeCubit, double>(
          builder: (context, fontSize) {
            return BlocBuilder<LineHeightCubit, double>(
              builder: (context, lineHeight) {
                return BlocBuilder<ParagraphSpacingCubit, double>(
                  builder: (context, paragraphSpacing) {
                    return BlocBuilder<TopBarHeightCubit, double>(
                      builder: (context, topBarHeight) {
                        return BlocBuilder<BottomBarHeightCubit, double>(
                          builder: (context, bottomBarHeight) {
                            return BlocBuilder<FullscreenCubit, bool>(
                              builder: (context, isFullscreen) {
                                final topPad =
                                    MediaQueryData.fromView(
                                      WidgetsBinding.instance.window,
                                    ).viewPadding.top;
                                final bottomPad =
                                    MediaQueryData.fromView(
                                      WidgetsBinding.instance.window,
                                    ).viewPadding.bottom;

                                final tail = [
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: onPreviousChapter,
                                          child: Text(
                                            l10n('上一章'),
                                            style: TextStyle(color: textColor),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: onNextChapter,
                                          child: Text(
                                            l10n('下一章'),
                                            style: TextStyle(color: textColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                ];

                                return BlocBuilder<LeftPaddingCubit, double>(
                                  builder: (context, leftPadding) {
                                    return BlocBuilder<
                                      RightPaddingCubit,
                                      double
                                    >(
                                      builder: (context, rightPadding) {
                                        return BlocBuilder<
                                          ParagraphIndentCubit,
                                          int
                                        >(
                                          builder: (context, indentChars) {
                                            return BlocBuilder<
                                              PunctuationRuleCubit,
                                              bool
                                            >(
                                              builder: (
                                                context,
                                                allowPunctuationAtLineStart,
                                              ) {
                                                final contentWidth =
                                                    MediaQueryData.fromView(
                                                          WidgetsBinding
                                                              .instance
                                                              .window,
                                                        ).size.width -
                                                        leftPadding -
                                                        rightPadding;
                                                final col = [
                                                  ..._buildContentWidgets(
                                                    context,
                                                    fontSize: fontSize,
                                                    fontFamily: fontFamily,
                                                    lineHeight: lineHeight,
                                                    paragraphSpacing:
                                                        paragraphSpacing,
                                                    textColor: textColor,
                                                    maxWidth: contentWidth,
                                                    indentChars: indentChars,
                                                    allowPunctuationAtLineStart:
                                                        allowPunctuationAtLineStart,
                                                  ),
                                                  ...tail,
                                                ];
                                                // 正文只在上、下角标栏之间这块区域里滚动：
                                                // 把滚动视口按内容区裁掉（安全区 + AppBar + 角标栏 + 边距），
                                                // 文字不会滚到角标栏/状态栏底下 —— 分页阅读器本来就是这样。
                                                final contentTop =
                                                    topPad +
                                                    (isFullscreen
                                                        ? 0
                                                        : kToolbarHeight) +
                                                    kReaderCornerBarHeight +
                                                    topBarHeight;
                                                final contentBottom =
                                                    bottomPad +
                                                    kReaderCornerBarHeight +
                                                    bottomBarHeight;
                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    top: contentTop,
                                                    bottom: contentBottom,
                                                  ),
                                                  child: ListView(
                                                    controller: scrollController,
                                                    // 上下留白由外层 Padding 负责，这里只管左右
                                                    padding: EdgeInsets.only(
                                                      left: leftPadding,
                                                      right: rightPadding,
                                                    ),
                                                    children: col,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReaderSettings extends StatelessWidget {
  final Future<void> Function()? onFontChanged;

  const _ReaderSettings({this.onFontChanged});

  @override
  Widget build(BuildContext context) {
    final fontSizeCubit = context.read<FontSizeCubit>();
    final paragraphSpacingCubit = context.read<ParagraphSpacingCubit>();
    final lineHeightCubit = context.read<LineHeightCubit>();
    final themeCubit = context.read<ThemeCubit>();
    final topBarHeightCubit = context.read<TopBarHeightCubit>();
    final bottomBarHeightCubit = context.read<BottomBarHeightCubit>();
    final leftPaddingCubit = context.read<LeftPaddingCubit>();
    final rightPaddingCubit = context.read<RightPaddingCubit>();
    final paragraphIndentCubit = context.read<ParagraphIndentCubit>();
    final punctuationRuleCubit = context.read<PunctuationRuleCubit>();
    final readerTypeCubit = context.read<ReaderTypeCubit>();
    final readerBackgroundCubit = context.read<ReaderBackgroundCubit>();
    final autoScrollConfigCubit = context.read<AutoScrollConfigCubit>();

    void _showColorPicker(
      BuildContext context,
      Color initialColor,
      Function(Color) onColorChanged,
    ) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          Color pickerColor = initialColor;
          return AlertDialog(
            title: Text(l10n('选择颜色')),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (Color color) {
                  pickerColor = color;
                },
                pickerAreaHeightPercent: 0.8,
                enableAlpha: false,
                labelTypes: const [],
                displayThumbColor: true,
                showLabel: false,
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(l10n('取消')),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(l10n('确定')),
                onPressed: () async {
                  onColorChanged(pickerColor);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    return BlocBuilder<ThemeCubit, ReaderTheme>(
      builder: (context, theme) {
        return Container(
          height: MediaQuery.of(context).size.height / 3 * 2,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            children: [
              Text(
                l10n('设置'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // 阅读器类型设置
              Row(
                children: [
                  Text(l10n('阅读器类型')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ReaderTypeCubit, ReaderType>(
                      builder: (context, type) {
                        return SegmentedButton<ReaderType>(
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
                          onSelectionChanged: (Set<ReaderType> types) async {
                            await readerTypeCubit.updateType(types.first);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const Divider(),
              // 字体大小设置
              BlocBuilder<FontSizeCubit, double>(
                builder: (context, fontSize) {
                  return Row(
                    children: [
                      Text(l10n('字体大小')),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 48,
                          divisions: 34,
                          label: fontSize.round().toString(),
                          onChanged: (value) {
                            fontSizeCubit.updateFontSize(value);
                          },
                        ),
                      ),
                      Text('${fontSize.round()}', style: TextStyle()),
                    ],
                  );
                },
              ),
              const Divider(),
              // 字体设置
              ReaderFontRow(
                cubit: context.read<FontFamilyCubit>(),
                onFontChanged: onFontChanged,
              ),
              const Divider(),
              // 内容语言（正文字形）：跟随界面语言 / 繁體中文 / 简体中文（原文）
              const ContentLanguageRow(),
              // 段首缩进（空几个字）
              BlocBuilder<ParagraphIndentCubit, int>(
                builder: (context, indent) {
                  return Row(
                    children: [
                      Text(l10n('段首缩进')),
                      Expanded(
                        child: Slider(
                          value: indent.toDouble(),
                          min: 0,
                          max: ParagraphIndentCubit.maxIndent.toDouble(),
                          divisions: ParagraphIndentCubit.maxIndent,
                          label: indent.toString(),
                          onChanged: (value) async {
                            await paragraphIndentCubit.updateParagraphIndent(
                              value.round(),
                            );
                          },
                        ),
                      ),
                      Text('$indent ${l10n('字')}'),
                    ],
                  );
                },
              ),
              // 避头点：标点不排到行首
              BlocBuilder<PunctuationRuleCubit, bool>(
                builder: (context, enabled) {
                  return Row(
                    children: [
                      Expanded(child: Text(l10n('标点可置行首'))),
                      Switch(
                        value: enabled,
                        onChanged: (value) async {
                          await punctuationRuleCubit.updatePunctuationRule(
                            value,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              // 段落间距设置
              BlocBuilder<ParagraphSpacingCubit, double>(
                builder: (context, spacing) {
                  return Row(
                    children: [
                      Text(l10n('段落间距')),
                      Expanded(
                        child: Slider(
                          value: spacing,
                          min: 16,
                          max: 32,
                          divisions: 8,
                          label: spacing.round().toString(),
                          onChanged: (value) {
                            paragraphSpacingCubit.updateSpacing(value);
                          },
                        ),
                      ),
                      Text('${spacing.round()}', style: TextStyle()),
                    ],
                  );
                },
              ),
              // 行高设置
              BlocBuilder<LineHeightCubit, double>(
                builder: (context, lineHeight) {
                  return Row(
                    children: [
                      Text(l10n('行高')),
                      Expanded(
                        child: Slider(
                          value: lineHeight,
                          min: 1.0,
                          max: 2.0,
                          divisions: 20,
                          label: lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            lineHeightCubit.updateLineHeight(value);
                          },
                        ),
                      ),
                      Text(lineHeight.toStringAsFixed(1), style: TextStyle()),
                    ],
                  );
                },
              ),
              // 边距设置
              BlocBuilder<TopBarHeightCubit, double>(
                builder: (context, topBarHeight) {
                  return BlocBuilder<BottomBarHeightCubit, double>(
                    builder: (context, bottomBarHeight) {
                      return BlocBuilder<LeftPaddingCubit, double>(
                        builder: (context, leftPadding) {
                          return BlocBuilder<RightPaddingCubit, double>(
                            builder: (context, rightPadding) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(l10n('顶部边距')),
                                      Expanded(
                                        child: Slider(
                                          value: topBarHeight,
                                          min: 0,
                                          max: 100,
                                          divisions: 20,
                                          label:
                                              topBarHeight.round().toString(),
                                          onChanged: (value) {
                                            topBarHeightCubit.updateHeight(
                                              value,
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${topBarHeight.round()}',
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(l10n('底部边距')),
                                      Expanded(
                                        child: Slider(
                                          value: bottomBarHeight,
                                          min: 0,
                                          max: 100,
                                          divisions: 20,
                                          label:
                                              bottomBarHeight
                                                  .round()
                                                  .toString(),
                                          onChanged: (value) {
                                            bottomBarHeightCubit.updateHeight(
                                              value,
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${bottomBarHeight.round()}',
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(l10n('左边距')),
                                      Expanded(
                                        child: Slider(
                                          value: leftPadding,
                                          min: 0,
                                          max: 50,
                                          divisions: 25,
                                          label: leftPadding.round().toString(),
                                          onChanged: (value) {
                                            leftPaddingCubit.updatePadding(
                                              value,
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${leftPadding.round()}',
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(l10n('右边距')),
                                      Expanded(
                                        child: Slider(
                                          value: rightPadding,
                                          min: 0,
                                          max: 50,
                                          divisions: 25,
                                          label:
                                              rightPadding.round().toString(),
                                          onChanged: (value) {
                                            rightPaddingCubit.updatePadding(
                                              value,
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${rightPadding.round()}',
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const Divider(),
              // 主题模式选择
              Row(
                children: [
                  Text(l10n('主题模式')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return SegmentedButton<ReaderThemeMode>(
                          segments: [
                            ButtonSegment<ReaderThemeMode>(
                              value: ReaderThemeMode.auto,
                              label: Text(l10n('自动')),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment<ReaderThemeMode>(
                              value: ReaderThemeMode.light,
                              label: Text(l10n('浅色')),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment<ReaderThemeMode>(
                              value: ReaderThemeMode.dark,
                              label: Text(l10n('深色')),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {theme.themeMode},
                          onSelectionChanged: (Set<ReaderThemeMode> modes) {
                            themeCubit.setThemeMode(modes.first);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 浅色主题颜色设置
              Row(
                children: [
                  Text(
                    l10n('浅色主题'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.lightBackgroundColor,
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(l10n('背景颜色')),
                          onPressed:
                              () => _showColorPicker(
                                context,
                                theme.lightBackgroundColor,
                                (color) {
                                  themeCubit.updateLightBackgroundColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.lightTextColor,
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(l10n('文字颜色')),
                          onPressed:
                              () => _showColorPicker(
                                context,
                                theme.lightTextColor,
                                (color) {
                                  themeCubit.updateLightTextColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 深色主题颜色设置
              Row(
                children: [
                  Text(
                    l10n('深色主题'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.darkBackgroundColor,
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(l10n('背景颜色')),
                          onPressed:
                              () => _showColorPicker(
                                context,
                                theme.darkBackgroundColor,
                                (color) {
                                  themeCubit.updateDarkBackgroundColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BlocBuilder<ThemeCubit, ReaderTheme>(
                      builder: (context, theme) {
                        return OutlinedButton.icon(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.darkTextColor,
                              border: Border.all(color: Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(l10n('文字颜色')),
                          onPressed:
                              () => _showColorPicker(
                                context,
                                theme.darkTextColor,
                                (color) {
                                  themeCubit.updateDarkTextColor(color);
                                },
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 自动滚动设置
              Row(
                children: [
                  Text(
                    l10n('自动滚动设置'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 滚动速度设置
              BlocBuilder<AutoScrollConfigCubit, AutoScrollConfig>(
                builder: (context, config) {
                  return Row(
                    children: [
                      Text(l10n('滚动速度')),
                      Expanded(
                        child: Slider(
                          value: config.scrollSpeed,
                          min: 0.5,
                          max: 3.0,
                          divisions: 10,
                          label: config.scrollSpeed.toStringAsFixed(1),
                          onChanged: (value) {
                            autoScrollConfigCubit.updateScrollSpeed(value);
                          },
                        ),
                      ),
                      Text(
                        config.scrollSpeed.toStringAsFixed(1),
                        style: TextStyle(),
                      ),
                    ],
                  );
                },
              ),
              // 滚动间隔设置
              BlocBuilder<AutoScrollConfigCubit, AutoScrollConfig>(
                builder: (context, config) {
                  return Row(
                    children: [
                      Text(l10n('滚动间隔')),
                      Expanded(
                        child: Slider(
                          value: config.scrollInterval.toDouble(),
                          min: 8,
                          max: 32,
                          divisions: 6,
                          label: '${config.scrollInterval}ms',
                          onChanged: (value) {
                            autoScrollConfigCubit.updateScrollInterval(
                              value.toInt(),
                            );
                          },
                        ),
                      ),
                      Text('${config.scrollInterval}ms', style: TextStyle()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // 背景透明度设置
              BlocBuilder<ReaderBackgroundCubit, ReaderBackgroundState>(
                builder: (context, backgroundState) {
                  return Row(
                    children: [
                      Text(l10n('背景透明度')),
                      Expanded(
                        child: Slider(
                          value: backgroundState.opacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 25,
                          label: '${(backgroundState.opacity * 100).round()}%',
                          onChanged: (value) async {
                            await readerBackgroundCubit.updateOpacity(value);
                          },
                        ),
                      ),
                      Text(
                        '${(backgroundState.opacity * 100).round()}%',
                        style: TextStyle(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // 背景图片设置
              Row(
                children: [
                  Text(
                    l10n('背景图片设置'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BlocBuilder<ReaderBackgroundCubit, ReaderBackgroundState>(
                builder: (context, backgroundState) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                backgroundState.lightBackgroundExists
                                    ? Icons.image
                                    : Icons.add_photo_alternate,
                              ),
                              label: Text(
                                backgroundState.lightBackgroundExists
                                    ? l10n('更新浅色背景')
                                    : l10n('设置浅色背景'),
                              ),
                              onPressed: () async {
                                await readerBackgroundCubit
                                    .updateLightBackground();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (backgroundState.lightBackgroundExists)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: Text(l10n('删除')),
                              onPressed: () async {
                                await readerBackgroundCubit
                                    .deleteLightBackground();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(
                                backgroundState.darkBackgroundExists
                                    ? Icons.image
                                    : Icons.add_photo_alternate,
                              ),
                              label: Text(
                                backgroundState.darkBackgroundExists
                                    ? l10n('更新深色背景')
                                    : l10n('设置深色背景'),
                              ),
                              onPressed: () async {
                                await readerBackgroundCubit
                                    .updateDarkBackground();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (backgroundState.darkBackgroundExists)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete),
                              label: Text(l10n('删除')),
                              onPressed: () async {
                                await readerBackgroundCubit
                                    .deleteDarkBackground();
                              },
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // 重置按钮
              TextButton(
                onPressed: () async {
                  await themeCubit.resetToDefault();
                  await topBarHeightCubit.updateHeight(56);
                  await bottomBarHeightCubit.updateHeight(56);
                  await leftPaddingCubit.updatePadding(16);
                  await rightPaddingCubit.updatePadding(16);
                },
                child: Text(l10n('重置为默认')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChapterList extends StatefulWidget {
  final List<Volume> volumes;
  final String currentAid;
  final String currentCid;
  final Function(String aid, String cid) onChapterSelected;

  const _ChapterList({
    required this.volumes,
    required this.currentAid,
    required this.currentCid,
    required this.onChapterSelected,
  });

  @override
  State<_ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends State<_ChapterList> {
  late ScrollController _scrollController;
  int _currentChapterGlobalIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentChapterGlobalIndex = _calculateCurrentChapterIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const estimatedItemHeight = 56.0;
        const estimatedVolumeTitleHeight = 48.0;
        const estimatedSpacing = 16.0;

        double targetScroll =
            _currentChapterGlobalIndex *
            (estimatedItemHeight + estimatedSpacing);
        for (var i = 0; i < widget.volumes.length; i++) {
          if (i < _findCurrentVolumeIndex()) {
            targetScroll += estimatedVolumeTitleHeight + estimatedSpacing;
          } else {
            break;
          }
        }

        _scrollController.animateTo(
          targetScroll - 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _findCurrentVolumeIndex() {
    for (var i = 0; i < widget.volumes.length; i++) {
      final volume = widget.volumes[i];
      if (volume.chapters.any(
        (chapter) =>
            chapter.aid == widget.currentAid &&
            chapter.cid == widget.currentCid,
      )) {
        return i;
      }
    }
    return -1;
  }

  int _calculateCurrentChapterIndex() {
    int globalIndex = 0;
    for (var volume in widget.volumes) {
      for (var chapter in volume.chapters) {
        if (chapter.aid == widget.currentAid &&
            chapter.cid == widget.currentCid) {
          return globalIndex;
        }
        globalIndex++;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          AppBar(
            title: Text(l10n('目录')),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.volumes.length,
              itemBuilder: (context, volumeIndex) {
                final volume = widget.volumes[volumeIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        volume.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...volume.chapters.map((chapter) {
                      final isSelected =
                          chapter.aid == widget.currentAid &&
                          chapter.cid == widget.currentCid;
                      return ListTile(
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                        selected: isSelected,
                        onTap:
                            () => widget.onChapterSelected(
                              chapter.aid,
                              chapter.cid,
                            ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
