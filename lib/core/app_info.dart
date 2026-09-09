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

  /// The build number — the `+N` half of `pubspec.yaml`'s version.
  ///
  /// Shown beside [version] because LEV is handed between devices as a file
  /// (technical-decisions #2): two people can be holding builds of the same
  /// version and a different build, and with no store, no update check and no
  /// crash reporting, this pair of numbers is the whole of what a bug report
  /// has to identify a binary by. The same test pins it to the pubspec.
  static const String buildNumber = '1';

  /// What the About row copies to the clipboard, and what a bug report should
  /// quote. Not localised: it is an identifier, not a sentence.
  static const String buildStamp = 'LEV $version (build $buildNumber)';
}
