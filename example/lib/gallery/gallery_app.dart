// The gallery shell: sidebar, toolbar and the list of cases.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import '../capture/page_capture.dart';
import 'case_view.dart';
import 'gallery_pages.dart';
import 'gallery_stage.dart';
import 'gallery_theme.dart';
import 'glass_case.dart';

/// The gallery app.
class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, required this.pages, this.onStage});

  final List<GalleryPage> pages;

  /// Handed the gallery once it is up, so the capture server can switch page,
  /// switch appearance, scroll to a case and take images.
  final ValueChanged<GalleryStage>? onStage;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'swiftui_kit gallery',
        debugShowCheckedModeBanner: false,
        theme: galleryTheme(Brightness.light),
        darkTheme: galleryTheme(Brightness.dark),
        home: Gallery(pages: pages, onStage: onStage),
      );
}

/// The gallery shell: a sidebar on the left (the pages; tap one to switch), a
/// toolbar on top (which page this is, the appearance, and a copy-whole-page
/// button), and the list of cases underneath. One case is a headline plus a
/// frame holding two lanes side by side: native on the left, fallback on the
/// right, each with its own code sample below its canvas. The two lanes show
/// the same spec at the same moment, so any difference is a real one.
class Gallery extends StatefulWidget {
  const Gallery({super.key, required this.pages, this.onStage});

  final List<GalleryPage> pages;

  /// See [GalleryApp.onStage].
  final ValueChanged<GalleryStage>? onStage;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> implements GalleryStage {
  int _page = 0;
  bool _dark = false;

  /// The case list's scroll position. Whole-page capture scrolls it screen by
  /// screen.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final ValueChanged<GalleryStage>? onStage = widget.onStage;
    if (onStage != null) {
      // Hand it over after the first frame: as soon as it is out, something may
      // ask for an image, and by then the list has to be laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onStage(this);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GalleryPage get _current => widget.pages[_page];

  @override
  List<String> get pageLabels =>
      <String>[for (final GalleryPage each in widget.pages) each.label];

  @override
  List<List<GlassCase>> get allCases => <List<GlassCase>>[
        for (final GalleryPage each in widget.pages) each.cases
      ];

  @override
  int get page => _page;

  @override
  void showPage(int index) {
    if (index == _page || index < 0 || index >= widget.pages.length) return;
    setState(() => _page = index);
  }

  @override
  bool get dark => _dark;

  @override
  set dark(bool value) {
    if (value == _dark) return;
    setState(() => _dark = value);
  }

  @override
  ScrollController get scroll => _scroll;

  @override
  GlobalKey get viewportKey => listKey;

  @override
  Color get background =>
      galleryTheme(_dark ? Brightness.dark : Brightness.light)
          .scaffoldBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: galleryTheme(_dark ? Brightness.dark : Brightness.light),
      child: Scaffold(
        body: Row(
          children: <Widget>[
            _Sidebar(
              key: sidebarKey,
              pages: widget.pages,
              page: _page,
              onSelect: (int index) => setState(() => _page = index),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _Toolbar(
                    title: _current.label,
                    note: _current.note,
                    dark: _dark,
                    onDark: () => setState(() => _dark = !_dark),
                    controller: _scroll,
                    viewportKey: listKey,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(child: _list()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list of cases on this page.
  Widget _list() => ListView.separated(
        key: listKey,
        controller: _scroll,
        padding: const EdgeInsets.all(10),
        itemCount: _current.cases.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 14),
        itemBuilder: (BuildContext context, int index) =>
            CaseView(item: _current.cases[index], width: canvasWidth),
      );
}

/// The sidebar on the left: the pages.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    super.key,
    required this.pages,
    required this.page,
    required this.onSelect,
  });

  final List<GalleryPage> pages;
  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SizedBox(
      width: 200,
      child: ColoredBox(
        color: scheme.surfaceContainer,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.blur_on, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'swiftui_kit gallery',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < pages.length; i++) ...<Widget>[
              _Row(
                icon: pages[i].icon,
                label: pages[i].label,
                selected: i == page,
                trailing: '${pages[i].cases.length}',
                onTap: () => onSelect(i),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.icon,
    this.trailing,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final GlassIcon? icon;
  final String? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color ink = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          children: <Widget>[
            if (icon != null)
              SizedBox(
                width: 18,
                child: Icon(
                  icon!.fallback,
                  size: 15,
                  color: ink.withValues(alpha: 0.8),
                ),
              ),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ink.withValues(alpha: selected ? 1 : 0.85),
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ink.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The toolbar on top.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.note,
    required this.dark,
    required this.onDark,
    required this.controller,
    required this.viewportKey,
  });

  final String title;
  final String note;
  final bool dark;
  final VoidCallback onDark;

  /// Handed to the button on the right: the case list's scroll position and the
  /// box around it.
  final ScrollController controller;
  final GlobalKey viewportKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDark,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Switch appearance',
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 8),
            _CopyPageButton(
              controller: controller,
              viewportKey: viewportKey,
            ),
          ],
        ),
      ),
    );
  }
}

/// The button at the top right: stitches the page's case list into one image
/// and puts it on the clipboard.
///
/// Once pressed the button shows the result in place — the size on success,
/// why on failure — and goes back after a moment.
class _CopyPageButton extends StatefulWidget {
  const _CopyPageButton({required this.controller, required this.viewportKey});

  /// The case list's scroll position and the box around it.
  final ScrollController controller;
  final GlobalKey viewportKey;

  @override
  State<_CopyPageButton> createState() => _CopyPageButtonState();
}

class _CopyPageButtonState extends State<_CopyPageButton> {
  /// What was just said (empty before the first press).
  String? _said;

  /// How long those two lines stay. Cancelled when this button is replaced.
  Timer? _undo;

  @override
  void dispose() {
    _undo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool ok = _said == null || _said!.startsWith('Copied');
    return FilledButton.tonalIcon(
      onPressed: _copy,
      icon: Icon(
        _said == null
            ? Icons.photo_camera_outlined
            : (ok ? Icons.check_circle_outline : Icons.error_outline),
        size: 16,
      ),
      label: Text(_said ?? 'Copy page'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: theme.textTheme.bodySmall,
      ),
    );
  }

  Future<void> _copy() async {
    final String said = await copyWholePageToClipboard(
      controller: widget.controller,
      viewportKey: widget.viewportKey,
      // Whatever the stitching does not cover is filled with the page colour.
      background: Theme.of(context).scaffoldBackgroundColor,
      // A page takes several screens, so the button reports progress (how many
      // screens there are is only known once the bottom is reached).
      progress: (int done) {
        if (!mounted) return;
        setState(() => _said = 'Stitching screen $done');
      },
    );
    if (!mounted) return;
    setState(() => _said = said);
    _undo?.cancel();
    _undo = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _said = null);
    });
  }
}
