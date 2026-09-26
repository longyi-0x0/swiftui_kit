# Native contract

The two sides agree on two things: the platform view type of each surface, and one
method channel per surface. Both names are declared once per side — in Dart as
`GlassContract` (`lib/src/native/glass_contract.dart`) and in Swift as
`GlassContract` (`shared/swiftui_kit/GlassSupport.swift`).

| Item | Value |
| --- | --- |
| View type (capsule bar) | `swiftui_kit/capsule_bar` |
| View type (title bar) | `swiftui_kit/title_bar` |
| Channel | `swiftui_kit/view/<platform view id>` |
| Dart to native | `update`, whose argument is a **whole spec**, never a delta |
| Native to Dart | `event`, whose argument is `{type, index?, text?}` |

The creation parameters of a platform view are the same spec as `update`: one is
passed when the view is created and another whenever the spec changes. The view
itself is never rebuilt, because rebuilding would lose the search state, the
keyboard focus and any animation in flight.

Each surface has its own channel, so an event identifies the surface it came from
without the payload having to carry an id.

## Spec: capsule bar

| Key | Type | Description |
| --- | --- | --- |
| `height` | number | Height of the capsules |
| `visualWeight` | number | 0 to 1 |
| `interactive` | bool | Whether the bar accepts input |
| `items` | list | One entry per item: `{label: string, symbol?: string, tooltip?: string}` |
| `selectedIndex` | int, optional | The selected item |
| `searchEnabled` | bool | Whether the right end shows a magnifier |
| `spacing` | number | The gap between the two capsules |
| `searching` | bool | Whether search is active |
| `searchText` | string, optional | The text the caller owns |
| `searchHint` | string | Placeholder of the search field |
| `searchCancel` | string | Label of the cancel action |
| `trailing` | map, optional | `{label, symbol?, tooltip?}` |
| `metrics` | map | See below |
| `palette` | map | See below |

## Spec: title bar

| Key | Type | Description |
| --- | --- | --- |
| `title` | string, optional | The title |
| `subtitle` | string, optional | Shown only alongside a large title |
| `displayMode` | string | `inline` or `large` |
| `largeTitleColor` | int, optional | ARGB |
| `items` | list | See below; both a single item and a group appear here |
| `searching` | bool | Whether search is active |
| `searchText` | string, optional | The text the caller owns |
| `searchHint` | string | Placeholder of the search field |
| `searchCancel` | string | Label of the cancel action |
| `height` | number | The size of one item |
| `spacing` | number | The gap between items that are not in the same group |
| `visualWeight` | number | 0 to 1 |
| `interactive` | bool | Whether the bar accepts input |
| `metrics` | map | See below |
| `palette` | map | See below |

An entry of `items` is either a single item:

| Key | Type | Description |
| --- | --- | --- |
| `placement` | string | `leading`, `principal` or `trailing` |
| `label` | string, optional | |
| `symbol` | string, optional | SF Symbol name |
| `pressable` | bool | Whether the item has an `onPressed` |
| `tooltip` | string, optional | |
| `dot` | bool | Whether to draw the badge dot |
| `dotColor` | int | ARGB |
| `selected` | bool | Whether the item is selected |
| `ink` | int | ARGB, resolved by Dart for this item's state |
| `tint` | int, optional | ARGB, present only while selected |

or a group, which adds `group` and shares one piece of glass among its members:

| Key | Type | Description |
| --- | --- | --- |
| `placement` | string | As above; a group occupies one placement |
| `gap` | number | The gap between two members |
| `group` | list | The members, each shaped like a single item |

## Spec: metrics

`metrics` carries the shared measurements so that neither side defines a dimension
on its own. The keys are the constant names in `lib/src/theme/glass_metrics.dart`,
which is also where the values and their rationale live.

## Spec: palette

The colours of text and icons are always resolved on the Dart side and pushed
as-is; the native side neither inspects the brightness nor consults the theme. A
colour is an ARGB integer, as produced by `Color.toARGB32()`.

| Key | Description |
| --- | --- |
| `isDark` | The brightness of the caller's theme. The native side uses it to set the **appearance of the view**: the glass itself follows the system appearance, and without this a dark system would put dark ink on dark glass. |
| `foreground` | Icons and the title |
| `selectedInk` / `plainInk` | The label of a selected and an unselected capsule item |
| `selectedFill` | The plate under the selected capsule item |
| `hint` | Placeholder text |
| `action` | An action that leans on the theme colour, such as cancel |
| `separator` | A separator inside a piece of glass |
| `subtitleAlpha` | How much of its alpha the subtitle of a large title keeps. The only non-colour entry: the native side needs it to render the subtitle at the same weight as the fallback. |

## Events

| `type` | Carries | Reported by |
| --- | --- | --- |
| `itemTap` | `index`, into the list the caller supplied | Both |
| `trailingTap` | — | Capsule bar |
| `searchEnter` | — | Capsule bar |
| `searchChanged` | `text` | Both |
| `searchSubmitted` | `text` | Both |
| `searchCancel` | — | Both |

An unrecognised `type` is treated as unknown and dropped, not as an error.
