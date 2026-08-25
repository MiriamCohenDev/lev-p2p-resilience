/// Counts tokens for budget enforcement (technical-spec §5.1).
///
/// Phase 2 supplies a heuristic implementation; Phase 3.1 replaces it with the
/// one the llama.cpp binding exposes. Appendix A is explicit that no separate
/// tokenizer package is needed for either.
///
/// Whichever is registered, §8 makes the contract the same: a prompt that
/// exceeds `contextTokens - replyTokenReserve` is a **defect**, not a graceful
/// degradation, because the engine's response is to silently truncate the
/// system prompt. An implementation that under-counts therefore causes a bug
/// somewhere else entirely — which is why the heuristic errs high.
abstract class Tokenizer {
  int count(String text);
}
