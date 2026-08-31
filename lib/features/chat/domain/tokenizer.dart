/// Counts tokens for budget enforcement (technical-spec §5.1).
///
/// Phase 2 supplied a fixed heuristic. Phase 3 supplies `CalibratedTokenizer`,
/// which measures the loaded model's characters-per-token with llama.cpp's own
/// tokenizer once at load time and then counts against that. Appendix A is
/// explicit that no separate tokenizer package is needed for either.
///
/// **This stays synchronous, deliberately** — see technical-decisions #20.
/// llama.cpp's tokenizer is only reachable asynchronously, and `PromptBuilder`
/// calls [count] once per message while deciding what fits, so an async counter
/// would put an isolate round-trip per message in front of every turn to answer
/// a question whose useful precision is "does this still fit".
///
/// Whichever is registered, §8 makes the contract the same: a prompt that
/// exceeds `contextTokens - replyTokenReserve` is a **defect**, not a graceful
/// degradation, because the engine's response is to silently truncate the
/// system prompt. An implementation that under-counts therefore causes a bug
/// somewhere else entirely — which is why the heuristic errs high.
abstract class Tokenizer {
  int count(String text);
}
