library lzw_compression;

class LZW {
  List<int> compress(String input) {
    final Map<String, int> dictionary = {};
    final List<int> output = [];

    // Initialize the dictionary with ASCII values
    for (int i = 0; i < 256; i++) {
      dictionary[String.fromCharCode(i)] = i;
    }

    String current = '';
    for (final char in input.runes) {
      final next = current + String.fromCharCode(char);
      if (dictionary.containsKey(next)) {
        current = next;
      } else {
        output.add(dictionary[current]!);
        dictionary[next] = dictionary.length;
        current = String.fromCharCode(char);
      }
    }

    if (current.isNotEmpty) {
      output.add(dictionary[current]!);
    }

    return output;
  }

  String decompress(List<int> input) {
    final Map<int, String> dictionary = {};
    final StringBuffer output = StringBuffer();

    // Initialize the dictionary with ASCII values
    for (int i = 0; i < 256; i++) {
      dictionary[i] = String.fromCharCode(i);
    }

    String current = dictionary[input.removeAt(0)]!;
    output.write(current);
    for (final index in input) {
      String entry;
      if (dictionary.containsKey(index)) {
        entry = dictionary[index]!;
      } else if (index == dictionary.length) {
        entry = current + current[0];
      } else {
        throw Exception('Invalid compressed data');
      }

      output.write(entry);

      // Add the new entry to the dictionary
      dictionary[dictionary.length] = current + entry[0];
      current = entry;
    }

    return output.toString();
  }
}
