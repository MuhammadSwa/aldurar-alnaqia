import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerStorageChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// `app/storage` channel: marks download directories as excluded from
  /// iCloud/iTunes backup (downloaded books and narrations are
  /// re-downloadable and must not consume backup quota).
  private func registerStorageChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "app/storage",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "EXCLUDE_FAILED",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }
}
