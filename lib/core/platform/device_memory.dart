import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// How much physical RAM this device has, in megabytes
/// (technical-spec §8, §9 Phase 3.2).
///
/// This is the number `ModelSelector` gates on. Phase 2 supplied a placeholder
/// that admitted every model, because nothing was loaded and the gate could not
/// mean anything; Phase 3 loads several hundred megabytes of weights and the
/// gate becomes the difference between a model that runs and one that takes the
/// app down with it — §8 is explicit that a model which does not fit does not
/// degrade gracefully.
///
/// **No plugin, no platform channel.** Each platform is read the way that
/// platform actually exposes the fact: `/proc/meminfo` on Linux and Android,
/// `GlobalMemoryStatusEx` on Windows, `sysctlbyname` on macOS and iOS. All three
/// are already reachable from Dart, so a dependency here would buy nothing and
/// would have to be kept working on four platforms.
///
/// Returns null when the figure cannot be read. That is a real state — a
/// hardened container with no `/proc`, an FFI symbol that is not there — and the
/// caller has to decide what to do about it. It is deliberately not an
/// exception: being unable to *measure* RAM is not the same as not having
/// enough, and it must not read as the latter.
int? totalPhysicalMemoryMb() {
  try {
    if (Platform.isAndroid || Platform.isLinux) return _fromProcMeminfo();
    if (Platform.isWindows) return _fromGlobalMemoryStatusEx();
    if (Platform.isMacOS || Platform.isIOS) return _fromSysctl();
  } on Object {
    // Every branch below touches something outside Dart's control — a file that
    // may not exist, a symbol that may not be exported. None of it is worth
    // taking the app down for, because the caller has a documented answer for
    // null.
    return null;
  }
  return null;
}

/// Linux and Android: `MemTotal:` in `/proc/meminfo`, reported in kB.
///
/// This is the kernel's own figure for usable physical memory. It reads
/// slightly below the RAM printed on the box — the kernel has already reserved
/// some — which is the right direction for a gate: what a model can actually use
/// is what matters, not what was advertised.
int? _fromProcMeminfo() {
  final file = File('/proc/meminfo');
  if (!file.existsSync()) return null;

  for (final line in file.readAsLinesSync()) {
    if (!line.startsWith('MemTotal:')) continue;
    final match = RegExp(r'(\d+)').firstMatch(line);
    if (match == null) return null;
    final kilobytes = int.tryParse(match.group(1)!);
    return kilobytes == null ? null : kilobytes ~/ 1024;
  }
  return null;
}

/// Windows: `GlobalMemoryStatusEx`, whose `ullTotalPhys` is bytes.
int? _fromGlobalMemoryStatusEx() {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final globalMemoryStatusEx = kernel32.lookupFunction<
      Int32 Function(Pointer<_MemoryStatusEx>),
      int Function(Pointer<_MemoryStatusEx>)>('GlobalMemoryStatusEx');

  final status = calloc<_MemoryStatusEx>();
  try {
    // The API rejects the struct unless it is told its own size — this is how
    // it distinguishes the layout it knows from any later one.
    status.ref.dwLength = sizeOf<_MemoryStatusEx>();
    if (globalMemoryStatusEx(status) == 0) return null;
    return status.ref.ullTotalPhys ~/ (1024 * 1024);
  } finally {
    calloc.free(status);
  }
}

/// macOS and iOS: `sysctlbyname("hw.memsize")`, in bytes.
int? _fromSysctl() {
  final libc = DynamicLibrary.process();
  final sysctlbyname = libc.lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Void>, Pointer<Size>,
          Pointer<Void>, Size),
      int Function(Pointer<Utf8>, Pointer<Void>, Pointer<Size>, Pointer<Void>,
          int)>('sysctlbyname');

  final name = 'hw.memsize'.toNativeUtf8();
  final out = calloc<Uint64>();
  final length = calloc<Size>();
  try {
    length.value = sizeOf<Uint64>();
    final result = sysctlbyname(
      name,
      out.cast<Void>(),
      length,
      nullptr,
      0,
    );
    if (result != 0) return null;
    return out.value ~/ (1024 * 1024);
  } finally {
    calloc
      ..free(name)
      ..free(out)
      ..free(length);
  }
}

/// `MEMORYSTATUSEX` from `sysinfoapi.h`.
///
/// Declared in full even though only two fields are used: the struct is passed
/// by pointer and the OS writes all of it, so a short declaration would have it
/// writing past the end of our allocation.
final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;

  @Uint32()
  external int dwMemoryLoad;

  @Uint64()
  external int ullTotalPhys;

  @Uint64()
  external int ullAvailPhys;

  @Uint64()
  external int ullTotalPageFile;

  @Uint64()
  external int ullAvailPageFile;

  @Uint64()
  external int ullTotalVirtual;

  @Uint64()
  external int ullAvailVirtual;

  @Uint64()
  external int ullAvailExtendedVirtual;
}
