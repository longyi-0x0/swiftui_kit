// How one case is laid out, and what the backdrops look like.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'glass_case.dart';

/// One case.
///
/// The state a case needs belongs to the case, so tapping it only moves that
/// case. Both lanes share that state, so they always show the same moment.
class CaseView extends StatefulWidget {
  const CaseView({super.key, required this.item, required this.width});

  /// The case to show.
  final GlassCase item;

  /// The width of one canvas.
  final double width;

  @override
  State<CaseView> createState() => _CaseViewState();
}

class _CaseViewState extends State<CaseView> {
  final Live _live = Live();

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _live,
        builder: (BuildContext context, _) => LayoutBuilder(
          builder: (BuildContext context, BoxConstraints limits) {
            // The two lanes sit side by side, each one canvas wide. When the
            // window is narrower than both, the frame scrolls sideways instead
            // of squeezing the canvases: squeezed canvases are no longer the
            // same spec, so they cannot be compared.
            final double lanes = widget.width * 2 + 12;
            final double width = limits.maxWidth.isFinite
                ? math.min(lanes, limits.maxWidth)
                : lanes;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // The headline is as wide as the frame below it, and the
                    // two share a left edge.
                    _Headline(item: widget.item, last: _live.last),
                    const SizedBox(height: 4),
                    _Frame(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _Lane(
                                label: 'Native',
                                width: widget.width,
                                height: widget.item.height,
                                codeName: 'Swift',
                                code: widget.item.swift,
                                child: CanvasPane(
                                  item: widget.item,
                                  renderer: GlassRenderer.native,
                                  live: _live,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _Lane(
                                label: 'Fallback',
                                width: widget.width,
                                height: widget.item.height,
                                codeName: 'Dart',
                                code: widget.item.dart,
                                child: CanvasPane(
                                  item: widget.item,
                                  renderer: GlassRenderer.fallback,
                                  live: _live,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

/// One lane of a case: a name on top, the canvas in the middle, that lane's own
/// code sample underneath.
///
/// All three are laid out at the same width, so a sample sits directly below
/// its canvas and the two lanes take one column each.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.label,
    required this.width,
    required this.height,
    required this.codeName,
    required this.code,
    required this.child,
  });

  final String label;

  /// The width of this column and the height of the canvas. Both lanes get the
  /// same pair, so the looks and the samples line up.
  final double width;
  final double height;

  /// Which language this lane shows, and its lines.
  final String codeName;
  final String code;

  /// The canvas.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: width, height: height, child: child),
          const SizedBox(height: 8),
          Expanded(child: CodeBlock(name: codeName, code: code)),
        ],
      ),
    );
  }
}

/// The headline of a case: the name, one line about it, and — once something
/// has been tapped — what was tapped.
class _Headline extends StatelessWidget {
  const _Headline({required this.item, required this.last});

  final GlassCase item;

  /// What was tapped last; empty before anything is.
  final String last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Text(
          item.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
        if (last.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            'Tapped: $last',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// One code sample: the language and a copy button in the corner, the lines
/// underneath.
///
/// The height follows the text, so a lane takes exactly one row — however long
/// a sample is, it stays visible without scrolling. The copy button turns into
/// "Copied" in place: the native glass can sit underneath, and a popup would
/// not necessarily be visible.
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.name, required this.code});

  /// Which language this is (the name in the corner).
  final String name;

  /// The lines.
  final String code;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  /// Whether the copy button was just pressed; it clears itself.
  bool _copied = false;

  /// How long that takes. Cancelled when this sample is replaced.
  Timer? _undo;

  @override
  void dispose() {
    _undo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String body = widget.code.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SelectableText.rich(_tinted(context, body)),
            ),
            Column(
              children: <Widget>[
                IconButton(
                  onPressed: () => _copy(body),
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy these ${widget.name} lines',
                  icon: Icon(
                    _copied
                        ? Icons.check_circle_outline
                        : Icons.content_copy_outlined,
                    color: _copied ? scheme.primary : null,
                  ),
                ),
                Text(
                  _copied ? 'Copied' : widget.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _copied ? scheme.primary : scheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Puts this sample on the clipboard — these are the lines a reader wants to
  /// paste elsewhere.
  Future<void> _copy(String body) async {
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    setState(() => _copied = true);
    _undo?.cancel();
    _undo = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }
}

/// The lines of a sample: the `//` tail is dimmed, the rest is one colour.
///
/// The text is small and tightly leaded because one column is only a canvas
/// wide, and a sample has to fit line by line instead of wrapping.
TextSpan _tinted(BuildContext context, String code) {
  final ThemeData theme = Theme.of(context);
  final ColorScheme scheme = theme.colorScheme;
  final TextStyle? plain = theme.textTheme.bodySmall?.copyWith(
    fontFamily: 'Menlo',
    fontFamilyFallback: const <String>['monospace', 'Courier'],
    fontSize: 11,
    height: 1.45,
    color: scheme.onSurface,
  );
  final TextStyle? faint = plain?.copyWith(
    color: scheme.outline,
    fontStyle: FontStyle.italic,
  );
  return TextSpan(
    style: plain,
    children: <InlineSpan>[
      for (final String line in code.split('\n')) ...<InlineSpan>[
        for (final (String text, bool comment) in _cut(line))
          TextSpan(text: text, style: comment ? faint : plain),
        const TextSpan(text: '\n'),
      ],
    ],
  );
}

/// Splits one line into the code and the `//` tail.
List<(String, bool)> _cut(String line) {
  final int at = line.indexOf('//');
  if (at < 0) return <(String, bool)>[(line, false)];
  return <(String, bool)>[
    (line.substring(0, at), false),
    (line.substring(at), true)
  ];
}

/// The frame that rings the two lanes of a case.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      );
}

/// One canvas: a backdrop, plus one piece of glass.
class CanvasPane extends StatelessWidget {
  const CanvasPane({
    super.key,
    required this.item,
    required this.renderer,
    required this.live,
  });

  final GlassCase item;
  final GlassRenderer renderer;
  final Live live;

  @override
  Widget build(BuildContext context) {
    final bool available =
        renderer != GlassRenderer.native || hasNativeRenderer;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: item.height,
        width: double.infinity,
        // The padding the glass carries itself follows the window's safe area,
        // which is not what we want inside a frame: a canvas is one solid
        // area, and the glass hugs its own end of it.
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: Stack(
            children: <Widget>[
              if (available) ...<Widget>[
                Positioned.fill(child: Backdrop(item.surface)),
                Align(
                  alignment:
                      item.atTop ? Alignment.topCenter : Alignment.bottomCenter,
                  child: GlassRendererScope(
                    renderer: renderer,
                    child: item.build(live),
                  ),
                ),
              ] else
                const Positioned.fill(child: _MissingLane()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "photo" behind the glass, or a flat colour.
class Backdrop extends StatelessWidget {
  const Backdrop(this.kind, {super.key});

  final CaseSurface kind;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return switch (kind) {
      CaseSurface.plain => ColoredBox(color: scheme.surfaceContainerHighest),
      CaseSurface.light => const ColoredBox(color: Color(0xFFFFFFFF)),
      CaseSurface.dark => const ColoredBox(color: Color(0xFF14161A)),
      CaseSurface.photo => const _Photo(),
    };
  }
}

/// A warm-to-cool gradient with a few colour blobs and two lines of text on top.
///
/// Blur, refraction and how much of the text underneath shows through all need
/// something to shine through: glass over a blank sheet and glass over a photo
/// are two different things.
class _Photo extends StatelessWidget {
  const _Photo();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF1C6E8C),
              Color(0xFF8E5A3C),
              Color(0xFF3B2A4A),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned(
              left: -40,
              top: -30,
              child: _Blob(size: 150, color: Color(0x66FFD166)),
            ),
            const Positioned(
              right: -46,
              bottom: -36,
              child: _Blob(size: 170, color: Color(0x55F26B8A)),
            ),
            const Positioned(
              right: 54,
              top: 30,
              child: _Blob(size: 80, color: Color(0x5522D3EE)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Page content',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Content passes under the glass, which is what makes the '
                    'blur and the refraction visible.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Stands in for the native lane on a platform that cannot draw it.
class _MissingLane extends StatelessWidget {
  const _MissingLane();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No SwiftUI on this platform, so the native lane cannot be '
              'drawn.\nRun on macOS or iOS to see it.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
}
