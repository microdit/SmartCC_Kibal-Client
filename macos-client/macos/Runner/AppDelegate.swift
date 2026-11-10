import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var logWindowController: NSWindowController?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    addLogMenu()
  }

  //--------------------------------------------------------------------------
  // 메뉴에 "실행 로그 보기" 항목 추가 (창 메뉴, 못 찾으면 최상단 "로그" 메뉴 생성)
  //--------------------------------------------------------------------------
  private func addLogMenu() {
    let item = NSMenuItem(
      title: "실행 로그 보기",
      action: #selector(showLogWindow),
      keyEquivalent: "l"
    )
    item.target = self
    item.keyEquivalentModifierMask = [.command, .option]

    if let mainMenu = NSApp.mainMenu,
       let wm = mainMenu.items.first(where: {
         $0.title == "Window" || $0.title == "창" || $0.title.lowercased() == "window"
       }),
       let submenu = wm.submenu {
      submenu.addItem(NSMenuItem.separator())
      submenu.addItem(item)
      NSLog("KibalLogWindow: added to \(wm.title)")
    } else {
      // 폴백: 최상단에 "로그" 메뉴 추가
      let submenu = NSMenu(title: "로그")
      submenu.addItem(item)
      let root = NSMenuItem(title: "로그", action: nil, keyEquivalent: "")
      root.submenu = submenu
      NSApp.mainMenu?.addItem(root)
      NSLog("KibalLogWindow: fallback menu created (mainMenu=\(String(describing: NSApp.mainMenu)))")
    }
  }

  //--------------------------------------------------------------------------
  // 실행 로그 확인 창 (파일 실시간 tail) — 메뉴 항목은 MainMenu.xib에 정의됨
  //--------------------------------------------------------------------------
  @objc func showLogWindow(_ sender: Any?) {
    NSLog("KibalLogWindow: showLogWindow invoked")
    if logWindowController == nil {
      let wc = LogWindowController()
      logWindowController = wc
    }
    logWindowController?.showWindow(sender)
    NSApp.activate(ignoringOtherApps: true)
  }
}

/// 로그 파일(app.log)을 폴링해 표시하는 네이티브 창.
final class LogWindowController: NSWindowController {
  private var textView: NSTextView?
  private var timer: Timer?
  private var lastContent: String?
  private var filterPopup: NSPopUpButton?
  private var lastRawContent: String = "" // 필터 재적용용 원본

  /// 최대 유지 렌더 문자 크기 (avoid unbounded memory)
  private static let maxRenderBytes: UInt64 = 512 * 1024

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Kibal 실행 로그"
    window.center()
    super.init(window: window)

    let contentVC = NSViewController()
    contentVC.view = makeContentView()
    window.contentViewController = contentVC
    window.collectionBehavior = [.fullScreenPrimary]
    window.windowController = self
    window.isReleasedWhenClosed = false
  }

  required init?(coder: NSCoder) {
    super.init(window: nil)
  }

  private func makeContentView() -> NSView {
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 860, height: 560))
    container.translatesAutoresizingMaskIntoConstraints = true

    // 툴바 영역
    let toolbar = NSView(frame: NSRect(x: 0, y: 528, width: 860, height: 32))
    toolbar.translatesAutoresizingMaskIntoConstraints = true
    toolbar.autoresizingMask = [.width]

    let openButton = NSButton(title: "폴더에서 열기", target: self, action: #selector(openLogFolder))
    openButton.isBordered = true
    openButton.bezelStyle = .rounded
    let copyButton = NSButton(title: "전체 복사", target: self, action: #selector(copyAllLogs))
    copyButton.isBordered = true
    copyButton.bezelStyle = .rounded
    let statusLabel = NSTextField(labelWithString: "자동 갱신 (1초)")
    statusLabel.textColor = .secondaryLabelColor
    statusLabel.font = NSFont.systemFont(ofSize: 11)

    let filterMenu = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
    for title in ["전체", "DEBUG", "INFO", "EVENT", "WARN", "ERROR"] {
      filterMenu.addItem(withTitle: title)
    }
    filterMenu.target = self
    filterMenu.action = #selector(applyFilterFromMenu)
    filterPopup = filterMenu

    let tb: [NSView] = [openButton, copyButton, filterMenu, statusLabel]
    var x: CGFloat = 8
    for (i, v) in tb.enumerated() {
      if let btn = v as? NSButton {
        btn.sizeToFit()
      }
      if let lbl = v as? NSTextField {
        lbl.sizeToFit()
      }
      let y = (32 - v.frame.height) / 2
      v.frame = NSRect(x: x, y: y, width: v.frame.width, height: v.frame.height)
      v.autoresizingMask = []
      toolbar.addSubview(v)
      x += v.frame.width + 8
      if i == 0 { x += 6 }
    }
    // status 라벨을 우측에 붙임
    statusLabel.sizeToFit()
    statusLabel.frame.origin = NSPoint(x: 860 - statusLabel.frame.width - 12,
                                       y: (32 - statusLabel.frame.height) / 2)
    statusLabel.autoresizingMask = [.minXMargin]    // 로그 텍스트 뷰
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 860, height: 524))
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.borderType = .noBorder
    let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 860, height: 524))
    text.isRichText = false
    text.isEditable = false
    text.isSelectable = true
    text.usesFindBar = true
    text.textContainerInset = NSSize(width: 8, height: 8)
    text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    text.autoresizingMask = [.width]
    scroll.documentView = text
    textView = text

    container.addSubview(toolbar)
    container.addSubview(scroll)
    return container
  }

  override func windowDidLoad() {
    super.windowDidLoad()
  }

  override func showWindow(_ sender: Any?) {
    super.showWindow(sender)
    startPolling()
    refreshLog(force: false)
  }

  private func startPolling() {
    timer?.invalidate()
    let t = Timer(timeInterval: 1.0, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  @objc private func poll() {
    guard let window = window, window.isVisible else { return }
    refreshLog(force: false)
  }

  private func refreshLog(force: Bool) {
    let path = Self.logFilePath()
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: path),
          let size = attrs[.size] as? UInt64 else {
      if lastContent != "... 로그 파일 없음" {
        lastContent = "... 로그 파일 없음"
        textView?.string = "지금은 실행 로그 파일이 없습니다.\n앱이 한 번 이상 동작하면 생성됩니다.\n\n경로: \(path)"
      }
      return
    }

    guard let handle = FileHandle(forReadingAtPath: path) else { return }
    defer { try? handle.close() }

    let readStart = UInt64(max(0, Int(size) - Int(Self.maxRenderBytes)))
    if readStart > 0 { try? handle.seek(toFileOffset: readStart) }
    let data = handle.readDataToEndOfFile()
    var content = String(decoding: data, as: UTF8.self)
    if readStart > 0, let nl = content.firstIndex(of: "\n") {
      content = String(content[content.index(after: nl)...])
    }

    if content == lastRawContent { return }
    lastRawContent = content
    let display = filtered(content)
    lastContent = display
    textView?.string = display
    if let length = textView?.textStorage?.length {
      textView?.scrollRangeToVisible(NSRange(location: max(0, length - 1), length: 1))
    }
  }

  /// 레벨 필터 적용 (전체/DEBUG/INFO/EVENT/WARN/ERROR)
  private func filtered(_ raw: String) -> String {
    guard let popup = filterPopup,
          popup.titleOfSelectedItem != "전체" else { return raw }
    let level = popup.titleOfSelectedItem!
    let lines = raw.components(separatedBy: "\n")
    let kept = lines.filter { line in
      // 로그 라인 형식: [timestamp] LEVEL [usr=..] message
      guard let idx = line.firstIndex(of: "]") else { return false }
      let rest = line[line.index(after: idx)...]
      let restTrim = rest.drop { $0 == " " }
      return restTrim.hasPrefix(level + " ")
    }
    return kept.joined(separator: "\n")
  }

  @objc private func applyFilterFromMenu() {
    refreshLog(force: true)
  }

  @objc private func openLogFolder() {
    NSWorkspace.shared.selectFile(Self.logFilePath(),
                                  inFileViewerRootedAtPath: Self.logDirectory())
  }

  @objc private func copyAllLogs() {
    guard let txt = textView?.string else { return }
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(txt, forType: .string)
  }

  deinit {
    timer?.invalidate()
    timer = nil
  }

  private static func logFilePath() -> String {
    return Self.logDirectory() + "/app.log"
  }

  private static func logDirectory() -> String {
    let fm = FileManager.default
    let support = (try? fm.url(for: .applicationSupportDirectory,
                         in: .userDomainMask,
                         appropriateFor: nil,
                         create: true)) ??
        (fm.homeDirectoryForCurrentUser
          .appendingPathComponent("Library", isDirectory: true)
          .appendingPathComponent("Application Support", isDirectory: true))
    // 샌드박스 컨테이너/일반 환경 모두에서 Dart(engine)가 쓰는 경로와 동일
    let dir = support
      .appendingPathComponent("com.microdit.macosClient", isDirectory: true)
      .appendingPathComponent("logs", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
      try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir.path
  }
}
