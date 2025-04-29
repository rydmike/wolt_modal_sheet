import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wolt_modal_sheet/src/content/components/main_content/wolt_modal_sheet_hero_image.dart';
import 'package:wolt_modal_sheet/src/theme/wolt_modal_sheet_default_theme_data.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// The main content widget within the scrollable modal sheet.
///
/// This widget is responsible for displaying the main content of the scrollable modal sheet.
/// It handles the scroll behavior, page layout, and interactions within the modal sheet.
class WoltModalSheetMainContent extends StatefulWidget {
  final ScrollController? scrollController;
  final GlobalKey pageTitleKey;
  final SliverWoltModalSheetPage page;
  final WoltModalType woltModalType;
  final WoltModalSheetScrollAnimationStyle scrollAnimationStyle;

  const WoltModalSheetMainContent({
    required this.scrollController,
    required this.pageTitleKey,
    required this.page,
    required this.woltModalType,
    required this.scrollAnimationStyle,
    Key? key,
  }) : super(key: key);

  @override
  State<WoltModalSheetMainContent> createState() =>
      _WoltModalSheetMainContentState();
}

class _WoltModalSheetMainContentState extends State<WoltModalSheetMainContent> {
  double? _measuredHeight;

  @override
  Widget build(BuildContext context) {
    // common: theme, page, slivers, physics
    final themeData = Theme.of(context).extension<WoltModalSheetThemeData>();
    final defaultThemeData = WoltModalSheetDefaultThemeData(context);
    final page = widget.page;
    final heroImageHeight = page.heroImage == null
        ? 0.0
        : (page.heroImageHeight ??
            themeData?.heroImageHeight ??
            defaultThemeData.heroImageHeight);
    final pageHasTopBarLayer = page.hasTopBarLayer ??
        themeData?.hasTopBarLayer ??
        defaultThemeData.hasTopBarLayer;
    final isTopBarLayerAlwaysVisible =
        pageHasTopBarLayer && page.isTopBarLayerAlwaysVisible == true;
    final navBarHeight = page.navBarHeight ??
        themeData?.navBarHeight ??
        defaultThemeData.navBarHeight;
    final topBarHeight = (pageHasTopBarLayer ||
            page.leadingNavBarWidget != null ||
            page.trailingNavBarWidget != null)
        ? navBarHeight
        : 0.0;
    final isNonScrollingPage = page is NonScrollingWoltModalSheetPage;
    final shouldFillRemaining = widget.woltModalType.forceMaxHeight ||
        (page.forceMaxHeight && !isNonScrollingPage);
    final physics = themeData?.mainContentScrollPhysics ??
        defaultThemeData.mainContentScrollPhysics;
    final slivers = <Widget>[
      if (!isNonScrollingPage)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                final heroImage = page.heroImage;
                return heroImage != null
                    ? WoltModalSheetHeroImage(
                        topBarHeight: topBarHeight,
                        heroImage: heroImage,
                        heroImageHeight: heroImageHeight,
                        scrollAnimationStyle: widget.scrollAnimationStyle,
                      )
                    : SizedBox(
                        height: isTopBarLayerAlwaysVisible ? 0 : topBarHeight,
                      );
              }
              return KeyedSubtree(
                key: widget.pageTitleKey,
                child: page.pageTitle ?? const SizedBox.shrink(),
              );
            },
            childCount: 2,
          ),
        ),
      ...page.mainContentSliversBuilder(context),
      if (shouldFillRemaining)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        ),
    ];

    return Padding(
      padding:
          EdgeInsets.only(top: isTopBarLayerAlwaysVisible ? topBarHeight : 0),
      child: LayoutBuilder(builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        // Phase 1: measure content height offstage
        if (_measuredHeight == null) {
          // Measure intrinsic content height using shrinkWrap offstage
          return Offstage(
            offstage: true,
            child: MeasureSize(
              onChange: (size) => setState(() => _measuredHeight = size.height),
              child: CustomScrollView(
                shrinkWrap: true,
                physics: physics,
                controller: widget.scrollController,
                slivers: slivers,
              ),
            ),
          );
        }
        // Phase 2: if this is a WoltModalSheetPage and content is shorter than max, render without scrolling
        if (_measuredHeight! < maxHeight && widget.page is WoltModalSheetPage) {
          final p = widget.page as WoltModalSheetPage;
          final heroImage = p.heroImage;
          final pageTitle = p.pageTitle;
          final children = <Widget>[];
          if (heroImage != null) {
            children.add(WoltModalSheetHeroImage(
              topBarHeight: topBarHeight,
              heroImage: heroImage,
              heroImageHeight: heroImageHeight,
              scrollAnimationStyle: widget.scrollAnimationStyle,
            ));
          } else {
            children.add(SizedBox(
              height: isTopBarLayerAlwaysVisible ? 0 : topBarHeight,
            ));
          }
          if (pageTitle != null) {
            children
                .add(KeyedSubtree(key: widget.pageTitleKey, child: pageTitle));
          }
          children.add(p.child);
          if (shouldFillRemaining) {
            // pad to fill remaining if needed
            children.add(SizedBox(height: maxHeight - _measuredHeight!));
          }
          return Column(mainAxisSize: MainAxisSize.min, children: children);
        }
        // Otherwise cap scrollable to maxHeight without shrinkWrap
        final height =
            _measuredHeight! < maxHeight ? _measuredHeight! : maxHeight;
        return SizedBox(
          height: height,
          child: CustomScrollView(
            physics: physics,
            controller: widget.scrollController,
            slivers: slivers,
          ),
        );
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // After first frame, measure Offstage child's size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_measuredHeight == null) {
        final contextBox = context.findRenderObject();
        if (contextBox is RenderBox) {
          setState(() => _measuredHeight = contextBox.size.height);
        }
      }
    });
  }
}

/// A widget to measure its child's size after layout
class MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;
  const MeasureSize({Key? key, required this.onChange, Widget? child})
      : super(key: key, child: child);
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRender(onChange);
}

class _MeasureSizeRender extends RenderProxyBox {
  final ValueChanged<Size> onChange;
  Size? _oldSize;
  _MeasureSizeRender(this.onChange);
  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
    }
  }
}
