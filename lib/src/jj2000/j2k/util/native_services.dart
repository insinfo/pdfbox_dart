/// Placeholder for JJ2000 native services.
///
/// The original library relied on OS-specific native methods to adjust POSIX
/// thread concurrency levels. This Dart port executes inside a single isolate,
/// so the calls become no-ops while retaining the API surface for code parity.
class NativeServices {
  NativeServices._();

  static const String sharedLibraryName = 'ucar/jpeg/jj2000';

  static bool loadLibrary() {
    // TODO(jj2000): Wire up native concurrency controls if/when the decoder
    // moves to isolates or FFI-backed workers.
    return false;
  }

  static void setThreadConcurrency(int level) {
    if (level < 0) {
      throw ArgumentError.value(level, 'level', 'Concurrency must be >= 0');
    }
    // No-op: Dart does not expose a direct analogue for pthread concurrency.
  }

  static int getThreadConcurrency() => 0;
}
