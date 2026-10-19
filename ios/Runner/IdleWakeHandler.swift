import CoreLocation
import Flutter
import UIKit

/// Significant-change location while the Flutter GPS stream is off.
///
/// Cell / Wi-Fi wakes are cheap and run while locked. Car-link and Core Motion
/// stay on their own channels; this is the backup when those are quiet.
final class IdleWakeHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  static let methodChannelName = "com.ultraforge.licenselogger/idle_wake"
  static let eventChannelName = "com.ultraforge.licenselogger/idle_wake_events"

  private static var shared: IdleWakeHandler?

  private let manager = CLLocationManager()
  private var eventSink: FlutterEventSink?
  private var running = false

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = IdleWakeHandler()
    shared = handler
    handler.manager.delegate = handler
    handler.manager.pausesLocationUpdatesAutomatically = false
    handler.manager.showsBackgroundLocationIndicator = false
    handler.manager.allowsBackgroundLocationUpdates = true
    FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "start":
          result(handler.start())
        case "stop":
          handler.stop()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(handler)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  @discardableResult
  private func start() -> Bool {
    if running { return true }
    manager.startMonitoringSignificantLocationChanges()
    running = true
    return true
  }

  private func stop() {
    guard running else { return }
    manager.stopMonitoringSignificantLocationChanges()
    running = false
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    eventSink?(["reason": "significant_change"])
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedAlways && running {
      manager.startMonitoringSignificantLocationChanges()
    }
  }
}
