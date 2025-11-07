import 'dart:collection';

import 'package:logging/logging.dart';

import 'gsub_worker.dart';

/// Default worker that warns about unsupported languages and keeps glyphs untouched.
class DefaultGsubWorker implements GsubWorker {
  static final Logger _log = Logger('fontbox.DefaultGsubWorker');

  @override
  List<int> applyTransforms(List<int> originalGlyphIds) {
    _log.warning(
      '${runtimeType.toString()} does not perform GSUB substitutions. '
      'The selected language may not be supported yet.',
    );
    return UnmodifiableListView<int>(originalGlyphIds);
  }
}
