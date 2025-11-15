import 'dart:async';

import 'msg_logger.dart';
import 'progress_watch.dart';
import 'stream_msg_logger.dart';

/// Manages per-zone facilities such as [MsgLogger] and [ProgressWatch].
class FacilityManager {
  // TODO(jj2000): Revisit the scoping strategy once decoder threading is ported.
  static final Map<Zone, MsgLogger> _loggers = <Zone, MsgLogger>{};
  static MsgLogger _defaultLogger = StreamMsgLogger.stdout();

  static final Map<Zone, ProgressWatch> _progressWatches = <Zone, ProgressWatch>{};
  static ProgressWatch? _defaultProgressWatch;

  static void registerMsgLogger(MsgLogger logger, {Zone? zone}) {
    if (zone == null) {
      _defaultLogger = logger;
    } else {
      _loggers[zone] = logger;
    }
  }

  static MsgLogger getMsgLogger({Zone? zone}) {
    final currentZone = zone ?? Zone.current;
    return _loggers[currentZone] ?? _defaultLogger;
  }

  static void registerProgressWatch(ProgressWatch watch, {Zone? zone}) {
    if (zone == null) {
      _defaultProgressWatch = watch;
    } else {
      _progressWatches[zone] = watch;
    }
  }

  static ProgressWatch? getProgressWatch({Zone? zone}) {
    final currentZone = zone ?? Zone.current;
    return _progressWatches[currentZone] ?? _defaultProgressWatch;
  }
}
