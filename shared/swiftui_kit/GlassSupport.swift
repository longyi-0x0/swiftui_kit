// Shared foundation of the native half: decoding of the spec pushed from Dart
// (`GlassSpec`), color resolution (palettes are computed on the Dart side, so no
// light/dark decisions are made here), and glass rendering (`.glassEffect` plus its
// pre-26 fallback).

import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Base view shared by both platforms.
///
/// Flutter requires a `UIView` on iOS and an `NSView` on macOS. That difference is
/// confined here so the rest of the code stays single-source.
#if canImport(UIKit)
class GlassBaseView: UIView {
  /// The frame Flutter assigns is the whole box for this surface, so the view reports no
  /// safe area of its own: `UIHostingController` would otherwise inset the SwiftUI content
  /// for the part of the frame that overlaps the system's safe area, and a bar with a fixed
  /// height centred in that smaller box would ride up by half the inset.
  override var safeAreaInsets: UIEdgeInsets { .zero }
}
#else
class GlassBaseView: NSView {}
#endif

/// Converts ARGB (Dart's `Color.toARGB32()`) to a SwiftUI color.
extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255
    )
  }
}

/// Spec pushed from Dart.
///
/// Channel and creation arguments alike are `StandardMessageCodec` dictionaries:
/// numbers and colors arrive as `NSNumber`, tables and lists as `NSDictionary` /
/// `NSArray`. Unreadable values fall back to safe defaults, since a missing key must not
/// crash this layer.
enum GlassSpec {
  /// One table. Keys must be `String`; other keys are dropped.
  static func table(_ value: Any?) -> [String: Any]? {
    if let table = value as? [String: Any] { return table }
    if let table = value as? [AnyHashable: Any] {
      var out: [String: Any] = [:]
      for (key, value) in table {
        guard let key = key as? String else { continue }
        out[key] = value
      }
      return out
    }
    return nil
  }

  /// A list of tables.
  static func tables(_ value: Any?) -> [[String: Any]] {
    guard let list = value as? [Any] else { return [] }
    return list.compactMap { table($0) }
  }

  static func number(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue
  }

  static func double(_ value: Any?, _ fallback: Double) -> Double {
    number(value) ?? fallback
  }

  static func float(_ value: Any?, _ fallback: CGFloat) -> CGFloat {
    number(value).map { CGFloat($0) } ?? fallback
  }

  static func int(_ value: Any?) -> Int? {
    (value as? NSNumber)?.intValue
  }

  static func bool(_ value: Any?, _ fallback: Bool) -> Bool {
    (value as? NSNumber)?.boolValue ?? fallback
  }

  static func string(_ value: Any?) -> String? {
    guard let text = value as? String, !text.isEmpty else { return nil }
    return text
  }

  static func color(_ value: Any?) -> Color? {
    guard let value = value as? NSNumber else { return nil }
    return Color(argb: value.uint32Value)
  }
}

/// Ink colors for text and glyphs. Computed on the Dart side (`ui`'s `GlassInk`); no
/// light/dark decisions are made here.
struct GlassPalette {
  let isDark: Bool
  let foreground: Color
  let selectedInk: Color
  let plainInk: Color
  /// Fill behind the selected capsule item: a neutral grey, deeper than the bar's own
  /// glass. It travels as a fill rather than as glass because refraction over a flat
  /// page shifts the tone by single digits, which reads as no selection at all.
  let selectedPlate: Color
  let hint: Color
  let action: Color
  let separator: Color
  /// How much of its alpha the subtitle of a large title keeps.
  let subtitleAlpha: Double

  init(_ raw: [String: Any]) {
    isDark = GlassSpec.bool(raw["isDark"], false)
    let foreground = GlassSpec.color(raw["foreground"]) ?? Color(argb: 0xFF1C1C1E)
    self.foreground = foreground
    selectedInk = GlassSpec.color(raw["selectedInk"]) ?? foreground
    plainInk = GlassSpec.color(raw["plainInk"]) ?? foreground
    selectedPlate = GlassSpec.color(raw["selectedPlate"]) ?? Color.black.opacity(0.12)
    hint = GlassSpec.color(raw["hint"]) ?? Color.white.opacity(0.45)
    action = GlassSpec.color(raw["action"]) ?? Color.white.opacity(0.45)
    separator = GlassSpec.color(raw["separator"]) ?? Color.black.opacity(0.08)
    subtitleAlpha = GlassSpec.double(raw["subtitleAlpha"], 0.75)
  }
}

/// Wire contract with Dart: the two channel methods and the event envelope keys.
///
/// Mirrors the Dart-side `GlassContract` entry by entry. View type names live in
/// `GlassViewRegistrar`.
enum GlassContract {
  /// Dart to native: pushes a full spec.
  static let updateMethod = "update"

  /// Native to Dart: reports one event.
  static let eventMethod = "event"

  /// Event envelope: which event.
  static let keyType = "type"

  /// Event envelope: index of the tapped item.
  static let keyIndex = "index"

  /// Event envelope: search text.
  static let keyText = "text"
}

/// Metrics of this glass. Computed on the Dart side (`ui`'s `GlassMetrics`), so no size
/// is chosen here and both platforms move together when a value changes. A missing key
/// falls back to the measured default.
struct GlassMetrics {
  let inset: CGFloat
  let scaleBase: CGFloat
  let scaleMin: CGFloat
  let scaleMax: CGFloat
  let itemPad: CGFloat
  let itemMinWidthFactor: CGFloat
  let itemSpacing: CGFloat
  let rightMinGap: CGFloat
  let capsuleIconSize: CGFloat
  let capsuleIconGap: CGFloat
  let titleItemIconSize: CGFloat
  let titleItemPad: CGFloat
  let titleItemPadWithIcon: CGFloat
  let titleItemGap: CGFloat
  let badgeSize: CGFloat
  let badgeInset: CGFloat
  let searchLeadingPad: CGFloat
  let searchTrailingPad: CGFloat
  let searchIconSize: CGFloat
  let searchIconGap: CGFloat
  let searchCancelPad: CGFloat
  let fontLargeTitle: CGFloat
  let fontTitle: CGFloat
  let fontSubtitle: CGFloat
  let fontItem: CGFloat
  let fontCapsuleLabel: CGFloat
  let fontCapsuleLabelOnly: CGFloat
  let fontLineHeight: CGFloat

  init(_ raw: [String: Any]?) {
    let raw = raw ?? [:]
    inset = GlassSpec.float(raw["capsuleInset"], 3)
    scaleBase = GlassSpec.float(raw["capsuleScaleBase"], 52)
    scaleMin = GlassSpec.float(raw["capsuleScaleMin"], 0.9)
    scaleMax = GlassSpec.float(raw["capsuleScaleMax"], 1.4)
    itemPad = GlassSpec.float(raw["capsuleItemPadNative"], 22)
    itemMinWidthFactor = GlassSpec.float(raw["capsuleItemMinWidthFactor"], 1.2)
    itemSpacing = GlassSpec.float(raw["capsuleItemSpacing"], 2)
    rightMinGap = GlassSpec.float(raw["capsuleRightMinGap"], 8)
    capsuleIconSize = GlassSpec.float(raw["capsuleIconSize"], 22)
    capsuleIconGap = GlassSpec.float(raw["capsuleIconGap"], 1)
    titleItemIconSize = GlassSpec.float(raw["titleItemIconSize"], 18)
    titleItemPad = GlassSpec.float(raw["titleItemPad"], 14)
    titleItemPadWithIcon = GlassSpec.float(raw["titleItemPadWithIcon"], 12)
    titleItemGap = GlassSpec.float(raw["titleItemGap"], 6)
    badgeSize = GlassSpec.float(raw["badgeSize"], 8)
    badgeInset = GlassSpec.float(raw["badgeInset"], 3)
    searchLeadingPad = GlassSpec.float(raw["searchLeadingPad"], 16)
    searchTrailingPad = GlassSpec.float(raw["searchTrailingPad"], 14)
    searchIconSize = GlassSpec.float(raw["searchIconSize"], 22)
    searchIconGap = GlassSpec.float(raw["searchIconGap"], 8)
    searchCancelPad = GlassSpec.float(raw["searchCancelPad"], 14)
    fontLargeTitle = GlassSpec.float(raw["fontLargeTitle"], 34)
    fontTitle = GlassSpec.float(raw["fontTitle"], 17)
    fontSubtitle = GlassSpec.float(raw["fontSubtitle"], 15)
    fontItem = GlassSpec.float(raw["fontItem"], 17)
    fontCapsuleLabel = GlassSpec.float(raw["fontCapsuleLabel"], 10)
    fontCapsuleLabelOnly = GlassSpec.float(raw["fontCapsuleLabelOnly"], 13)
    fontLineHeight = GlassSpec.float(raw["fontLineHeight"], 1)
  }

  /// Fonts and glyphs scale with height, relative to [scaleBase] and clamped between
  /// [scaleMin] and [scaleMax].
  func scale(_ height: CGFloat) -> CGFloat {
    min(max(height / scaleBase, scaleMin), scaleMax)
  }

  /// Height left inside the inset; the selected pill is laid out within it.
  func innerHeight(_ height: CGFloat) -> CGFloat {
    max(height - inset * 2, 1)
  }
}

/// Glass surface.
///
/// On 26 and later this defers to the system `.glassEffect`, which supplies refraction,
/// specular highlights and content-adaptive brightening, and follows the system look.
/// Below 26 it falls back to a blurred material with a stroke; shape and metrics are
/// unchanged.
struct GlassSurface<S: Shape>: ViewModifier {
  let shape: S
  let interactive: Bool
  let tint: Color?

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      content.glassEffect(systemGlass, in: shape)
    } else {
      content
        .background {
          ZStack {
            shape.fill(.ultraThinMaterial)
            if let tint {
              shape.fill(tint.opacity(0.55))
            }
          }
        }
        .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  private var systemGlass: Glass {
    var glass = Glass.regular
    if let tint {
      glass = glass.tint(tint)
    }
    return interactive ? glass.interactive() : glass
  }
}

extension View {
  /// Draws this view as glass in [shape]. A non-nil [tint] colors it (used by a
  /// selected title bar item).
  func glassed<S: Shape>(_ shape: S, interactive: Bool, tint: Color? = nil) -> some View {
    modifier(GlassSurface(shape: shape, interactive: interactive, tint: tint))
  }

  /// Tooltip shown on pointer hover. macOS only.
  @ViewBuilder func glassHelp(_ text: String?) -> some View {
    #if os(macOS)
    if let text {
      self.help(text)
    } else {
      self
    }
    #else
    self
    #endif
  }
}

/// One event sent back to Dart. On the wire it is a table carrying `type`; names match
/// the `wire` values of the Dart-side `GlassEventType` exactly.
enum GlassOutgoing {
  case itemTap(Int)
  case trailingTap
  case searchEnter
  case searchChanged(String)
  case searchSubmitted(String)
  case searchCancel

  var payload: [String: Any] {
    switch self {
    case .itemTap(let index):
      return [
        GlassContract.keyType: "itemTap",
        GlassContract.keyIndex: index,
      ]
    case .trailingTap:
      return [GlassContract.keyType: "trailingTap"]
    case .searchEnter:
      return [GlassContract.keyType: "searchEnter"]
    case .searchChanged(let text):
      return [GlassContract.keyType: "searchChanged", GlassContract.keyText: text]
    case .searchSubmitted(let text):
      return [GlassContract.keyType: "searchSubmitted", GlassContract.keyText: text]
    case .searchCancel:
      return [GlassContract.keyType: "searchCancel"]
    }
  }
}

/// Base for native-side state: holds a spec and can report events back.
///
/// The SwiftUI content holds it via `@ObservedObject`; the hosting view swaps in the spec
/// pushed from Dart and wires `send` to the channel.
protocol GlassModel: ObservableObject {
  /// Reports one event back to Dart. Wired up by the hosting view.
  var send: (GlassOutgoing) -> Void { get set }

  /// Light/dark mode requested by the caller (the Flutter theme).
  ///
  /// The glass itself follows the *system* appearance, while ink colors are computed by
  /// Dart from the Flutter theme. Unaligned, a dark system pairs dark glass with dark
  /// ink, and a light system the inverse. The hosting view applies this value to the
  /// view's appearance.
  var isDark: Bool { get }
}
