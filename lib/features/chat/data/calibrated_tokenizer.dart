import 'dart:math' as math;

import '../domain/tokenizer.dart';

/// A [Tokenizer] whose estimate is measured against the loaded model's own
/// vocabulary (technical-spec §5.1, §8).
///
/// **Why this is not simply the engine's tokenizer.** llama.cpp's tokenizer is
/// reachable only asynchronously — llamadart runs it on a worker isolate — while
/// [Tokenizer.count] is synchronous, and deliberately so. `DefaultPromptBuilder`
/// calls it once per message while deciding what fits, so an asynchronous
/// counter would mean one isolate round-trip per message on every single turn,
/// to answer a question whose useful precision is "does this still fit".
///
/// So the engine's tokenizer is used where it is affordable and decisive — once,
/// at model load — to measure how many tokens this model's vocabulary actually
/// produces per character of text like ours. [count] then stays synchronous and
/// free, but its constant is this model's rather than English prose's in
/// general. That matters most for the language LEV has not shipped yet: Hebrew
/// runs closer to two characters per token on a Qwen vocabulary, where the
/// uncalibrated constant of 3.5 would under-count by nearly half.
///
/// **The bias is preserved.** §8 makes exceeding the budget a defect, because
/// the engine's response to an over-long prompt is to silently drop the front of
/// it — which is the system prompt, and with it the assistant's stated limits.
/// Over-counting merely drops one more old turn than strictly necessary. So the
/// measurement takes the *worst* ratio seen across the samples, not the mean,
/// and then adds a margin.
class CalibratedTokenizer implements Tokenizer {
  const CalibratedTokenizer._(this._charsPerToken);

  /// The pre-Phase-3 estimate, used before a model is loaded and whenever
  /// calibration cannot run.
  ///
  /// Roughly what a BPE vocabulary averages on English prose. This is Phase 2's
  /// `HeuristicTokenizer` constant and formula, folded in here rather than kept
  /// in a class of its own — two copies of one formula stay in agreement only
  /// until somebody edits one.
  ///
  /// It stays a fallback rather than an error: a chat that refuses to assemble a
  /// prompt because it could not measure a ratio is worse than one that
  /// assembles a slightly conservative prompt.
  const CalibratedTokenizer.uncalibrated() : _charsPerToken = 3.5;

  /// Measures [samples] with the model's own tokenizer.
  ///
  /// [countExact] is `LlamaEngine.getTokenCount` in production and a plain
  /// function in tests — this class never imports the engine, so the whole of it
  /// is testable on the host with no weights.
  ///
  /// Any failure falls back to [CalibratedTokenizer.uncalibrated]: calibration
  /// is an optimisation of an estimate that already errs in the safe direction,
  /// and it must never be the reason a model refuses to load.
  static Future<CalibratedTokenizer> calibrate({
    required Future<int> Function(String text) countExact,
    required List<String> samples,
  }) async {
    var worst = double.infinity;

    for (final sample in samples) {
      final text = sample.trim();
      // Short strings are dominated by the vocabulary's handling of the first
      // and last token and produce ratios that are not representative of prose.
      if (text.length < _minimumSampleLength) continue;
      try {
        final tokens = await countExact(text);
        if (tokens <= 0) continue;
        worst = math.min(worst, text.length / tokens);
      } on Object {
        // A tokenizer that throws is a tokenizer we cannot calibrate against.
        // The fallback is safe, so this is not worth failing a model load over.
        return const CalibratedTokenizer.uncalibrated();
      }
    }

    if (!worst.isFinite) return const CalibratedTokenizer.uncalibrated();

    // The margin. Calibration is measured on the samples we happened to have,
    // and real conversations contain things they do not — code, URLs, emoji,
    // a language the samples were not written in — all of which tokenize worse
    // than prose. Shading the ratio down keeps the estimate on the safe side of
    // wrong when that happens.
    final calibrated = worst * (1 - _margin);

    // Never worse than the uncalibrated guess: a model whose vocabulary is
    // unusually efficient on the samples must not be allowed to talk the
    // estimate up into under-counting ordinary text.
    return CalibratedTokenizer._(math.min(calibrated, 3.5));
  }

  /// Visible for testing: build with a ratio measured elsewhere.
  const CalibratedTokenizer.withRatio(double charsPerToken)
      : _charsPerToken = charsPerToken;

  final double _charsPerToken;

  /// Below this a sample says more about the tokenizer's edges than its prose.
  static const int _minimumSampleLength = 120;

  /// How far the measured ratio is shaded towards over-counting.
  static const double _margin = 0.1;

  /// Every message carries template markers around it (§5.2.2) that the caller
  /// has not necessarily included in the string being counted.
  static const int _floor = 1;

  double get charsPerToken => _charsPerToken;

  @override
  int count(String text) {
    if (text.isEmpty) return 0;

    // Whitespace-separated chunks are a lower bound on the token count: no
    // tokenizer merges across a space, so a word is at least one token however
    // short it is. Taking the max of the two estimates keeps short-word text
    // from being under-counted even if the ratio is generous.
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final byLength = (text.length / _charsPerToken).ceil();

    return math.max(_floor, math.max(words, byLength));
  }

  @override
  String toString() =>
      'CalibratedTokenizer(${_charsPerToken.toStringAsFixed(2)} chars/token)';
}
