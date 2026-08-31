import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

/// The safety layer's support message, its phone number and its review date.
///
/// **The numbers are an asset, not code** (technical-decisions #24). They
/// change, they are localised alongside the interface, and they have to be
/// fixable without recompiling: a number that has gone stale is worse than a
/// message that never appeared.
///
/// This supersedes the `supportMessage` field carried in
/// `assets/prompts/safety_patterns_<locale>.json` (#18). The pattern file still
/// decides *whether* to show the message — `SafetyVerdict.matched` — but what is
/// shown now needs a title, a body, a service name and a dialable number, which
/// a single string cannot carry.
class LevSupportResource {
  const LevSupportResource({
    required this.title,
    required this.body,
    required this.callLabel,
    required this.phone,
    required this.serviceName,
    required this.reviewedOn,
  });

  /// "You don't have to be with this alone".
  final String title;

  /// The body of the message.
  ///
  /// Note what is **not** in it: no promise that the call is confidential or
  /// anonymous. That varies between services and between circumstances, and it
  /// is not ours to promise on someone else's behalf. There is one fact that can
  /// be stood behind — a person is there, around the clock — and that is all it
  /// claims.
  final String body;

  final String callLabel;

  /// A phone number, never a web address: this is an app with no network, and a
  /// link would be a dead button.
  final String phone;

  final String serviceName;

  /// When the number was last checked against an official source (YYYY-MM-DD).
  /// Verify before every release and update it.
  final String reviewedOn;

  factory LevSupportResource.fromJson(Map<String, dynamic> json) {
    return LevSupportResource(
      title: json['title'] as String,
      body: json['body'] as String,
      callLabel: json['callLabel'] as String,
      phone: json['phone'] as String,
      serviceName: json['serviceName'] as String,
      reviewedOn: json['reviewedOn'] as String,
    );
  }
}

/// Loads [LevSupportResource] from `assets/support/<languageCode>.json`.
abstract final class LevSupportResources {
  static const String assetDirectory = 'assets/support';

  /// The language used when the UI's language has no file of its own.
  static const String fallbackLanguage = 'he';

  static final Map<String, LevSupportResource> _cache = {};

  /// Loads the support resource for the **UI** language.
  ///
  /// The UI language, not the model's: §10's Hebrew gap and #11 together mean a
  /// Hebrew-reading user gets a Hebrew interface and an English assistant, and
  /// the person in front of the screen is the one who has to be able to read
  /// this.
  static Future<LevSupportResource> load(String languageCode) async {
    final cached = _cache[languageCode];
    if (cached != null) return cached;

    String raw;
    try {
      raw = await rootBundle.loadString('$assetDirectory/$languageCode.json');
    } on FlutterError {
      raw = await rootBundle.loadString(
        '$assetDirectory/$fallbackLanguage.json',
      );
    }

    final resource = parse(raw);
    _cache[languageCode] = resource;
    return resource;
  }

  /// Parses a resource from its JSON text. Exposed so a test can supply one
  /// without touching `rootBundle`, which caches the future it returns and
  /// therefore does not resolve again inside a later test's `fake_async` zone.
  static LevSupportResource parse(String raw) =>
      LevSupportResource.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Drops the cache. For tests that load more than one language.
  static void resetCache() => _cache.clear();
}
