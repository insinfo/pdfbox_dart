
import 'package:petitparser/petitparser.dart';

/// Write all strings in [value] to [target], assuming [value] is a nested
/// list of string of arbitrary finite depth.
void _flattenString(dynamic value, StringBuffer target) {
  if (value == null) {
    return;
  }
  if (value is String) {
    target.write(value);
    return;
  }
  if (value is List) {
    for (final v in value) {
      _flattenString(v, target);
    }
    return;
  }
  throw ArgumentError('Unsupported type ${value.runtimeType}');
}

/// Create a [Parser] that ignores output from [p] and return `null`.
Parser<String?> ignore<T>(Parser<T> p) => p.map((_) => null);

/// Create a [Parser] that flattens all strings in the result from [p].
Parser<String> flatten(Parser<dynamic> p) => p.map((value) {
      final s = StringBuffer();
      _flattenString(value, s);
      return s.toString();
    });
