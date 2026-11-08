import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: NSApplication,
        didFinishLaunching withOptions launchOptions: [NSApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 상태 표시줄 아이콘 추가 (선택 사항)
        // let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // ...

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
