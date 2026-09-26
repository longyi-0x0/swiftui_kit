// The pages of the gallery, and the keys and sizes the shell shares with it.

import 'package:flutter/material.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

import 'capsule_cases.dart';
import 'glass_case.dart';
import 'title_cases.dart';

/// One page of the gallery.
class GalleryPage {
  const GalleryPage({
    required this.label,
    required this.icon,
    required this.note,
    required this.cases,
  });

  /// The sidebar label, and the name `--dart-define=only=` matches.
  final String label;

  /// The sidebar icon.
  final GlassIcon icon;

  /// What this page is about; the toolbar shows it after the label.
  final String note;

  /// The cases on this page.
  final List<GlassCase> cases;
}

/// Every page of the gallery, in sidebar order.
final List<GalleryPage> allPages = <GalleryPage>[
  GalleryPage(
    label: 'Capsule',
    icon: const GlassIcon(
      systemName: 'rectangle.bottomhalf.inset.filled',
      fallback: Icons.smart_button_outlined,
    ),
    note: 'The floating capsule at the bottom: items, trailing, search, '
        'receding, not hittable, heights, backdrops.',
    cases: capsuleCases(),
  ),
  GalleryPage(
    label: 'Title',
    icon: const GlassIcon(
      systemName: 'rectangle.tophalf.inset.filled',
      fallback: Icons.web_asset_outlined,
    ),
    note: 'The top bar: inline and large titles, back and custom items, '
        'selection and badges, search, backdrops.',
    cases: titleCases(),
  ),
];

/// The width of one canvas.
///
/// A single value, and wider than 300 because the fallback lane (the package's
/// own capsule bar) overflows its inner row below 300.
const double canvasWidth = 560;

/// Key of the sidebar. Tapping a row inside it needs one, since a page may show
/// the same word.
const Key sidebarKey = ValueKey<String>('swiftui_kit/sidebar');

/// Key of the case list. Scrolling to a case and capturing a whole page both
/// need it.
final GlobalKey listKey = GlobalKey(debugLabel: 'swiftui_kit/list');
