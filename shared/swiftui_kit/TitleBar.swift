// Floating title bar drawn on system glass, laid out like a SwiftUI toolbar: each action
// gets its own glass capsule and the title is plain text over the page, with content
// scrolling underneath. Mirrors `ui.GlassTopBar`; ink and fill colors come from Dart.

import SwiftUI

/// Where an item sits in the bar.
enum TitlePlacement {
  case leading
  case principal
  case trailing

  init(_ raw: String?) {
    switch raw {
    case "leading": self = .leading
    case "principal": self = .principal
    default: self = .trailing
    }
  }
}

/// One item in the bar.
struct TitleItemSpec {
  let placement: TitlePlacement
  let label: String?
  let symbol: String?
  let pressable: Bool
  let tooltip: String?
  let dot: Bool
  let dotColor: Color
  let selected: Bool
  /// Ink color for text and glyphs, computed by Dart for the selected state.
  let ink: Color
  /// Glass tint when selected; nil when not selected.
  let tint: Color?
  /// Items sharing one glass capsule (`ToolbarItemGroup`). Empty for a plain item.
  let members: [TitleItemSpec]
  /// Spacing between entries in [members].
  let gap: CGFloat

  init(_ raw: [String: Any], fallbackInk: Color) {
    placement = TitlePlacement(GlassSpec.string(raw["placement"]))
    label = GlassSpec.string(raw["label"])
    symbol = GlassSpec.string(raw["symbol"])
    pressable = GlassSpec.bool(raw["pressable"], false)
    tooltip = GlassSpec.string(raw["tooltip"])
    dot = GlassSpec.bool(raw["dot"], false)
    dotColor = GlassSpec.color(raw["dotColor"]) ?? .red
    selected = GlassSpec.bool(raw["selected"], false)
    ink = GlassSpec.color(raw["ink"]) ?? fallbackInk
    tint = GlassSpec.color(raw["tint"])
    members = GlassSpec.tables(raw["group"]).map {
      TitleItemSpec($0, fallbackInk: fallbackInk)
    }
    gap = GlassSpec.float(raw["gap"], 2)
  }
}

/// Spec of the title bar.
struct TitleBarSpec {
  let title: String?
  let subtitle: String?
  let large: Bool
  let largeTitleColor: Color?
  let items: [TitleItemSpec]
  let searching: Bool
  let searchText: String?
  let searchHint: String
  let searchCancel: String
  let height: CGFloat
  let spacing: CGFloat
  let visualWeight: Double
  let interactive: Bool
  let palette: GlassPalette
  let metrics: GlassMetrics

  init(_ raw: [String: Any]) {
    title = GlassSpec.string(raw["title"])
    subtitle = GlassSpec.string(raw["subtitle"])
    large = GlassSpec.string(raw["displayMode"]) == "large"
    largeTitleColor = GlassSpec.color(raw["largeTitleColor"])
    searching = GlassSpec.bool(raw["searching"], false)
    searchText = GlassSpec.string(raw["searchText"])
    searchHint = GlassSpec.string(raw["searchHint"]) ?? "Search"
    searchCancel = GlassSpec.string(raw["searchCancel"]) ?? "Cancel"
    height = GlassSpec.float(raw["height"], 37)
    spacing = GlassSpec.float(raw["spacing"], 6)
    visualWeight = GlassSpec.double(raw["visualWeight"], 1)
    interactive = GlassSpec.bool(raw["interactive"], true)
    metrics = GlassMetrics(GlassSpec.table(raw["metrics"]))
    let palette = GlassPalette(GlassSpec.table(raw["palette"]) ?? [:])
    self.palette = palette
    items = GlassSpec.tables(raw["items"]).map {
      TitleItemSpec($0, fallbackInk: palette.foreground)
    }
  }

  /// The principal item (a custom title). When present it is the title, otherwise
  /// [title] is used.
  var principal: (index: Int, item: TitleItemSpec)? {
    for index in items.indices where items[index].placement == .principal {
      return (index, items[index])
    }
    return nil
  }
}

/// Native-side state.
///
/// Search state is owned by the caller, as in `ui.GlassTopBar`: the `searching` flag from
/// Dart only switches which shape is shown. Only the typed text lives on this side.
final class TitleBarModel: GlassModel {
  @Published var spec: TitleBarSpec
  @Published var searchText = ""
  var send: (GlassOutgoing) -> Void = { _ in }

  /// Last text received from Dart. Distinguishes a caller edit from an echo of our own
  /// reported event.
  private var lastIncomingText: String?

  var isDark: Bool { spec.palette.isDark }

  init(_ spec: TitleBarSpec) {
    self.spec = spec
    lastIncomingText = spec.searchText
  }

  /// Replaces the spec with a full spec pushed from Dart.
  func apply(_ next: TitleBarSpec) {
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

  func setSearchText(_ text: String) {
    searchText = text
    send(.searchChanged(text))
  }
}

/// Rendering of the title bar.
struct TitleBarContent: View {
  @ObservedObject var model: TitleBarModel
  @FocusState private var searchFocused: Bool

  private var spec: TitleBarSpec { model.spec }
  private var metrics: GlassMetrics { spec.metrics }

  private let ease = Animation.spring(response: 0.35, dampingFraction: 0.82)

  var body: some View {
    Group {
      if spec.large {
        largeRow
      } else {
        inlineRow
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // Receded state: fade the whole bar, since Dart already weights the ink color. This
    // is native-only; the fallback fades the ink, measured to land at the same level.
    .opacity(0.55 + 0.45 * min(max(spec.visualWeight, 0), 1))
    .allowsHitTesting(spec.interactive)
    .animation(ease, value: spec.searching)
  }

  /// Inline state: the title floats in the center, actions split at the two ends.
  @ViewBuilder
  private var inlineRow: some View {
    if spec.searching {
      HStack(spacing: spec.spacing) {
        leadingItems
        searchField
        cancelButton
      }
      .frame(height: spec.height)
    } else {
      ZStack {
        HStack(spacing: spec.spacing) {
          leadingItems
          Spacer(minLength: 0)
          trailingItems
        }
        titleLabel(large: false)
          .padding(.horizontal, spec.height + spec.spacing)
      }
      .frame(height: spec.height)
    }
  }

  /// Large-title state: the title is enlarged and leading-aligned, actions still split at
  /// the two ends.
  private var largeRow: some View {
    HStack(alignment: .top, spacing: spec.spacing) {
      leadingItems
      VStack(alignment: .leading, spacing: 0) {
        if let subtitle = spec.subtitle {
          Text(subtitle)
            .font(.system(size: metrics.fontSubtitle, weight: .medium))
            .foregroundStyle(subtitleColor)
            .lineLimit(1)
        }
        titleLabel(large: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailingItems
    }
  }

  private var subtitleColor: Color {
    (spec.largeTitleColor ?? spec.palette.foreground)
      .opacity(spec.palette.subtitleAlpha)
  }

  // MARK: - Title

  @ViewBuilder
  private func titleLabel(large: Bool) -> some View {
    if let principal = spec.principal {
      if principal.item.pressable {
        Button {
          model.send(.itemTap(principal.index))
        } label: {
          principalBody(principal.item, large: large)
        }
        .buttonStyle(.plain)
        .glassHelp(principal.item.tooltip)
      } else {
        principalBody(principal.item, large: large)
      }
    } else if let title = spec.title {
      Text(title)
        .font(
          large
            ? .system(size: metrics.fontLargeTitle, weight: .bold)
            : .system(size: metrics.fontTitle, weight: .semibold)
        )
        .foregroundStyle(large ? (spec.largeTitleColor ?? spec.palette.foreground) : spec.palette.foreground)
        .lineLimit(1)
        .minimumScaleFactor(large ? 0.7 : 0.8)
    }
  }

  private func principalBody(_ item: TitleItemSpec, large: Bool) -> some View {
    HStack(spacing: metrics.titleItemGap) {
      if let symbol = item.symbol {
        Image(systemName: symbol)
          .font(.system(size: metrics.titleItemIconSize))
      }
      if let label = item.label {
        Text(label)
          .font(
            .system(
              size: large ? metrics.fontLargeTitle : metrics.fontTitle,
              weight: large ? .bold : .semibold
            )
          )
      }
    }
    .foregroundStyle(large ? (spec.largeTitleColor ?? item.ink) : item.ink)
    .lineLimit(1)
  }

  // MARK: - Actions

  @ViewBuilder
  private var leadingItems: some View {
    HStack(spacing: spec.spacing) {
      ForEach(indices(at: .leading), id: \.self) { index in
        itemView(spec.items[index], index: index)
      }
    }
  }

  @ViewBuilder
  private var trailingItems: some View {
    HStack(spacing: spec.spacing) {
      ForEach(indices(at: .trailing), id: \.self) { index in
        itemView(spec.items[index], index: index)
      }
    }
  }

  private func indices(at placement: TitlePlacement) -> [Int] {
    spec.items.indices.filter { spec.items[$0].placement == placement }
  }

  /// Flat index of the first member of the group at [index]. Event indices address the
  /// flattened list, counted the same way as `_flatItems` on the Dart side.
  private func flatStart(_ index: Int) -> Int {
    spec.items.prefix(index).reduce(0) { $0 + max($1.members.count, 1) }
  }

  @ViewBuilder
  private func itemView(_ item: TitleItemSpec, index: Int) -> some View {
    if item.members.isEmpty {
      singleItem(item, index: index)
    } else {
      groupedItems(item, index: index)
    }
  }

  @ViewBuilder
  private func singleItem(_ item: TitleItemSpec, index: Int) -> some View {
    if item.pressable {
      Button {
        model.send(.itemTap(index))
      } label: {
        itemBody(item)
      }
      .buttonStyle(.plain)
      .glassed(Capsule(), interactive: spec.interactive, tint: item.tint)
      .glassHelp(item.tooltip)
    } else {
      itemBody(item)
        .glassed(Capsule(), interactive: false, tint: item.tint)
        .glassHelp(item.tooltip)
    }
  }

  /// A group: its members share one glass capsule, separated only by `gap`.
  @ViewBuilder
  private func groupedItems(_ group: TitleItemSpec, index: Int) -> some View {
    let start = flatStart(index)
    HStack(spacing: group.gap) {
      ForEach(Array(group.members.enumerated()), id: \.offset) { offset, member in
        Button {
          model.send(.itemTap(start + offset))
        } label: {
          memberBody(member)
        }
        .buttonStyle(.plain)
        // Non-pressable members block hit testing instead of using `.disabled`, which
        // would also dim their appearance.
        .allowsHitTesting(member.pressable)
        .glassHelp(member.tooltip)
      }
    }
    .glassed(
      Capsule(),
      interactive: spec.interactive,
      tint: group.members.first(where: { $0.selected })?.tint
    )
  }

  /// One member of a group: the shared glass supplies the outline, so this entry only
  /// sizes to its own content.
  private func memberBody(_ item: TitleItemSpec) -> some View {
    HStack(spacing: metrics.titleItemGap) {
      if let symbol = item.symbol {
        Image(systemName: symbol)
          .font(.system(size: metrics.titleItemIconSize))
      }
      if let label = item.label {
        Text(label)
          .font(.system(size: metrics.fontItem))
          .lineLimit(1)
      }
    }
    .padding(.horizontal, metrics.titleItemPadWithIcon / 2)
    .foregroundStyle(item.ink)
    .frame(height: spec.height)
    .overlay(alignment: .topTrailing) {
      if item.dot {
        Circle()
          .fill(item.dotColor)
          .frame(width: metrics.badgeSize, height: metrics.badgeSize)
          .padding(metrics.badgeInset)
      }
    }
  }

  private func itemBody(_ item: TitleItemSpec) -> some View {
    Group {
      if item.label == nil, let symbol = item.symbol {
        // An item with only a symbol is circular.
        Image(systemName: symbol)
          .font(.system(size: metrics.titleItemIconSize))
          .foregroundStyle(item.ink)
          .frame(width: spec.height, height: spec.height)
      } else {
        HStack(spacing: metrics.titleItemGap) {
          if let symbol = item.symbol {
            Image(systemName: symbol)
              .font(.system(size: metrics.titleItemIconSize))
              .foregroundStyle(item.ink)
          }
          if let label = item.label {
            Text(label)
              .font(.system(size: metrics.fontItem))
              .foregroundStyle(item.ink)
              .lineLimit(1)
          }
        }
        .padding(
          .horizontal,
          item.symbol == nil ? metrics.titleItemPad : metrics.titleItemPadWithIcon
        )
        .frame(height: spec.height)
      }
    }
    .overlay(alignment: .topTrailing) {
      if item.dot {
        Circle()
          .fill(item.dotColor)
          .frame(width: metrics.badgeSize, height: metrics.badgeSize)
          .padding(metrics.badgeInset)
      }
    }
  }

  // MARK: - Search state

  private var searchField: some View {
    HStack(spacing: metrics.searchIconGap) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: metrics.searchIconSize))
        .foregroundStyle(spec.palette.hint)
      TextField(spec.searchHint, text: searchBinding)
        .textFieldStyle(.plain)
        .font(.system(size: metrics.fontTitle))
        .foregroundStyle(spec.palette.foreground)
        .focused($searchFocused)
        .onSubmit { model.send(.searchSubmitted(model.searchText)) }
    }
    .padding(.leading, metrics.searchLeadingPad)
    .padding(.trailing, metrics.searchTrailingPad)
    .frame(maxWidth: .infinity, minHeight: spec.height, maxHeight: spec.height)
    .glassed(Capsule(), interactive: spec.interactive)
    .onAppear { searchFocused = true }
    .onDisappear { model.setSearchText("") }
  }

  private var cancelButton: some View {
    Button {
      model.send(.searchCancel)
    } label: {
      Text(spec.searchCancel)
        .font(.system(size: metrics.fontTitle))
        .foregroundStyle(spec.palette.action)
        .padding(.horizontal, metrics.searchCancelPad)
        .frame(minHeight: spec.height)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// Text field binding. Keystrokes go through the setter, so no `onChange` hook is
  /// needed; that API differs across OS versions.
  private var searchBinding: Binding<String> {
    Binding(
      get: { model.searchText },
      set: { model.setSearchText($0) }
    )
  }
}
