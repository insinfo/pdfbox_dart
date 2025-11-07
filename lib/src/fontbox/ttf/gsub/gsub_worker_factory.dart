import 'package:logging/logging.dart';

import '../cmap_lookup.dart';
import '../model/gsub_data.dart';
import '../model/language.dart';
import 'default_gsub_worker.dart';
import 'gsub_worker.dart';
import 'gsub_worker_for_bengali.dart';
import 'gsub_worker_for_devanagari.dart';
import 'gsub_worker_for_gujarati.dart';
import 'gsub_worker_for_latin.dart';

/// Produces language-specific GSUB workers based on font data.
class GsubWorkerFactory {
  static final Logger _log = Logger('fontbox.GsubWorkerFactory');

  GsubWorker getGsubWorker(CMapLookup cmapLookup, GsubData gsubData) {
    _log.fine('Language: ${gsubData.language}');
    switch (gsubData.language) {
      case Language.bengali:
        return GsubWorkerForBengali(cmapLookup, gsubData);
      case Language.devanagari:
        return GsubWorkerForDevanagari(cmapLookup, gsubData);
      case Language.gujarati:
        return GsubWorkerForGujarati(cmapLookup, gsubData);
      case Language.latin:
        return GsubWorkerForLatin(cmapLookup, gsubData);
      case Language.unspecified:
        return DefaultGsubWorker();
    }
  }
}
