import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// A fresh random identifier for a stored entity.
///
/// UUIDv4 — random, not derived from the device or the clock. Every entity that
/// might ever cross devices uses one instead of an auto-increment integer, so a
/// future merge cannot collide (technical-spec §6). Chat entities use it too,
/// for consistency and because the alternative buys nothing.
String newId() => _uuid.v4();
