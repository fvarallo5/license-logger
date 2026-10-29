import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// User-selectable power / GPS sampling policy.
enum BatteryMode {
  batterySaver,
  balanced,
  accuracy,
}

extension BatteryModeX on BatteryMode {
  String get label => switch (this) {
        BatteryMode.batterySaver => 'Battery Saver',
        BatteryMode.balanced => 'Balanced',
        BatteryMode.accuracy => 'Accuracy',
      };

  String get description => switch (this) {
        BatteryMode.batterySaver =>
          'GPS sleeps until the car or motion wakes it. Sparse highway points. Best for long shifts.',
        BatteryMode.balanced =>
          'GPS sleeps while parked; denser points while driving. Cell gaps stay on the same trip.',
        BatteryMode.accuracy =>
          'Tightest sampling. GPS stays up. Best auto-detect; uses more battery.',
      };

  IconData get icon => switch (this) {
        BatteryMode.batterySaver => Icons.battery_saver_outlined,
        BatteryMode.balanced => Icons.balance_outlined,
        BatteryMode.accuracy => Icons.gps_fixed,
      };

  /// Location settings while watching for a trip (idle auto-detect).
  /// Build 12: denser idle so Balanced/Saver can confirm starts (Accuracy worked).
  LocationSettings get idleLocationSettings => switch (this) {
        BatteryMode.batterySaver => const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 150,
          ),
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 100,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
      };

  /// Location settings while a trip is active.
  /// Accuracy stays tight. Balanced is 60 m so long shifts are not sampled
  /// every few meters.
  LocationSettings get activeLocationSettings => switch (this) {
        BatteryMode.batterySaver => const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 30,
          ),
        BatteryMode.balanced => const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
          ),
        BatteryMode.accuracy => const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
      };

  /// iOS: pause idle watch when still. Never pause during active trips.
  /// Balanced stays awake — field tests missed the next start after a pause.
  bool get idlePauseLocationUpdatesAutomatically => switch (this) {
        BatteryMode.batterySaver => true,
        BatteryMode.balanced => true,
        BatteryMode.accuracy => false,
      };

  int get startConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 25,
        BatteryMode.balanced => 17,
        BatteryMode.accuracy => 15,
      };

  /// Parked long enough to auto-end (auto-detect trips only).
  /// Balanced is 2 minutes so a long light does not split the drive.
  int get stopConfirmSeconds => switch (this) {
        BatteryMode.batterySaver => 120,
        BatteryMode.balanced => 120,
        BatteryMode.accuracy => 60,
      };

  int get idleIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 30,
        BatteryMode.balanced => 20,
        BatteryMode.accuracy => 8,
      };

  int get activeIntervalSeconds => switch (this) {
        BatteryMode.batterySaver => 6,
        BatteryMode.balanced => 4,
        BatteryMode.accuracy => 2,
      };

  /// After this long parked at idle, drop the GPS stream (null = never).
  int? get idleParkSleepAfterSeconds => switch (this) {
        BatteryMode.batterySaver => 60,
        BatteryMode.balanced => 90,
        BatteryMode.accuracy => null,
      };

  /// How long the parked nap lasts before a GPS peek.
  int get idleParkSleepForSeconds => switch (this) {
        BatteryMode.batterySaver => 90,
        BatteryMode.balanced => 60,
        BatteryMode.accuracy => 45,
      };

  /// With native wake (car-link / motion / significant-change), sleep GPS
  /// this soon after the car is gone and we look parked. Accuracy never sleeps.
  int? get idleNativeSleepAfterSeconds => switch (this) {
        BatteryMode.batterySaver => 15,
        BatteryMode.balanced => 25,
        BatteryMode.accuracy => null,
      };

  /// Live distanceFilter / interval may stretch on stable highway headings.
  bool get usesAdaptiveSampling => this != BatteryMode.accuracy;

  /// Hold GPS after Core Motion leaves automotive (traffic lights).
  Duration get vehicleGateExitHold => switch (this) {
        BatteryMode.batterySaver => const Duration(seconds: 20),
        BatteryMode.balanced => const Duration(seconds: 25),
        BatteryMode.accuracy => const Duration(seconds: 45),
      };

  int get minActiveTripSeconds => switch (this) {
        BatteryMode.batterySaver => 90,
        BatteryMode.balanced => 60,
        BatteryMode.accuracy => 45,
      };

  double get minActiveTripMeters => switch (this) {
        BatteryMode.batterySaver => 200,
        BatteryMode.balanced => 150,
        BatteryMode.accuracy => 100,
      };

  /// Auto-end only after this much path (~0.6 mi Balanced). Short hops
  /// still save if the driver taps Stop.
  double get minAutoEndMeters => switch (this) {
        BatteryMode.batterySaver => 1100,
        BatteryMode.balanced => 965,
        BatteryMode.accuracy => 800,
      };

  /// Last speed above this refuses the soft GPS-silence auto-end (~18 mph).
  double get silenceGuardSpeedMps => 8.0;

  /// ~9 mph (accuracy) worked in field tests; keep Balanced close.
  double get startSpeedMps => switch (this) {
        BatteryMode.batterySaver => 4.5,
        BatteryMode.balanced => 4.0,
        BatteryMode.accuracy => 4.0,
      };

  double get minStartDistanceMeters => switch (this) {
        BatteryMode.batterySaver => 70,
        BatteryMode.balanced => 60,
        BatteryMode.accuracy => 60,
      };

  /// Tighter GPS while confirming a start so 60 m is measured, not skipped.
  int get confirmDistanceFilter => switch (this) {
        BatteryMode.batterySaver => 40,
        BatteryMode.balanced => 30,
        BatteryMode.accuracy => 20,
      };

  /// Below this ≈ parked / crawl (~3.4 mph).
  double get stopSpeedMps => switch (this) {
        BatteryMode.batterySaver => 1.5,
        BatteryMode.balanced => 1.5,
        BatteryMode.accuracy => 1.4,
      };

  /// Mature trip + no usable GPS this long → consider ending when last
  /// speed was slow (destination garage). Moving last-fix never ends on silence
  /// (cellular dropouts while driving).
  int get gpsSilenceFailsafeSeconds => switch (this) {
        BatteryMode.batterySaver => 240,
        BatteryMode.balanced => 210,
        BatteryMode.accuracy => 180,
      };
}
