import 'font_mapper.dart';
import 'font_mapper_impl.dart';

/// Singleton access to the configured [FontMapper].
class FontMappers {
  FontMappers._();

  static FontMapper? _instance;

  /// Returns the active [FontMapper], falling back to a stub implementation.
  static FontMapper instance() {
    _instance ??= FontMapperImpl();
    return _instance!;
  }

  /// Overrides the singleton [FontMapper] instance.
  static void set(FontMapper fontMapper) {
    _instance = fontMapper;
  }
}
