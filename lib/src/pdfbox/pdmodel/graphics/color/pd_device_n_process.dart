import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../pd_resources.dart';

import 'pd_color_space.dart';

class PDDeviceNProcess {
  PDDeviceNProcess([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  COSDictionary get cosDictionary => _dictionary;

  PDColorSpace? getColorSpace({PDResources? resources}) {
    final cosColorSpace = _dictionary.getDictionaryObject(COSName.colorSpace);
    if (cosColorSpace == null) {
      return null;
    }
    return PDColorSpace.create(cosColorSpace, resources: resources);
  }

  List<String> getComponents() {
    final array = _dictionary.getCOSArray(COSName.components);
    if (array == null) {
      return const <String>[];
    }
    final components = <String>[];
    for (final entry in array) {
      if (entry is COSName) {
        components.add(entry.name);
      }
    }
    return components;
  }

  @override
  String toString() {
    final buffer = StringBuffer('Process{');
    final componentNames = getComponents();
    try {
      final colorSpace = getColorSpace();
      if (colorSpace != null) {
        buffer.write(colorSpace);
      }
    } catch (_) {
      buffer.write('ERROR');
    }
    for (final component in componentNames) {
      buffer.write(' "');
      buffer.write(component);
      buffer.write('"');
    }
    buffer.write('}');
    return buffer.toString();
  }
}
