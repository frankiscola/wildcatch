import 'package:flutter/services.dart';

/// Mechanism 2 of the anti-photo-of-a-screen plan: real depth check.
///
/// CURRENT STATE: scaffold, NOT implemented natively yet.
///
/// Many phones expose a depth map of the scene (LiDAR/TrueDepth on
/// iOS via AVDepthData, dual-camera stereo or ToF on Android via
/// Camera2's ImageFormat.DEPTH16 stream). If the depth in the center
/// of the frame is nearly constant, the scene is almost certainly a
/// flat plane (a screen, a printed photo) rather than a real animal
/// at a varying distance from the background.
///
/// Implementing this properly requires native Swift/Kotlin code that
/// can't be written "blind" without a device to test on: a bug here
/// wouldn't cause a compile error, just "always works/never works",
/// hard to notice before shipping the app. That's why this service
/// is written to fail explicitly and stay ALWAYS optional: if the
/// native channel doesn't respond, the rest of the pipeline (checks
/// 1, 3, 4, 5) keeps working exactly as if this signal didn't exist.
///
/// To actually enable it in the future:
///  - iOS: implement a MethodChannel in AppDelegate.swift that uses
///    AVCaptureDepthDataOutput to read the depth variance at the
///    center of the frame during capture.
///  - Android: implement a MethodChannel in MainActivity.kt that
///    uses Camera2 (CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL
///    + an ImageFormat.DEPTH16 stream, if the device supports it) to
///    compute the same variance.
/// In both cases the channel must respond with `null` (not a fake
/// value) on devices that have no depth hardware.
class DepthCheckService {
  static const _channel = MethodChannel('wildkin/depth');

  /// Returns the estimated depth variance at the center of the
  /// frame, or `null` if the device/platform doesn't expose this
  /// data (the expected case today, on EVERY device, until the
  /// native channel is implemented).
  ///
  /// A value near 0 = a flat surface was detected (suspicious).
  /// A high value = varying depth = a real 3D scene.
  Future<double?> sampleCenterDepthVariance() async {
    try {
      final result = await _channel.invokeMethod<double>('sampleCenterDepthVariance');
      return result;
    } on MissingPluginException {
      // Expected until the native code is written: no error to show
      // the user, just "signal not available".
      return null;
    } on PlatformException {
      return null;
    }
  }
}
