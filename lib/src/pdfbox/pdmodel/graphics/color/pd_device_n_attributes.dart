import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../pd_resources.dart';

import 'pd_color_space.dart';
import 'pd_device_n_process.dart';
import 'pd_separation.dart';

class PDDeviceNAttributes {
  PDDeviceNAttributes([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  COSDictionary get cosDictionary => _dictionary;

  Map<String, PDSeparation> getColorants({PDResources? resources}) {
    final colorantsDict = _dictionary.getCOSDictionary(COSName.colorants);
    if (colorantsDict == null) {
      return const <String, PDSeparation>{};
    }
    final result = <String, PDSeparation>{};
    for (final entry in colorantsDict.entries) {
      final colorSpace = PDColorSpace.create(
        entry.value,
        resources: resources,
      );
      if (colorSpace is PDSeparation) {
        result[entry.key.name] = colorSpace;
      }
    }
    return result;
  }

  PDDeviceNProcess? getProcess({PDResources? resources}) {
    final processDict = _dictionary.getCOSDictionary(COSName.process);
    if (processDict == null) {
      return null;
    }
    return PDDeviceNProcess(processDict);
  }

  bool get isNChannel =>
      _dictionary.getNameAsString(COSName.subtype) == 'NChannel';

  @override
  String toString() => 'DeviceNAttributes{${_dictionary.toString()}}';
}
