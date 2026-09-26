// One shape of the glass, plus the per-case state it is shown with.

import 'package:flutter/widgets.dart';
import 'package:swiftui_kit/swiftui_kit.dart';

/// What sits behind the glass.
enum CaseSurface {
  /// A photo. Refraction, blur and text contrast only show when there is
  /// something behind the glass to look through.
  photo,

  /// The light grey of a page background.
  plain,

  /// Pure white. Whether the glass still reads over a bright backdrop.
  light,

  /// Dark.
  dark,
}

/// One shape of the glass.
///
/// A case is pure data: the name, one line about it, the backdrop, which end of
/// the canvas the glass hugs, how tall the canvas is, the glass itself, and the
/// two code samples for this shape — the SwiftUI lines and the Dart lines. The
/// view layer lays each case out as two lanes with those samples underneath. The
/// state a case needs (selected index, whether search is open) lives in [Live],
/// so tapping one case only moves that case.
@immutable
class GlassCase {
  const GlassCase({
    required this.title,
    required this.hint,
    required this.height,
    required this.atTop,
    required this.build,
    required this.swift,
    required this.dart,
    this.surface = CaseSurface.photo,
    this.barHeight = 62,
  });

  /// The name of the case.
  final String title;

  /// One line about what this case shows.
  final String hint;

  /// The height of one canvas (each lane gets its own). Padding the glass
  /// carries itself is not part of it.
  final double height;

  /// Whether the glass hugs the top of the canvas (a title bar) or the bottom
  /// (a capsule).
  final bool atTop;

  /// The backdrop.
  final CaseSurface surface;

  /// How tall the glass itself is, without padding. The capture server uses it
  /// to work out the glass rectangle when comparing the two lanes.
  final double barHeight;

  /// How this shape is written in SwiftUI. Only the lines this case is about;
  /// the shared boilerplate is not repeated.
  final String swift;

  /// How this shape is written with this package: the lines a caller writes in
  /// Dart.
  final String dart;

  /// The glass. Both lanes are given the same [live], so both show the same
  /// moment.
  ///
  /// Which renderer draws it is decided by the enclosing `GlassRendererScope`,
  /// not here.
  final Widget Function(Live live) build;
}

/// The state one case owns.
///
/// Cases are independent: selection and the like belong to the case, so tapping
/// one only moves that case. Both lanes of a case share this object, so the two
/// always show the same moment.
class Live extends ChangeNotifier {
  /// The selected index.
  int tab = 0;

  /// The visual weight. The receding cases toggle it.
  double weight = 1;

  /// Whether search is open.
  bool searching = false;

  /// What was tapped last; the case headline appends it.
  String last = '';

  void setTab(int value) {
    tab = value;
    notifyListeners();
  }

  void toggleWeight() {
    weight = weight == 1 ? 0.35 : 1;
    notifyListeners();
  }

  void setSearching(bool value) {
    searching = value;
    notifyListeners();
  }

  void watch(String what) {
    last = what;
    notifyListeners();
  }
}

/// Records which capsule item was tapped, so the case headline can show it.
extension CaseTabRecording on Live {
  /// Taps item [index]: move the selection and record that item's label.
  void Function(int) recordTab(List<GlassCapsuleItem> items) => (int index) {
        setTab(index);
        if (index >= 0 && index < items.length) {
          watch(
              items[index].label.isEmpty ? 'item $index' : items[index].label);
        }
      };
}
