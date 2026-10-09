// The floating capsule at the bottom, in its various shapes.
//
// One case per shape: the same items at the same height, with one thing
// different — only the difference is visible. Every case carries the two code
// samples for that one point: which SwiftUI lines it corresponds to, and which
// Dart lines.

import 'package:flutter/material.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'glass_case.dart';

/// Every shape on the capsule page.
List<GlassCase> capsuleCases() => <GlassCase>[
      _case(
        'Three items · middle selected',
        'The ordinary state: three items, the middle one carrying a grey plate. Interactive.',
        swift: r'''
HStack(spacing: 0) {
  ForEach(items) { item in
    Button { select(item) } label: {
      Label(item.label, systemImage: item.symbol)
        .padding(.horizontal, 22 * scale)
        // The selection is a fill, not another piece of glass: refraction over a
        // flat page shifts the tone by single digits — no visible selection.
        .background {
          if item.id == selectedID { Capsule().fill(selectedPlate) }
        }
    }
    .buttonStyle(.plain)
  }
}
.padding(3)
.fixedSize(horizontal: true, vertical: false)
.glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
      ),
      _case(
        'No selection',
        'selectedIndex left null: no pill at all, everything else unchanged.',
        swift: r'''
ForEach(items) { item in
  Button { select(item) } label: {
    // Nothing is selected, so there is no pill underneath
    Label(item.label, systemImage: item.symbol)
  }
  .buttonStyle(.plain)
}
.padding(3)
.glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  items: items,          // no selectedIndex
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          onItemTap: live.recordTab(_tabs),
        ),
      ),
      _case(
        'Trailing · icon only',
        'A trailing item with an icon alone: the trailing glass is a circle whose diameter is height.',
        swift: r'''
HStack(spacing: 0) {
  itemsCapsule
  Spacer(minLength: 8)                    // the two capsules sit at the ends; the gap is what is left
  Button { more() } label: {
    Image(systemName: "ellipsis")
      .frame(width: height, height: height)   // a circle: the diameter is height
      .contentShape(Circle())
  }
  .buttonStyle(.plain)
  .glassEffect(.regular, in: .capsule)
}''',
        dart: r'''
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
  trailing: const GlassCapsuleItem(
    icon: GlassIcon(systemName: 'ellipsis', fallback: Icons.more_horiz),
  ),
  onTrailingTap: () => live.watch('trailing item'),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
          trailing: const GlassCapsuleItem(
            label: '',
            icon: GlassIcon(systemName: 'ellipsis', fallback: Icons.more_horiz),
          ),
          onTrailingTap: () => live.watch('trailing item'),
        ),
      ),
      _case(
        'Trailing · with label',
        'A trailing item with a label: the trailing glass stretches to the text instead of matching the left capsule.',
        swift: r'''
Button { more() } label: {
  Label("More", systemImage: "ellipsis")
    // Stretches to the text rather than matching the left capsule
    .padding(.horizontal, 22 * scale)
}
.buttonStyle(.plain)
.glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
  trailing: const GlassCapsuleItem(
    label: 'More',
    icon: GlassIcon(systemName: 'ellipsis', fallback: Icons.more_horiz),
  ),
  onTrailingTap: () => live.watch('More'),
)''',
        (Live live) => GlassCapsuleBar(
          items: _twoTabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
          trailing: const GlassCapsuleItem(
            label: 'More',
            icon: GlassIcon(systemName: 'ellipsis', fallback: Icons.more_horiz),
          ),
          onTrailingTap: () => live.watch('More'),
        ),
      ),
      _case(
        'Search',
        'searchEnabled: a magnifier at the trailing end. Tap it to go in — the left capsule widens into a field carrying Cancel.',
        swift: r'''
if searching {
  HStack(spacing: 8) {
    Image(systemName: "magnifyingglass")
    TextField("Search", text: $text)   // widens into a field
      .textFieldStyle(.plain)
    Button("Cancel") { searching = false }.buttonStyle(.plain)
  }
  .padding(.leading, 16)
  .glassEffect(.regular, in: .capsule)
} else {
  Button { searching = true } label: {
    Image(systemName: "magnifyingglass")
  }
    .glassEffect(.regular, in: .capsule)
}''',
        dart: r'''
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  searchEnabled: true,                    // the magnifier at the trailing end
  searching: live.searching,              // the caller owns whether it is open
  searchPrompt: 'Search',
  onSearchEnter: () => live.setSearching(true),
  onSearchChanged: live.watch,
  onSearchCancel: () => live.setSearching(false),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
          searchEnabled: true,
          searching: live.searching,
          searchPrompt: 'Search',
          onSearchEnter: () => live.setSearching(true),
          onSearchChanged: live.watch,
          onSearchSubmitted: (String text) => live.watch('submitted $text'),
          onSearchCancel: () => live.setSearching(false),
        ),
      ),
      _case(
        'Receding',
        'visualWeight 0.35: recedes while something sits above it. Tap this case to switch back.',
        swift: r'''
itemsCapsule
  .opacity(0.55 + 0.45 * 0.35)            // the receded step
  .allowsHitTesting(true)''',
        dart: r'''
GlassCapsuleBar(
  visualWeight: live.weight,              // 0.35
  items: items,
  selectedIndex: live.tab,
  onItemTap: (_) => live.toggleWeight(),
)''',
        (Live live) => GlassCapsuleBar(
          visualWeight: live.weight,
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: (int index) => live.toggleWeight(),
        ),
      ),
      _case(
        'Not hittable',
        'allowsHitTesting: false: no press is accepted, and the look differs too.',
        swift: r'''
itemsCapsule
  .allowsHitTesting(false)                // no press is accepted
  .glassEffect(.regular.interactive(false), in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  allowsHitTesting: false,
  items: items,
  selectedIndex: 0,
)''',
        (Live live) => GlassCapsuleBar(
          allowsHitTesting: false,
          items: _tabs,
          selectedIndex: 0,
        ),
      ),
      _case(
        'Labels only',
        'No icons: an item stretches to its text instead of being a circle.',
        swift: r'''
Button { select(item) } label: {
  Text(item.label)                        // no icon: stretches to the text
    .padding(.horizontal, 22 * scale)
    .frame(minHeight: height - 6)
}
.buttonStyle(.plain)''',
        dart: r'''
GlassCapsuleBar(
  items: const <GlassCapsuleItem>[
    GlassCapsuleItem(label: 'All'),
    GlassCapsuleItem(label: 'Open'),
    GlassCapsuleItem(label: 'Done'),
  ],
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: const <GlassCapsuleItem>[
            GlassCapsuleItem(label: 'All'),
            GlassCapsuleItem(label: 'Open'),
            GlassCapsuleItem(label: 'Done'),
          ],
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
      ),
      _case(
        'Icons only',
        'No labels: an item is a circle whose diameter is height.',
        swift: r'''
Button { select(item) } label: {
  Image(systemName: item.symbol!)         // no label: a circle of diameter height
    .frame(width: height, height: height)
    .contentShape(Circle())
}
.buttonStyle(.plain)''',
        dart: r'''
GlassCapsuleBar(
  items: const <GlassCapsuleItem>[
    GlassCapsuleItem(
      label: '',                           // no label: a circle of diameter height
      icon: GlassIcon(systemName: 'circle', fallback: Icons.circle_outlined),
    ),
    GlassCapsuleItem(
      label: '',
      icon: GlassIcon(systemName: 'square', fallback: Icons.square_outlined),
    ),
    GlassCapsuleItem(
      label: '',
      icon: GlassIcon(
        systemName: 'triangle',
        fallback: Icons.change_history,
      ),
    ),
  ],
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: const <GlassCapsuleItem>[
            GlassCapsuleItem(
              label: '',
              icon: GlassIcon(
                  systemName: 'circle', fallback: Icons.circle_outlined),
            ),
            GlassCapsuleItem(
              label: '',
              icon: GlassIcon(
                  systemName: 'square', fallback: Icons.square_outlined),
            ),
            GlassCapsuleItem(
              label: '',
              icon: GlassIcon(
                systemName: 'triangle',
                fallback: Icons.change_history,
              ),
            ),
          ],
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
      ),
      _case(
        'Height 52',
        'height 52: text and icons shrink with it, and the selection pill is narrower.',
        swift: r'''
itemsCapsule
  .frame(height: 52)                      // scale = 52 / 52
  .glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  height: 52,
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          height: 52,
          items: _twoTabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
        barHeight: 52,
      ),
      _case(
        'Height 74',
        'height 74: the same items scaled up to a taller, phone-typical height.',
        swift: r'''
itemsCapsule
  // scale = 74 / 52: text and icons scale up with it
  .frame(height: 74)
  .glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  height: 74,
  items: two,             // the same two items, scaled to 74
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          height: 74,
          items: _twoTabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
        barHeight: 74,
      ),
      _case(
        'Five items',
        'With more items each one shrinks, and so does the pill.',
        swift: r'''
ForEach(items) { item in                   // with more items each one shrinks
  Button { select(item) } label: {
    Label(item.label, systemImage: item.symbol)
      .padding(.horizontal, 22 * scale)
  }
  .buttonStyle(.plain)
}
.fixedSize(horizontal: true, vertical: false)
.glassEffect(.regular, in: .capsule)''',
        dart: r'''
GlassCapsuleBar(
  items: five,            // Item 1 … Item 5
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: const <GlassCapsuleItem>[
            GlassCapsuleItem(
              label: 'Home',
              icon: GlassIcon(
                  systemName: 'circle', fallback: Icons.circle_outlined),
            ),
            GlassCapsuleItem(
              label: 'Item 2',
              icon: GlassIcon(
                  systemName: 'square', fallback: Icons.square_outlined),
            ),
            GlassCapsuleItem(
              label: 'Item 3',
              icon: GlassIcon(
                  systemName: 'diamond', fallback: Icons.diamond_outlined),
            ),
            GlassCapsuleItem(
              label: 'Item 4',
              icon: GlassIcon(
                  systemName: 'hexagon', fallback: Icons.hexagon_outlined),
            ),
            GlassCapsuleItem(
              label: 'Item 5',
              icon: GlassIcon(
                systemName: 'triangle',
                fallback: Icons.change_history,
              ),
            ),
          ],
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
      ),
      _case(
        'On white',
        'surface: light — glass over a bright backdrop: whether the edges and the text still hold up.',
        swift: r'''
ZStack {
  Color.white                             // the page: glass over a bright backdrop
  itemsCapsule.glassEffect(.regular, in: .capsule)
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on white.
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
        surface: CaseSurface.light,
      ),
      _case(
        'On dark',
        'surface: dark — thickness and text weight over a dark backdrop.',
        swift: r'''
ZStack {
  // thickness and text weight over a dark backdrop
  Color(red: 0.08, green: 0.09, blue: 0.10)
  itemsCapsule.glassEffect(.regular, in: .capsule)
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on dark.
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
        surface: CaseSurface.dark,
      ),
      _case(
        'On light grey',
        'surface: plain — the light grey of a page background, the most common case.',
        swift: r'''
ZStack {
  Color(white: 0.95)                      // the light grey of a page background
  itemsCapsule.glassEffect(.regular, in: .capsule)
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on light grey.
GlassCapsuleBar(
  items: items,
  selectedIndex: live.tab,
  onItemTap: live.recordTab(items),
)''',
        (Live live) => GlassCapsuleBar(
          items: _tabs,
          selectedIndex: live.tab,
          onItemTap: live.recordTab(_tabs),
        ),
        surface: CaseSurface.plain,
      ),
    ];

GlassCase _case(
  String title,
  String hint,
  Widget Function(Live live) build, {
  required String swift,
  required String dart,
  CaseSurface surface = CaseSurface.photo,
  double barHeight = 62,
}) =>
    GlassCase(
      title: title,
      hint: hint,
      height: 116,
      atTop: false,
      barHeight: barHeight,
      surface: surface,
      swift: swift,
      dart: dart,
      build: build,
    );

const List<GlassCapsuleItem> _twoTabs = <GlassCapsuleItem>[
  GlassCapsuleItem(
    label: 'Item 1',
    icon: GlassIcon(systemName: 'circle', fallback: Icons.circle_outlined),
  ),
  GlassCapsuleItem(
    label: 'Item 2',
    icon: GlassIcon(systemName: 'square', fallback: Icons.square_outlined),
  ),
];

const List<GlassCapsuleItem> _tabs = <GlassCapsuleItem>[
  GlassCapsuleItem(
    label: 'Item 1',
    icon: GlassIcon(systemName: 'circle', fallback: Icons.circle_outlined),
  ),
  GlassCapsuleItem(
    label: 'Item 2',
    icon: GlassIcon(systemName: 'square', fallback: Icons.square_outlined),
  ),
  GlassCapsuleItem(
    label: 'Item 3',
    icon: GlassIcon(
      systemName: 'triangle',
      fallback: Icons.change_history,
    ),
  ),
];
