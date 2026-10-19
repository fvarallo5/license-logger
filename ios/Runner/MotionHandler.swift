import CoreMotion
import Flutter
import UIKit

/// Core Motion activity — auto-track sleeps GPS until the phone is in a vehicle.
final class MotionHandler: NSObject, FlutterStreamHandler {
  static let methodChannelName = "com.ultraforge.licenselogger/motion"
  static let eventChannelName = "com.ultraforge.licenselogger/motion_events"

  private static var instance: MotionHandler?

  private let manager = CMMotionActivityManager()
  private var eventSink: FlutterEventSink?
  private var lastType = "unknown"
  private var lastConfidence = 0
  private var inVehicle = false
  private var hasPermission = false

  static func register(messenger: FlutterBinaryMessenger) {
    let handler = MotionHandler()
    instance = handler
    FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getState":
          result(handler.currentState())
        case "isAvailable":
          result(CMMotionActivityManager.isActivityAvailable())
        case "start":
          handler.startUpdates()
          result(handler.currentState())
        case "requestPermission":
          handler.requestPermission(result: result)
        case "stop":
          handler.stopUpdates()
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
    startUpdates()
    events(currentState())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopUpdates()
    eventSink = nil
    return nil
  }

  /// `queryActivityStarting` is what presents the Motion & Fitness system alert.
  func requestPermission(result: @escaping FlutterResult) {
    refreshPermission()
    if hasPermission {
      startUpdates()
      result(currentState())
      return
    }

    let status = CMMotionActivityManager.authorizationStatus()
    if status == .denied || status == .restricted {
      result(currentState())
      return
    }

    var finished = false
    let complete = { [weak self] in
      guard !finished else { return }
      finished = true
      guard let self else {
        result([
          "available": false,
          "inVehicle": false,
          "activity": "unknown",
          "confidence": 0,
          "permission": false,
        ])
        return
      }
      self.refreshPermission()
      if self.hasPermission {
        self.startUpdates()
      }
      result(self.currentState())
    }

    let now = Date()
    manager.queryActivityStarting(
      from: now.addingTimeInterval(-30),
      to: now,
      to: .main
    ) { _, _ in
      complete()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
      complete()
    }
  }

  private func refreshPermission() {
    switch CMMotionActivityManager.authorizationStatus() {
    case .authorized:
      hasPermission = true
    case .denied, .restricted, .notDetermined:
      hasPermission = false
    @unknown default:
      hasPermission = false
    }
  }

  private func startUpdates() {
    refreshPermission()
    guard CMMotionActivityManager.isActivityAvailable() else {
      lastType = "unavailable"
      inVehicle = false
      emit()
      return
    }

    manager.startActivityUpdates(to: .main) { [weak self] activity in
      guard let self, let activity else { return }
      self.apply(activity)
      self.emit()
    }
  }

  private func stopUpdates() {
    manager.stopActivityUpdates()
  }

  private func apply(_ activity: CMMotionActivity) {
    switch activity.confidence {
    case .low:
      lastConfidence = 25
    case .medium:
      lastConfidence = 55
    case .high:
      lastConfidence = 85
    @unknown default:
      lastConfidence = 40
    }

    if activity.confidence == .low {
      return
    }

    if activity.automotive {
      lastType = "in_vehicle"
      inVehicle = true
    } else if activity.cycling {
      lastType = "on_bicycle"
      inVehicle = true
    } else if activity.running {
      lastType = "running"
      inVehicle = false
    } else if activity.stationary {
      lastType = "still"
      inVehicle = false
    } else if activity.walking {
      lastType = "walking"
      inVehicle = false
    } else {
      lastType = "unknown"
    }
  }

  private func emit() {
    eventSink?(currentState())
  }

  private func currentState() -> [String: Any?] {
    refreshPermission()
    return [
      "available": CMMotionActivityManager.isActivityAvailable(),
      "inVehicle": inVehicle,
      "activity": lastType,
      "confidence": lastConfidence,
      "permission": hasPermission,
    ]
  }
}
