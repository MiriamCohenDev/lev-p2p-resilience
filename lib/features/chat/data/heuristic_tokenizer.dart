import 'dart:math' as math;

import '../domain/tokenizer.dart';

/// A [Tokenizer] that estimates rather than tokenizes (technical-spec §5.1,
/// Appendix A).
///
/// Phase 2 has no model and therefore no real vocabulary. Appendix A is explicit
/// that no tokenizer package is needed for this: Phase 3.1 replaces this class
/// with the one the llama.cpp binding exposes, and nothing above the [Tokenizer]
/// interface changes.
///
/// **It deliberately over-counts.** §8 makes exceeding the budget a defect, so
/// the two directions of error are not symmetric: over-counting drops one more
/// old turn than strictly necessary, while under-counting silently truncates the
/// system prompt and removes the assistant's stated limits. The bias is the
/// point, not sloppiness — and it means Phase 3.1's exact tokenizer can only
/// make prompts fit better, never worse.
class HeuristicTokenizer implements Tokenizer {
  const HeuristicTokenizer();

  /// Roughly what a BPE vocabulary averages on English prose. Latin scripts sit
  /// near 4 characters per token; the count below rounds up from there.
  static const double _charsPerToken = 3.5;

  /// Every message carries template markers around it (§5.2.2) that the caller
  /// has not necessarily included in the string being counted.
  static const int _floor = 1;

  @override
  int count(String text) {
    if (text.isEmpty) return 0;

    // Whitespace-separated chunks are a lower bound on the token count: no
    // tokenizer merges across a space, so a word is at least one token however
    // short it is. Taking the max of the two estimates keeps short-word text
    // (and CJK/Hebrew, where the character ratio is worse) from being
    // under-counted.
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final byLength = (text.length / _charsPerToken).ceil();

    return math.max(_floor, math.max(words, byLength));
  }
}
