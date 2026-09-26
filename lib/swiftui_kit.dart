/// Native SwiftUI glass bars for Flutter.
///
/// Two floating glass surfaces are provided:
///
/// - [GlassCapsuleBar], a capsule bar intended to sit at the bottom of a page.
/// - [GlassTitleBar], a bar intended to sit at the top of a page.
///
/// On iOS and macOS both are drawn by SwiftUI inside platform views, so the
/// glass is the system's own (`.glassEffect` on iOS/macOS 26 and later, falling
/// back to a blur plus a rim below that). On every other platform they are
/// drawn in Flutter instead.
///
/// Both renderers consume the same spec: the same geometry, colours and
/// callbacks, pushed down to the native side and read directly by the Flutter
/// one. Switching renderers therefore does not move or recolour the glass, and
/// both report the same events.
library;

export 'src/glass_capsule_bar.dart';
export 'src/glass_icon.dart';
export 'src/glass_renderer.dart';
export 'src/glass_title_bar.dart';
