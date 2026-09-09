import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../layout/lev_shell.dart';
import 'app_routes.dart';

/// The mapping between the shell's three destinations and their routes.
///
/// Lives in `routing` rather than in `layout` so that `LevShell` stays a layout
/// widget with no opinion about navigation — it reports which destination was
/// chosen and the screen decides what that means, which is also what lets a
/// widget test drive it without a router.
extension LevDestinationRouting on LevDestination {
  String get location => switch (this) {
        LevDestination.home => AppRoutes.home,
        LevDestination.chat => AppRoutes.chat,
        LevDestination.aid => AppRoutes.aid,
      };
}

/// Switches tabs. `go`, never `push`: the three destinations are siblings, so
/// stacking them would make "Home" something you can go back from.
void goToDestination(BuildContext context, LevDestination destination) {
  context.go(destination.location);
}
