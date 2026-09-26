// The iOS entry point: registers the platform views. Everything else is pushed
// from Dart.
//
// The views themselves live in `shared/swiftui_kit/`, which both platforms
// share; only the way the binary messenger is obtained differs here.

import Flutter
import UIKit

/// The iOS half of the plugin.
public class SwiftuiKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    GlassViewRegistrar.register(registrar, messenger: registrar.messenger())
  }
}
