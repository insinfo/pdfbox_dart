import 'type/type_mapping.dart';

/// Base interface for XMP metadata access from types to avoid circular imports.
abstract class XMPMetadataBase {
  TypeMapping get typeMapping;
}
