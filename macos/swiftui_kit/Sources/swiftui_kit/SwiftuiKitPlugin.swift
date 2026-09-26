// The macOS entry point: registers the platform views. Everything else is pushed
// from Dart.
//
// The views themselves live in `shared/swiftui_kit/`, which both platforms
// share; only the way the binary messenger is obtained differs here.

import Cocoa
import FlutterMacOS

/// The macOS half of the plugin.
public class SwiftuiKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    GlassViewRegistrar.register(registrar, messenger: registrar.messenger)
  }
}
