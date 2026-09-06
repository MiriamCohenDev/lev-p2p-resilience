import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the desktop list column is showing.
///
/// **Not `LevShell`'s own state**, and that is the whole point of the file:
/// opening a conversation is a navigation, so go_router builds a fresh page for
/// `/chat/<id>` and any `State` inside the shell goes with the old one. A
/// collapsed column would spring back open the moment someone started a new
/// conversation — the one action still reachable while it is collapsed.
///
/// It lives for the session and is not written to the `preferences` table. The
/// annoyance this fixes is the column reappearing mid-use; a column that
/// remembers across restarts is a nicety, and the settings repository is async,
/// which would put an `AsyncValue` — and a frame of the wrong layout — in front
/// of every screen on startup.
final sideListOpenProvider =
    NotifierProvider<SideListOpen, bool>(SideListOpen.new);

class SideListOpen extends Notifier<bool> {
  /// Open, as the design draws it. Collapsing is the deliberate act.
  @override
  bool build() => true;

  void toggle() => state = !state;
}
