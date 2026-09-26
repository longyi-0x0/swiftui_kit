// Platform view for one glass surface: hosts SwiftUI content, receives specs pushed from
// Dart, and sends events back.

import SwiftUI

#if canImport(UIKit)
import Flutter
#else
import FlutterMacOS
#endif

/// One glass surface.
///
/// After creation Dart keeps pushing full specs through `update`: no deltas are accepted,
/// each push replaces the whole spec. The view itself is never rebuilt, since search
/// state, keyboard focus and in-flight transitions live inside it (search state in the
/// content view).
final class GlassView<Model: GlassModel, Content: View>: GlassBaseView {
  let model: Model

  private let channel: FlutterMethodChannel
  private let apply: (Model, [String: Any]) -> Void
  /// Retains the SwiftUI hosting layer: the controller on iOS, the hosting view on macOS.
  private var hostingOwner: AnyObject?

  init(
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    model: Model,
    apply: @escaping (Model, [String: Any]) -> Void,
    @ViewBuilder content: (Model) -> Content
  ) {
    self.model = model
    self.apply = apply
    channel = FlutterMethodChannel(
      name: "swiftui_kit/view/\(viewId)",
      binaryMessenger: messenger
    )
    super.init(frame: .zero)

    attach(content(model))
    applyAppearance()

    model.send = { [weak self] event in
      self?.channel.invokeMethod(GlassContract.eventMethod, arguments: event.payload)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case GlassContract.updateMethod:
        if let raw = GlassSpec.table(call.arguments) {
          self.apply(self.model, raw)
          self.applyAppearance()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Pins the view's appearance to the caller's mode, which is what the system glass
  /// reads.
  private func applyAppearance() {
    #if canImport(UIKit)
    overrideUserInterfaceStyle = model.isDark ? .dark : .light
    #else
    appearance = NSAppearance(named: model.isDark ? .darkAqua : .aqua)
    #endif
  }

  private func attach(_ content: Content) {
    #if canImport(UIKit)
    backgroundColor = .clear
    isOpaque = false
    let controller = UIHostingController(rootView: content)
    controller.view.backgroundColor = .clear
    controller.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(controller.view)
    pin(controller.view)
    hostingOwner = controller
    #else
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    let hosted = NSHostingView(rootView: content)
    hosted.translatesAutoresizingMaskIntoConstraints = false
    // Keep SwiftUI's intrinsic size from fighting the frame Flutter assigns.
    hosted.setContentHuggingPriority(.defaultLow, for: .horizontal)
    hosted.setContentHuggingPriority(.defaultLow, for: .vertical)
    hosted.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    hosted.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    addSubview(hosted)
    pin(hosted)
    hostingOwner = hosted
    #endif
  }

  #if canImport(UIKit)
  private func pin(_ view: UIView) {
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: leadingAnchor),
      view.trailingAnchor.constraint(equalTo: trailingAnchor),
      view.topAnchor.constraint(equalTo: topAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
  #else
  private func pin(_ view: NSView) {
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: leadingAnchor),
      view.trailingAnchor.constraint(equalTo: trailingAnchor),
      view.topAnchor.constraint(equalTo: topAnchor),
      view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
  #endif
}

#if canImport(UIKit)
/// On iOS the platform view is an `@objc` protocol, which a generic class cannot
/// conform to. This non-generic wrapper hands out the inner view.
final class GlassPlatformViewHolder: NSObject, FlutterPlatformView {
  private let hosted: GlassBaseView

  init(_ hosted: GlassBaseView) {
    self.hosted = hosted
    super.init()
  }

  func view() -> UIView {
    hosted
  }
}
#endif

/// Registers both view types.
///
/// Names match the Dart-side `GlassContract` exactly; the platform view type name is the
/// only agreement between the two sides.
enum GlassViewRegistrar {
  static let capsuleBarViewType = "swiftui_kit/capsule_bar"
  static let titleBarViewType = "swiftui_kit/title_bar"

  static func register(
    _ registrar: FlutterPluginRegistrar,
    messenger: FlutterBinaryMessenger
  ) {
    registrar.register(
      CapsuleBarFactory(messenger: messenger),
      withId: capsuleBarViewType
    )
    registrar.register(
      TitleBarFactory(messenger: messenger),
      withId: titleBarViewType
    )
  }
}

/// Factory for the capsule bar.
final class CapsuleBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  #if canImport(UIKit)
  // On iOS both `createArgsCodec` and `create` are required: a non-optional codec and a
  // wrapped platform view. On macOS the former is optional, the latter returns `NSView`.
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassPlatformViewHolder(make(viewId: viewId, args: args))
  }
  #else
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    make(viewId: viewId, args: args)
  }
  #endif

  private func make(viewId: Int64, args: Any?) -> GlassView<CapsuleBarModel, CapsuleBarContent> {
    GlassView(
      viewId: viewId,
      messenger: messenger,
      model: CapsuleBarModel(CapsuleBarSpec(GlassSpec.table(args) ?? [:])),
      apply: { model, raw in model.apply(CapsuleBarSpec(raw)) }
    ) { model in
      CapsuleBarContent(model: model)
    }
  }
}

/// Factory for the title bar.
final class TitleBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  #if canImport(UIKit)
  // On iOS both `createArgsCodec` and `create` are required: a non-optional codec and a
  // wrapped platform view. On macOS the former is optional, the latter returns `NSView`.
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassPlatformViewHolder(make(viewId: viewId, args: args))
  }
  #else
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    make(viewId: viewId, args: args)
  }
  #endif

  private func make(viewId: Int64, args: Any?) -> GlassView<TitleBarModel, TitleBarContent> {
    GlassView(
      viewId: viewId,
      messenger: messenger,
      model: TitleBarModel(TitleBarSpec(GlassSpec.table(args) ?? [:])),
      apply: { model, raw in model.apply(TitleBarSpec(raw)) }
    ) { model in
      TitleBarContent(model: model)
    }
  }
}
