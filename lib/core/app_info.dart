/// Facts about this build that the interface shows.
abstract final class AppInfo {
  /// The version, as Settings reports it.
  ///
  /// A constant rather than `package_info_plus`, which would be a platform
  /// plugin and a dependency for one row of text. The obvious hazard is that it
  /// drifts from `pubspec.yaml`, so `test/core/app_info_test.dart` reads the
  /// pubspec and fails when the two disagree — which turns a silent lie into a
  /// failing test.
  static const String version = '1.0.0';
}
