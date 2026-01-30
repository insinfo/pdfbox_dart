import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';

import 'pd_action.dart';

/// This represents a Sound action that can be executed in a PDF document.
class PDActionSound extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'Sound';

  /// Default constructor.
  PDActionSound() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionSound.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Sets the sound object.
  ///
  /// @param sound the sound object defining the sound that shall be played.
  void setSound(COSStream? sound) {
    action.setItem(COSName.sound, sound);
  }

  /// Gets the sound object.
  ///
  /// @return The sound object defining the sound that shall be played.
  COSStream? getSound() {
    return action.getCOSStream(COSName.sound);
  }

  /// Sets the volume at which to play the sound, in the range -1.0 to 1.0.
  ///
  /// @param volume The volume at which to play the sound.
  /// @throws ArgumentError if the volume parameter is outside of the range -1.0 to 1.0.
  void setVolume(double volume) {
    if (volume < -1 || volume > 1) {
      throw ArgumentError('volume outside of the range -1.0 to 1.0');
    }
    action.setFloat(COSName.volume, volume);
  }

  /// Gets the volume.
  ///
  /// @return The volume at which to play the sound, in the range -1.0 to 1.0. Default value: 1.0.
  double getVolume() {
    final volume = action.getFloat(COSName.volume, 1.0) ?? 1.0;
    return volume < -1 || volume > 1 ? 1.0 : volume;
  }

  /// A flag specifying whether to play the sound synchronously or asynchronously.
  /// When true, the reader allows no further user interaction other than 
  /// canceling the sound until the sound has been completely played.
  ///
  /// @param synchronous Whether to play the sound synchronously (true) or asynchronously (false).
  void setSynchronous(bool synchronous) {
    action.setBoolean(COSName.synchronous, synchronous);
  }

  /// Gets the synchronous flag.
  ///
  /// @return Whether to play the sound synchronously (true) or asynchronously (false, also the default).
  bool getSynchronous() {
    return action.getBoolean(COSName.synchronous, false) ?? false;
  }

  /// A flag specifying whether to repeat the sound indefinitely.
  ///
  /// @param repeat Whether to repeat the sound indefinitely.
  void setRepeat(bool repeat) {
    action.setBoolean(COSName.repeat, repeat);
  }

  /// Gets whether to repeat the sound indefinitely.
  ///
  /// @return Whether to repeat the sound indefinitely (default: false).
  bool getRepeat() {
    return action.getBoolean(COSName.repeat, false) ?? false;
  }

  /// Sets the flag specifying whether to mix this sound with any other sound 
  /// already playing. If this flag is false, any previously playing sound 
  /// shall be stopped before starting this sound.
  ///
  /// @param mix whether to mix this sound with any other sound already playing.
  void setMix(bool mix) {
    action.setBoolean(COSName.mix, mix);
  }

  /// Gets the flag specifying whether to mix this sound with any other sound 
  /// already playing.
  ///
  /// @return whether to mix this sound with any other sound already playing (default: false).
  bool getMix() {
    return action.getBoolean(COSName.mix, false) ?? false;
  }
}
