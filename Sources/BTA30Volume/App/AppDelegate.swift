import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItemController: StatusItemController!

    // 'GURL' and '----' four-char codes (AppleEvents URL event)
    private static let internetEventClass = AEEventClass(0x4755_524C)
    private static let getURLEventID = AEEventID(0x4755_524C)
    private static let directObjectKeyword = AEKeyword(0x2D2D_2D2D)

    func applicationWillFinishLaunching(_ notification: Notification) {
        model = AppModel()
        statusItemController = StatusItemController(model: model)

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: Self.internetEventClass,
            andEventID: Self.getURLEventID
        )
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: Self.directObjectKeyword)?.stringValue,
              let url = URL(string: urlString) else { return }
        model.handle(url: url)
    }
}
