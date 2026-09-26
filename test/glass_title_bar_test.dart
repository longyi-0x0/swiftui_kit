import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftui_kit/src/fallback/liquid_glass_surface.dart';
import 'package:swiftui_kit/src/native/glass_contract.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'support.dart';

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
          alignment: Alignment.topCenter,
          child: GlassRendererScope(renderer: renderer, child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlassTitleBar, fallback renderer', () {
    testWidgets('lays out the title and the items, each with its own callback',
        (
      WidgetTester tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        app(
          GlassTitleBar(
            title: 'Grade 3B',
            items: <GlassTitleItem>[
              GlassTitleItem(
                placement: GlassTitlePlacement.topBarLeading,
                icon: const GlassIcon(
                  systemName: 'chevron.backward',
                  fallback: Icons.arrow_back_ios_new,
                ),
                help: 'Back',
                onPressed: () => taps.add('Back'),
              ),
              GlassTitleItem(label: 'Edit', onPressed: () => taps.add('Edit')),
              GlassTitleItem(
                icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
                onPressed: () => taps.add('Add'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grade 3B'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(taps, <String>['Edit']);

      // Back is simply a leading item; there is no separate entry point for it.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(taps, <String>['Edit', 'Back']);
    });

    testWidgets('a group shares one glass and numbers its members flattened', (
      WidgetTester tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        app(
          GlassTitleBar(
            title: 'Seating',
            items: <GlassTitleElement>[
              GlassTitleGroup(
                items: <GlassTitleItem>[
                  GlassTitleItem(
                    icon: const GlassIcon(
                      systemName: 'square.grid.3x3',
                      fallback: Icons.grid_view,
                    ),
                    onPressed: () => taps.add(0),
                  ),
                  GlassTitleItem(
                    icon: const GlassIcon(
                      systemName: 'bell',
                      fallback: Icons.notifications_none,
                    ),
                    onPressed: () => taps.add(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both members are there, inside a single piece of glass.
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byType(LiquidGlassSurface), findsOneWidget);

      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();
      expect(taps, <int>[1]);
    });
  });

  group('GlassTitleBar, native renderer', () {
    useFakeHost();

    testWidgets(
        'pushes the whole spec on creation',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  GlassTitleBar(
                    title: 'Grade 3B',
                    subtitle: '502 items',
                    displayMode: GlassTitleDisplayMode.large,
                    searchPrompt: 'Find',
                    items: <GlassTitleItem>[
                      const GlassTitleItem(
                        placement: GlassTitlePlacement.topBarLeading,
                        label: '8F2K',
                      ),
                      GlassTitleItem(
                        icon: const GlassIcon(
                          systemName: 'magnifyingglass',
                          fallback: Icons.search,
                        ),
                        onPressed: () {},
                      ),
                      const GlassTitleItem(
                        placement: GlassTitlePlacement.principal,
                        label: 'Custom title',
                      ),
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(host.viewType, GlassContract.titleBarViewType);
              expect(host.spec['title'], 'Grade 3B');
              expect(host.spec['subtitle'], '502 items');
              expect(host.spec['displayMode'], 'large');
              expect(host.spec['searching'], isFalse);
              expect(host.spec['searchHint'], 'Find');
              expect(host.spec['searchCancel'], 'Cancel');
              expect(host.spec['height'], 37.0);
              expect(host.spec['spacing'], 6.0);

              final items = (host.spec['items']! as List<Object?>)
                  .cast<Map<Object?, Object?>>();
              expect(items, hasLength(3));
              expect(items[0]['placement'], 'leading');
              expect(
                items[0]['pressable'],
                isFalse,
                reason: 'an item without onPressed is not pressable',
              );
              expect(items[1]['symbol'], 'magnifyingglass');
              expect(items[1]['pressable'], isTrue);
              expect(items[2]['placement'], 'principal');
              expect(
                items[0]['ink'],
                isA<int>(),
                reason:
                    'the ink is resolved on the Dart side and the native side only '
                    'draws the number',
              );
              expect(
                items[0].containsKey('tint'),
                isFalse,
                reason: 'an unselected item does not tint its glass',
              );
            }));

    testWidgets(
        'gives the native side the extra two lines a large title needs',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  const GlassTitleBar(
                    title: 'Grade 3B',
                    subtitle: '502 items',
                    displayMode: GlassTitleDisplayMode.large,
                  ),
                ),
              );
              await tester.pumpAndSettle();

              // A 37 pt item cannot hold an 18 pt subtitle plus a 34 pt title, so the
              // box follows the latter.
              expect(tester.getSize(find.byType(AppKitView)).height, 18 + 34);
            }));

    testWidgets(
        'carries the fill of a selected item',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  GlassTitleBar(
                    items: <GlassTitleItem>[
                      GlassTitleItem(
                        icon: const GlassIcon(
                          systemName: 'person',
                          fallback: Icons.person,
                        ),
                        selected: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();

              final Map<Object?, Object?> item =
                  (host.spec['items']! as List<Object?>)
                      .cast<Map<Object?, Object?>>()
                      .single;
              expect(item['selected'], isTrue);
              expect(item['tint'], isA<int>());
            }));

    testWidgets(
        'pushes the brightness of a dark theme',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  const GlassTitleBar(title: 'Grade 3B'),
                  brightness: Brightness.dark,
                ),
              );
              await tester.pumpAndSettle();

              final palette = host.spec['palette']! as Map<Object?, Object?>;
              expect(palette['isDark'], isTrue);
            }));

    testWidgets(
        'routes each event to its own callback',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              int second = 0;
              int cancelled = 0;
              final changed = <String>[];
              final submitted = <String>[];

              await tester.pumpWidget(
                app(
                  GlassTitleBar(
                    title: 'Grade 3B',
                    onSearchChanged: changed.add,
                    onSearchSubmitted: submitted.add,
                    onSearchCancel: () => cancelled++,
                    items: <GlassTitleItem>[
                      const GlassTitleItem(label: 'Edit'),
                      GlassTitleItem(label: 'More', onPressed: () => second++),
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();

              // Indices refer to `items`, including the one that cannot be pressed.
              await host.emit('itemTap', index: 1);
              await host.emit('searchChanged', text: 'Gra');
              await host.emit('searchSubmitted', text: 'Grade 3B');
              await host.emit('searchCancel');
              await host.emit('itemTap', index: 0);
              await host.emit('trailingTap');
              await tester.pump();

              expect(second, 1);
              expect(changed, <String>['Gra']);
              expect(submitted, <String>['Grade 3B']);
              expect(cancelled, 1);
              expect(tester.takeException(), isNull);
            }));

    testWidgets(
        'pushes a group as one entry with its members inside',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              await tester.pumpWidget(
                app(
                  GlassTitleBar(
                    title: 'Seating',
                    items: <GlassTitleElement>[
                      GlassTitleGroup(
                        gap: 4,
                        items: <GlassTitleItem>[
                          const GlassTitleItem(label: 'Edit'),
                          const GlassTitleItem(label: 'More'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
              await tester.pumpAndSettle();

              final first = (host.spec['items']! as List<Object?>).first!
                  as Map<Object?, Object?>;
              expect(first['placement'], 'trailing');
              expect(first['gap'], 4);

              final group = first['group']! as List<Object?>;
              expect(group.length, 2);
              expect((group.first! as Map<Object?, Object?>)['label'], 'Edit');
              expect((group.last! as Map<Object?, Object?>)['label'], 'More');
            }));

    testWidgets(
        'pushes the search state as soon as it is set',
        (
          WidgetTester tester,
        ) async =>
            asMacOs(() async {
              Widget build(bool searching) => app(
                    GlassTitleBar(
                      key: const ValueKey<String>('bar'),
                      title: 'Grade 3B',
                      searching: searching,
                    ),
                  );

              await tester.pumpWidget(build(false));
              await tester.pumpAndSettle();
              expect(host.spec['searching'], isFalse);

              await tester.pumpWidget(build(true));
              await tester.pumpAndSettle();
              expect(host.lastPush['searching'], isTrue);
            }));
  });
}
