import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The copy-page button goes through this channel.
    //
    // Flutter's clipboard only takes text (`Clipboard.setData`), and the glass
    // the native renderer draws is not in Flutter's own canvas either — so the
    // per-screen images have to be rendered by the system. A page is taller than
    // the window, so this side hands over one screen at a time, the Dart side
    // scrolls and stitches, and this side only provides "the window as it is
    // right now" and "put the stitched image down".
    FlutterMethodChannel(
      name: "swiftui_kit_example/screenshot",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "captureWindow":
        result(self.captureWindow())
      case "pasteImage":
        self.pasteImage(call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  /// A PNG of this window right now, plus how it lines up with Flutter's layer.
  ///
  /// `scale` is how many pixels one logical point takes; `offsetX`/`offsetY` are
  /// the content view's top-left corner inside the image (the image starts at
  /// the window's top-left corner while Flutter's [0,0] is the content view, so
  /// the title bar has to be subtracted).
  private func captureWindow() -> [String: Any]? {
    guard
      let raw = windowImage(),
      let image = normalized(raw),
      let png = NSBitmapImageRep(cgImage: image).representation(
        using: .png,
        properties: [:]
      )
    else { return nil }
    let scale = Double(image.width) / Double(frame.width)
    var offsetX = 0.0
    var offsetY = 0.0
    if let content = contentView {
      // AppKit measures y upwards, the image from the top.
      let box = content.convert(content.bounds, to: nil)
      offsetX = Double(box.minX) * scale
      offsetY = Double(frame.height - box.maxY) * scale
    }
    return [
      "bytes": FlutterStandardTypedData(bytes: png),
      "scale": scale,
      "offsetX": offsetX,
      "offsetY": offsetY,
      "width": image.width,
      "height": image.height,
    ]
  }

  /// Normalises the system's image to 8-bit sRGB.
  ///
  /// The bit depth the system hands over varies: on this machine two runs gave
  /// one 8-bit and one 16-bit image, and the same pixels read back different
  /// numbers. A before/after comparison needs the same numbers, so the image is
  /// drawn into a fixed 8-bit sRGB context first.
  private func normalized(_ image: CGImage) -> CGImage? {
    guard
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue
      )
    else { return nil }
    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    return context.makeImage()
  }

  /// Puts the stitched image on the clipboard.
  private func pasteImage(_ arguments: Any?) {
    guard let typed = arguments as? FlutterStandardTypedData else { return }
    let board = NSPasteboard.general
    board.clearContents()
    board.setData(typed.data, forType: .png)
  }

  /// One image of the whole window.
  ///
  /// What the system returns is already composited, so the Metal-drawn part and
  /// the native glass are both in it. When the system does not return one, this
  /// falls back to rendering the content view itself — the platform views are
  /// there in that case, and Flutter's own layer is mostly empty.
  private func windowImage() -> CGImage? {
    let fromSystem = CGWindowListCreateImage(
      .null,
      .optionIncludingWindow,
      CGWindowID(windowNumber),
      [.boundsIgnoreFraming, .bestResolution]
    )
    if let fromSystem { return fromSystem }

    guard let view = contentView else { return nil }
    let bounds = view.bounds
    guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
      return nil
    }
    view.cacheDisplay(in: bounds, to: rep)
    return rep.cgImage
  }
}
