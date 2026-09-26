// What the capture code needs from the running gallery.

import 'package:flutter/material.dart';

import 'glass_case.dart';

/// The gallery, as the capture code sees it.
///
/// The gallery hands out its current moment: how many pages there are, which
/// one is showing, the appearance, the case list's scroll position and the box
/// around it. Capture only uses these — switching page, switching appearance
/// and scrolling all go through here, and the images are taken the same way, so
/// a capture sees the same moment as the copy button in the toolbar.
abstract class GalleryStage {
  /// How many pages there are, and their names.
  List<String> get pageLabels;

  /// The cases on each page, in page order.
  List<List<GlassCase>> get allCases;

  /// Which page is showing.
  int get page;

  /// Switches to a page.
  void showPage(int index);

  /// The appearance.
  bool get dark;
  set dark(bool value);

  /// The case list's scroll position.
  ScrollController get scroll;

  /// The box around the case list.
  GlobalKey get viewportKey;

  /// The page background colour, used to fill gaps when stitching a whole page.
  Color get background;
}
