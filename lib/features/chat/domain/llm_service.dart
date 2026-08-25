import '../../../llm/model_descriptor.dart';
import 'prompt.dart';
import 'tokenizer.dart';

/// One live inference context, owning the KV cache for a single conversation
/// (technical-spec §5.1).
///
/// A conversation maps to a session. Opening it prefills once with the system
/// prompt and retained history; each later turn feeds only the new tokens, so
/// per-turn latency stays flat as the conversation grows. Closing the
/// conversation disposes the session.
abstract class LlmSession {
  /// Streams the reply token-by-token.
  ///
  /// **Cancelling the subscription stops generation.** Not "stops delivery" —
  /// an implementation that keeps generating into a dropped stream burns the
  /// battery §8 asks us to watch, and on a real engine holds the model busy
  /// while the user waits for the next turn.
  ///
  /// Emits a [GenerationFailed] error on the stream if generation breaks
  /// part-way; tokens already delivered stand.
  Stream<String> send(Prompt turn);

  Future<void> dispose();
}

/// The inference engine (technical-spec §5.1).
///
/// Phase 2 registers `FakeLlmService`; Phase 3.1 registers the llama.cpp one and
/// changes nothing else. That swap is the reason this interface says nothing
/// about conversations, roles, templates or budgets — all of which live in
/// `PromptBuilder`, one layer up. An engine that knew about them could not be
/// exchanged for one that knew about them differently.
abstract class LlmService {
  Future<void> loadModel(ModelDescriptor model);

  Future<void> unload();

  /// Prefills the seed (system prompt + retained history) and returns a live
  /// session.
  ///
  /// This is the expensive call — §8's prefill ceiling is about this, and the
  /// UI must show `isPrefilling` while it runs rather than a blank screen.
  Future<LlmSession> openSession({required Prompt seed});

  /// The tokenizer matching the loaded model, used for budget enforcement.
  Tokenizer get tokenizer;
}
