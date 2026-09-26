import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftui_kit/src/fallback/entrance_fade.dart';
import 'package:swiftui_kit/src/native/glass_contract.dart';
import 'package:swiftui_kit/src/theme/glass_motion.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'support.dart';

const List<GlassCapsuleItem> _items = <GlassCapsuleItem>[
  GlassCapsuleItem(
    label: 'Home',
    icon: GlassIcon(systemName: 'house.fill', fallback: Icons.home),
  ),
  GlassCapsuleItem(
    label: 'Tasks',
    icon: GlassIcon(systemName: 'checklist', fallback: Icons.checklist),
  ),
];

/// A page. [renderer] is the renderer for the subtree, which is chosen by an
/// enclosing scope rather than by the bar itself.
Widget app(
  Widget child, {
  Brightness brightness = Brightness.light,
  GlassRenderer renderer = GlassRenderer.auto,
}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GlassRendererScope(renderer: renderer, child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassCapsuleBar, fallback renderer', () {
    testWidgets('lays out the items and reports taps by index', (
      WidgetTester tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        app(
          GlassCapsuleBar(
            items: _items,
            selectedIndex: 0,
            onItemTap: taps.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(taps, <int>[1]);
    });

    testWidgets('auto falls back on a platform without the native renderer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        app(const GlassCapsuleBar(items: _items, selectedIndex: 0)),
      );
      await tester.pumpAndSettle();

      expect(hasNativeRenderer, isFalse);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search is driven by the caller', (WidgetTester tester) async {
      Widget bar(bool searching) => app(
            GlassCapsuleBar(
              items: _items,
              selectedIndex: 0,
              searchEnabled: true,
              searching: searching,
              searchPrompt: 'Find',
            ),
          );

      await tester.pumpWidget(bar(false));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      await tester.pumpWidget(bar(true));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Find'), findsOneWidget);

      await tester.pumpWidget(bar(false));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('fades in from transparent on mount', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        app(GlassCapsuleBar(items: _items, selectedIndex: 0)),
      );
      // The first frame has not faded in yet. The router has a fade of its own,
      // so the one to look for is inside the fallback.
      FadeTransition fade() => tester.widget<FadeTransition>(
            find.descendant(
              of: find.byType(EntranceFade),
              matching: find.byType(FadeTransition),
            ),
          );
      expect(fade().opacity.value, lessThan(0.5));

      await tester.pump(GlassMotion.entranceFade);
      expect(fade().opacity.value, 1);
    });
  });

  group('GlassCapsuleBar, native renderer', () {
    useFakeHost();

    testWidgets(
        'pushes the view type and the whole spec on creation',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  const GlassCapsuleBar(
                    items: _items,
                    selectedIndex: 1,
                    searchEnabled: true,
                    searchPrompt: 'Find',
                    trailing: GlassCapsuleItem(
                      label: 'Me',
                      icon: GlassIcon(systemName: 'person'),
                    ),
                    height: 62,
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(host.viewType, GlassContract.capsuleBarViewType);
              expect(host.spec['height'], 62.0);
              expect(host.spec['selectedIndex'], 1);
              expect(host.spec['searchEnabled'], isTrue);
              expect(host.spec['searchHint'], 'Find');
              expect(host.spec['searchCancel'], 'Cancel');
              expect(host.spec['interactive'], isTrue);

              final items = host.spec['items']! as List<Object?>;
              expect(items, hasLength(2));
              expect(
                (items.first! as Map<Object?, Object?>)['symbol'],
                'house.fill',
                reason:
                    'the native side only knows SF Symbols; Flutter icons do not '
                    'cross over',
              );

              final trailing = host.spec['trailing']! as Map<Object?, Object?>;
              expect(trailing['label'], 'Me');

              final palette = host.spec['palette']! as Map<Object?, Object?>;
              expect(palette['isDark'], isFalse);
              expect(palette['selectedFill'], isA<int>());
              expect(palette['foreground'], isA<int>());
            }));

    testWidgets(
        'reserves the bar height plus the padding around it',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester
                  .pumpWidget(app(const GlassCapsuleBar(items: _items)));
              await tester.pumpAndSettle();

              // The same padding the fallback applies: 16 at the sides, 14 above, and 8
              // below when there is no safe area. The padding is applied on the Dart
              // side because a platform view is a bare rectangle, so the view itself
              // covers exactly the capsule.
              final Rect view = tester.getRect(find.byType(AppKitView));
              final Rect bar = tester.getRect(find.byType(GlassCapsuleBar));
              expect(view.size, const Size(800 - 32, 62));
              expect(view.left, bar.left + 16);
              expect(view.top, bar.top + 14);
              expect(view.bottom, bar.bottom - 8);
              // The native renderer is not wrapped in the fade: its first frame is
              // already late, and a fade would double the delay.
              expect(find.byType(EntranceFade), findsNothing);
            }));

    testWidgets(
        'pushes a changed spec once and an unchanged one never',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              Widget build(int index) => app(
                    GlassCapsuleBar(
                      key: const ValueKey<String>('bar'),
                      items: _items,
                      selectedIndex: index,
                    ),
                  );

              await tester.pumpWidget(build(0));
              await tester.pumpAndSettle();
              // One push after the view exists, because creation is asynchronous and
              // the caller may have changed the spec in the meantime. Just the one.
              expect(host.pushes, hasLength(1));
              expect(host.lastPush['selectedIndex'], 0);

              await tester.pumpWidget(build(1));
              await tester.pumpAndSettle();
              expect(host.pushes, hasLength(2));
              expect(host.lastPush['selectedIndex'], 1);

              await tester.pumpWidget(build(1));
              await tester.pumpAndSettle();
              expect(host.pushes, hasLength(2),
                  reason: 'an identical spec is not pushed');
            }));

    testWidgets(
        'routes each event to its own callback',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              final taps = <int>[];
              int trailing = 0;
              int entered = 0;
              final changed = <String>[];
              final submitted = <String>[];
              int cancelled = 0;

              await tester.pumpWidget(
                app(
                  GlassCapsuleBar(
                    items: _items,
                    trailing: const GlassCapsuleItem(label: 'Me'),
                    onItemTap: taps.add,
                    onTrailingTap: () => trailing++,
                    onSearchEnter: () => entered++,
                    onSearchChanged: changed.add,
                    onSearchSubmitted: submitted.add,
                    onSearchCancel: () => cancelled++,
                  ),
                ),
              );
              await tester.pumpAndSettle();

              await host.emit('itemTap', index: 1);
              await host.emit('trailingTap');
              await host.emit('searchEnter');
              await host.emit('searchChanged', text: 'Gra');
              await host.emit('searchSubmitted', text: 'Grade 3B');
              await host.emit('searchCancel');
              await tester.pump();

              expect(taps, <int>[1]);
              expect(trailing, 1);
              expect(entered, 1);
              expect(changed, <String>['Gra']);
              expect(submitted, <String>['Grade 3B']);
              expect(cancelled, 1);
            }));

    testWidgets(
        'ignores an event it does not recognise',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              final taps = <int>[];
              await tester.pumpWidget(
                app(GlassCapsuleBar(items: _items, onItemTap: taps.add)),
              );
              await tester.pumpAndSettle();

              await host.emit('somethingElse');
              await host.emit('itemTap');
              await tester.pump();

              expect(taps, isEmpty);
              expect(tester.takeException(), isNull);
            }));

    testWidgets('asserts when the native renderer is forced without one', (
      WidgetTester tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          app(
            const GlassCapsuleBar(items: _items),
            renderer: GlassRenderer.native,
          ),
        );
        expect(tester.takeException(), isAssertionError);
        // The asserted tree is still mounted and would be rebuilt during
        // teardown, so replace it first.
        await tester.pumpWidget(app(const SizedBox.shrink()));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
