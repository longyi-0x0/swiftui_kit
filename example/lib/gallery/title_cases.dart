// The floating glass band at the top, in its various shapes.
//
// The layout follows the package's own title bar, which in turn follows
// SwiftUI's toolbar: an action is a piece of glass of its own, while the title
// is text floating on the page with no glass. Every case carries the two code
// samples for that one point: which SwiftUI lines it corresponds to, and which
// Dart lines.

import 'package:flutter/material.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'glass_case.dart';

/// Every shape on the title page.
List<GlassCase> titleCases() => <GlassCase>[
      _case(
        'Inline title',
        'The title in the centre, actions split between the two ends — the ordinary shape.',
        swift: r'''
.toolbar {
  ToolbarItem(placement: .principal) {        // the title floats in the centre, with no glass
    Text("Title").font(.system(size: 17, weight: .semibold))
  }
  ToolbarItem(placement: .topBarTrailing) {
    // one action, one piece of glass
    Button("Edit") { edit() }.buttonStyle(.glass)
  }
}''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    // Back on the leading end.
    GlassTitleItem(
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              label: 'Edit',
              onPressed: () => live.watch('edit'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: () => live.watch('add'),
            ),
          ],
        ),
      ),
      _case(
        'Leading · with label',
        'No back button on the leading end: a custom item (label plus icon) that stretches to its text, while the rest stays trailing.',
        swift: r'''
// The leading item is not a back button: label plus icon, as wide as its text.
ToolbarItem(placement: .topBarLeading) {
  Button { showLeading() } label: {
    Label("Leading", systemImage: "number")
      .padding(.horizontal, 12)
  }
  .buttonStyle(.glass)
}''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    const GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      label: 'Leading',
      icon: GlassIcon(systemName: 'number', fallback: Icons.tag),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            const GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              label: 'Leading',
              icon: GlassIcon(systemName: 'number', fallback: Icons.tag),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'square.and.arrow.up',
                fallback: Icons.ios_share,
              ),
              help: 'Share',
              onPressed: () => live.watch('share'),
            ),
          ],
        ),
      ),
      _case(
        'Principal · custom title',
        'principal: the title is not text but a piece of glass of its own. Use it instead of title, not alongside it.',
        swift: r'''
// The title is not text but a piece of glass of its own.
ToolbarItem(placement: .principal) {
  Button { pick() } label: {
    Label("Menu ▾", systemImage: "chevron.up.chevron.down")
  }
  .buttonStyle(.glass)
}''',
        dart: r'''
GlassTitleBar(                       // no title: a principal item instead
  items: <GlassTitleElement>[
    const GlassTitleItem(
      placement: GlassTitlePlacement.principal,
      label: 'Menu ▾',
      icon: GlassIcon(
        systemName: 'chevron.up.chevron.down',
        fallback: Icons.unfold_more,
      ),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            const GlassTitleItem(
              placement: GlassTitlePlacement.principal,
              label: 'Menu ▾',
              icon: GlassIcon(
                systemName: 'chevron.up.chevron.down',
                fallback: Icons.unfold_more,
              ),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'ellipsis.circle',
                fallback: Icons.more_horiz,
              ),
              onPressed: () => live.watch('more'),
            ),
          ],
        ),
      ),
      _case(
        'Selected and badge',
        'selected is the current state (the glass fills); badge is a small "not seen yet" dot in the top-right corner.\n'
            'Two items form one group (GlassTitleGroup / ToolbarItemGroup): one shared piece of glass, 2 points apart.',
        swift: r'''
// These two share one piece of glass, 2 points apart.
ToolbarItemGroup {
  Button { sort() } label: { Image(systemName: "square.grid.3x3") }
    .badge(1)                             // the selected glass fills in
  Button { bell() } label: { Image(systemName: "bell") }
    .badge(1)                             // the "not seen yet" dot
}''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
    // These two share one piece of glass, `gap` apart.
    GlassTitleGroup(
      gap: 2,
      items: <GlassTitleItem>[
        GlassTitleItem(
          icon: const GlassIcon(
            systemName: 'square.grid.3x3',
            fallback: Icons.grid_view,
          ),
          help: 'Sort',
          selected: live.tab == 0,
          onPressed: () => live.setTab(0),
        ),
        GlassTitleItem(
          icon: const GlassIcon(
            systemName: 'bell',
            fallback: Icons.notifications_none,
          ),
          badge: true,
          onPressed: () => live.watch('notifications'),
        ),
      ],
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'square.grid.3x3',
                fallback: Icons.grid_view,
              ),
              help: 'Sort',
              selected: live.tab == 0,
              onPressed: () => live.setTab(0),
            ),
            GlassTitleGroup(
              gap: 2,
              items: <GlassTitleItem>[
                GlassTitleItem(
                  icon: const GlassIcon(
                    systemName: 'list.bullet',
                    fallback: Icons.format_list_bulleted,
                  ),
                  help: 'Sort',
                  selected: live.tab == 1,
                  onPressed: () => live.setTab(1),
                ),
                GlassTitleItem(
                  icon: const GlassIcon(
                    systemName: 'bell',
                    fallback: Icons.notifications_none,
                  ),
                  badge: true,
                  onPressed: () => live.watch('notifications'),
                ),
              ],
            ),
            const GlassTitleItem(
              icon: GlassIcon(systemName: 'clock', fallback: Icons.schedule),
            ),
          ],
        ),
      ),
      _case(
        'Large title',
        'displayMode.large: the title grows and moves to the leading edge, with the subtitle on the line above it. Actions stay at the ends.',
        swift: r'''
VStack(alignment: .leading, spacing: 0) {
  Text("Subtitle").font(.system(size: 15, weight: .medium))
  // the title grows at the leading edge, the subtitle is the line above
  Text("Title").font(.largeTitle.bold())
}''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  subtitle: 'Subtitle',
  displayMode: GlassTitleDisplayMode.large,
  height: 148,
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          subtitle: 'Subtitle',
          displayMode: GlassTitleDisplayMode.large,
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'magnifyingglass',
                fallback: Icons.search,
              ),
              onPressed: () => live.watch('search'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'ellipsis.circle',
                fallback: Icons.more_horiz,
              ),
              onPressed: () => live.watch('more'),
            ),
          ],
          height: 148,
        ),
      ),
      _case(
        'Large title over photo',
        'largeTitleColor set to white: a large title over a photo turns white.',
        swift: r'''
VStack(alignment: .leading, spacing: 0) {
  Text("Subtitle").foregroundStyle(.white.opacity(0.75))
  Text("Title").font(.largeTitle.bold())
    .foregroundStyle(.white)              // over a photo: turns white
}''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  subtitle: 'Subtitle',
  displayMode: GlassTitleDisplayMode.large,
  largeTitleColor: Colors.white,
  height: 148,
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          subtitle: 'Subtitle',
          displayMode: GlassTitleDisplayMode.large,
          largeTitleColor: Colors.white,
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'square.and.arrow.up',
                fallback: Icons.ios_share,
              ),
              onPressed: () => live.watch('share'),
            ),
          ],
          height: 148,
        ),
      ),
      _case(
        'Search',
        'searching is owned by the caller: put the search item in items and raise it on press — the centre becomes a field and the trailing end becomes Cancel.',
        swift: r'''
@State private var searching = false      // the caller owns this state

Button { searching = true } label: {
  Image(systemName: "magnifyingglass")
}
  .buttonStyle(.glass)   // once pressed: the centre becomes a field, the trailing end Cancel''',
        dart: r'''
GlassTitleBar(
  title: 'Title',
  searching: live.searching,
  searchPrompt: 'Search',
  onSearchCancel: () => live.setSearching(false),
  items: <GlassTitleElement>[
    GlassTitleItem(
      icon: const GlassIcon(
        systemName: 'magnifyingglass',
        fallback: Icons.search,
      ),
      onPressed: () => live.setSearching(true),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          searching: live.searching,
          searchPrompt: 'Search',
          onSearchChanged: live.watch,
          onSearchSubmitted: (String text) => live.watch('submitted $text'),
          onSearchCancel: () => live.setSearching(false),
          items: <GlassTitleElement>[
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'magnifyingglass',
                fallback: Icons.search,
              ),
              onPressed: () => live.setSearching(true),
            ),
          ],
        ),
      ),
      _case(
        'Receding',
        'visualWeight 0.35: the whole bar recedes and the text fades with it. Tap the trailing item to switch back.',
        swift: r'''
titleBar
  .opacity(0.55 + 0.45 * 0.35)            // the receded step, text fades too
  .allowsHitTesting(true)''',
        dart: r'''
GlassTitleBar(
  visualWeight: live.weight,              // 0.35
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
    GlassTitleItem(
      icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
      onPressed: () => live.toggleWeight(),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          visualWeight: live.weight,
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: live.toggleWeight,
            ),
          ],
        ),
      ),
      _case(
        'Not hittable',
        'allowsHitTesting: false: no press is accepted, and the look recedes one step.',
        swift: r'''
titleBar
  .allowsHitTesting(false)                // no press is accepted
  .glassEffect(.regular.interactive(false), in: .capsule)''',
        dart: r'''
GlassTitleBar(
  allowsHitTesting: false,
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          allowsHitTesting: false,
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: () => live.watch('add'),
            ),
          ],
        ),
      ),
      _case(
        'No title',
        'The title is optional: only the two ends remain, and the centre stays empty.',
        swift: r'''
ToolbarItem(placement: .topBarLeading) {
  Button { openSidebar() } label: { Image(systemName: "sidebar.left") }
    .buttonStyle(.glass)
}
ToolbarItem(placement: .topBarTrailing) {
  Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
    .buttonStyle(.glass)
}                                         // no title: the centre stays empty''',
        dart: r'''
GlassTitleBar(                       // no title
  items: <GlassTitleElement>[
    // One item at each end.
    GlassTitleItem(
      icon: const GlassIcon(
        systemName: 'sidebar.left',
        fallback: Icons.menu,
      ),
      onPressed: () => live.watch('sidebar'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          items: <GlassTitleElement>[
            GlassTitleItem(
              icon: const GlassIcon(
                  systemName: 'sidebar.left', fallback: Icons.menu),
              onPressed: () => live.watch('sidebar'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(
                systemName: 'arrow.clockwise',
                fallback: Icons.refresh,
              ),
              onPressed: () => live.watch('refresh'),
            ),
          ],
        ),
      ),
      _case(
        'Spacing and height',
        'spacing 16, height 44: both the gap between items and the size of an item are adjustable.',
        swift: r'''
titleBar
  .toolbarSpacing(16)                     // the gap between items
  .frame(height: 44)                      // the size of an item''',
        dart: r'''
GlassTitleBar(
  height: 44,
  spacing: 16,
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          height: 44,
          spacing: 16,
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: () => live.watch('add'),
            ),
          ],
        ),
        barHeight: 44,
      ),
      _case(
        'On white',
        'surface: light — glass and text both have to hold up on a bright backdrop.',
        swift: r'''
ZStack {
  Color.white                             // glass and text have to hold up here
  titleBar
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on white.
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              label: 'Selected',
              selected: true,
              onPressed: () => live.watch('selected'),
            ),
          ],
        ),
        surface: CaseSurface.light,
      ),
      _case(
        'On dark',
        'surface: dark — the glass edges and the text weight over a dark backdrop.',
        swift: r'''
ZStack {
  // the glass edges and the text weight over a dark backdrop
  Color(red: 0.08, green: 0.09, blue: 0.10)
  titleBar
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on dark.
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: () => live.watch('add'),
            ),
          ],
        ),
        surface: CaseSurface.dark,
      ),
      _case(
        'On light grey',
        'surface: plain — the light grey of a page background.',
        swift: r'''
ZStack {
  Color(white: 0.95)                      // the light grey of a page background
  titleBar
}''',
        dart: r'''
// The gallery paints the backdrop: this case sits on light grey.
GlassTitleBar(
  title: 'Title',
  items: <GlassTitleElement>[
    GlassTitleItem(
      placement: GlassTitlePlacement.topBarLeading,
      icon: const GlassIcon(
        systemName: 'chevron.backward',
        fallback: Icons.arrow_back_ios_new,
      ),
      help: 'Back',
      onPressed: () => live.watch('back'),
    ),
  ],
)''',
        (Live live) => GlassTitleBar(
          title: 'Title',
          items: <GlassTitleElement>[
            GlassTitleItem(
              placement: GlassTitlePlacement.topBarLeading,
              icon: const GlassIcon(
                systemName: 'chevron.backward',
                fallback: Icons.arrow_back_ios_new,
              ),
              help: 'Back',
              onPressed: () => live.watch('back'),
            ),
            GlassTitleItem(
              icon: const GlassIcon(systemName: 'plus', fallback: Icons.add),
              onPressed: () => live.watch('add'),
            ),
          ],
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
  double height = 116,
  double barHeight = 37,
}) =>
    GlassCase(
      title: title,
      hint: hint,
      height: height,
      atTop: true,
      barHeight: barHeight,
      surface: surface,
      swift: swift,
      dart: dart,
      build: build,
    );
