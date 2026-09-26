// Floating capsule bar drawn on system glass, mirroring `ui.CapsuleBar`: 3pt inner inset,
// glyphs and fonts scaled with height. With a right capsule (search or trailing item) the
// two sit at opposite edges; without one the items capsule centers.

import SwiftUI

/// One item in the capsule.
struct CapsuleItemSpec {
  let label: String
  let symbol: String?
  let tooltip: String?

  init(_ raw: [String: Any]) {
    label = GlassSpec.string(raw["label"]) ?? ""
    symbol = GlassSpec.string(raw["symbol"])
    tooltip = GlassSpec.string(raw["tooltip"])
  }
}

/// Spec of the capsule bar.
struct CapsuleBarSpec {
  let height: CGFloat
  let visualWeight: Double
  let interactive: Bool
  let items: [CapsuleItemSpec]
  let selectedIndex: Int?
  let searchEnabled: Bool
  let searching: Bool
  let searchText: String?
  let spacing: CGFloat
  let searchHint: String
  let searchCancel: String
  let trailing: CapsuleItemSpec?
  let palette: GlassPalette
  let metrics: GlassMetrics

  init(_ raw: [String: Any]) {
    height = GlassSpec.float(raw["height"], 62)
    visualWeight = GlassSpec.double(raw["visualWeight"], 1)
    interactive = GlassSpec.bool(raw["interactive"], true)
    items = GlassSpec.tables(raw["items"]).map(CapsuleItemSpec.init)
    selectedIndex = GlassSpec.int(raw["selectedIndex"])
    searchEnabled = GlassSpec.bool(raw["searchEnabled"], false)
    searching = GlassSpec.bool(raw["searching"], false)
    searchText = GlassSpec.string(raw["searchText"])
    spacing = GlassSpec.float(raw["spacing"], 12)
    searchHint = GlassSpec.string(raw["searchHint"]) ?? "Search"
    searchCancel = GlassSpec.string(raw["searchCancel"]) ?? "Cancel"
    trailing = GlassSpec.table(raw["trailing"]).map(CapsuleItemSpec.init)
    palette = GlassPalette(GlassSpec.table(raw["palette"]) ?? [:])
    metrics = GlassMetrics(GlassSpec.table(raw["metrics"]))
  }
}

/// Native-side state.
///
/// Search state is owned by the caller, as in `ui.CapsuleBar`: the `searching` flag from
/// Dart only switches which shape is shown. Only the typed text lives on this side.
final class CapsuleBarModel: GlassModel {
  @Published var spec: CapsuleBarSpec
  @Published var searchText = ""
  var send: (GlassOutgoing) -> Void = { _ in }

  /// Last text received from Dart. Distinguishes a caller edit from an echo of our own
  /// reported event.
  private var lastIncomingText: String?

  var isDark: Bool { spec.palette.isDark }

  init(_ spec: CapsuleBarSpec) {
    self.spec = spec
    lastIncomingText = spec.searchText
  }

  /// Replaces the spec with a full spec pushed from Dart.
  func apply(_ next: CapsuleBarSpec) {
    let wasSearching = spec.searching
    spec = next
    if wasSearching && !next.searching {
      // Clear the text when leaving search without reporting it: not a user edit.
      searchText = ""
    }
    if next.searchText != lastIncomingText {
      lastIncomingText = next.searchText
      searchText = next.searchText ?? ""
    }
  }

  /// Reports every keystroke back to Dart.
  func setSearchText(_ text: String) {
    searchText = text
    send(.searchChanged(text))
  }
}

/// Rendering of the capsule bar.
struct CapsuleBarContent: View {
  @ObservedObject var model: CapsuleBarModel
  @FocusState private var searchFocused: Bool

  private var spec: CapsuleBarSpec { model.spec }

  private var metrics: GlassMetrics { spec.metrics }

  /// Height inside the 3pt inset; the selected pill is laid out within it.
  private var innerHeight: CGFloat { metrics.innerHeight(spec.height) }

  /// Fonts and glyphs scale with height, relative to the design baseline height.
  private var scale: CGFloat { metrics.scale(spec.height) }

  private var hasRightSlot: Bool { spec.searchEnabled || spec.trailing != nil }

  private let ease = Animation.spring(response: 0.35, dampingFraction: 0.82)

  var body: some View {
    Group {
      if spec.searching {
        searchCapsule
      } else if hasRightSlot {
        HStack(spacing: spec.spacing) {
          itemsCapsule
          Spacer(minLength: metrics.rightMinGap)
          rightCapsule
        }
      } else {
        HStack(spacing: 0) {
          Spacer(minLength: 0)
          itemsCapsule
          Spacer(minLength: 0)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    // Receded state: fade the whole bar, since Dart already weights the ink color. This
    // is native-only; the fallback fades the ink, measured to land at the same level.
    .opacity(0.55 + 0.45 * min(max(spec.visualWeight, 0), 1))
    .allowsHitTesting(spec.interactive)
    .animation(ease, value: spec.selectedIndex)
    .animation(ease, value: spec.searching)
  }

  private var itemsCapsule: some View {
    HStack(spacing: 0) {
      ForEach(Array(spec.items.indices), id: \.self) { index in
        let item = spec.items[index]
        Button {
          model.send(.itemTap(index))
        } label: {
          itemLabel(item, selected: index == spec.selectedIndex)
            .padding(.horizontal, metrics.itemPad * scale)
            .frame(
              minWidth: spec.height * metrics.itemMinWidthFactor,
              minHeight: innerHeight,
              maxHeight: innerHeight
            )
            // The selected pill is this item's own background; layout supplies its
            // position and width, so no other item's frame is measured.
            .background {
              if index == spec.selectedIndex {
                Capsule()
                  .fill(spec.palette.selectedFill)
                  .transition(.opacity)
              }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassHelp(spec.items[index].tooltip)
      }
    }
    .padding(metrics.inset)
    .frame(height: spec.height)
    .fixedSize(horizontal: true, vertical: false)
    .animation(ease, value: spec.selectedIndex)
    .glassed(Capsule(), interactive: spec.interactive)
  }

  @ViewBuilder
  private var rightCapsule: some View {
    if spec.searchEnabled {
      Button {
        model.send(.searchEnter)
      } label: {
        Image(systemName: "magnifyingglass")
          .font(.system(size: metrics.capsuleIconSize * scale, weight: .medium))
          .foregroundStyle(spec.palette.foreground)
          .frame(width: spec.height, height: spec.height)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .glassed(Capsule(), interactive: spec.interactive)
      .glassHelp(spec.searchHint)
    } else if let trailing = spec.trailing {
      Button {
        model.send(.trailingTap)
      } label: {
        itemLabel(trailing, selected: false)
          .frame(width: spec.height, height: spec.height)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .glassed(Capsule(), interactive: spec.interactive)
      .glassHelp(trailing.tooltip)
    }
  }

  private var searchCapsule: some View {
    HStack(spacing: metrics.searchIconGap) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: metrics.searchIconSize, weight: .regular))
        .foregroundStyle(spec.palette.hint)
      TextField(spec.searchHint, text: searchBinding)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.fontTitle))
        .foregroundStyle(spec.palette.foreground)
        .focused($searchFocused)
        .onSubmit { model.send(.searchSubmitted(model.searchText)) }
      Button {
        model.send(.searchCancel)
      } label: {
        Text(spec.searchCancel)
          .font(.system(size: metrics.fontTitle))
          .foregroundStyle(spec.palette.action)
      }
      .buttonStyle(.plain)
    }
    .padding(.leading, metrics.searchLeadingPad)
    .padding(.trailing, metrics.searchTrailingPad)
    .frame(maxWidth: .infinity, minHeight: spec.height, maxHeight: spec.height)
    .glassed(Capsule(), interactive: spec.interactive)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear { searchFocused = true }
  }

  /// Text field binding. Keystrokes go through the setter, so no `onChange` hook is
  /// needed; that API differs across OS versions.
  private var searchBinding: Binding<String> {
    Binding(
      get: { model.searchText },
      set: { model.setSearchText($0) }
    )
  }

  @ViewBuilder
  private func itemLabel(_ item: CapsuleItemSpec, selected: Bool) -> some View {
    let ink = (selected ? spec.palette.selectedInk : spec.palette.plainInk)
    let weight: Font.Weight = selected ? .semibold : .medium
    if let symbol = item.symbol, !item.label.isEmpty {
      VStack(spacing: metrics.capsuleIconGap * scale) {
        Image(systemName: symbol)
          .font(.system(size: metrics.capsuleIconSize * scale, weight: weight))
        Text(item.label)
          .font(.system(size: metrics.fontCapsuleLabel * scale, weight: weight))
      }
      .foregroundStyle(ink)
    } else if let symbol = item.symbol {
      Image(systemName: symbol)
        .font(.system(size: metrics.capsuleIconSize * scale, weight: weight))
        .foregroundStyle(ink)
    } else {
      Text(item.label)
        .font(.system(size: metrics.fontCapsuleLabelOnly * scale, weight: weight))
        .foregroundStyle(ink)
        .lineLimit(1)
    }
  }
}
