import 'dart:collection';

import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_integer.dart';
import '../../cos/cos_name.dart';
import '../pd_document.dart';
import 'pd_number_tree_node.dart';
import 'pd_page_label_range.dart';

/// Represents the page label dictionary of a document.
class PDPageLabels implements COSObjectable {
  PDPageLabels(PDDocument document)
      : this._(() => document.numberOfPages);

  PDPageLabels._(int Function() pageCountProvider)
      : _pageCountProvider = pageCountProvider,
        _labels = SplayTreeMap<int, PDPageLabelRange>() {
    final defaultRange = PDPageLabelRange()
      ..style = PDPageLabelRange.styleDecimal;
    _labels[0] = defaultRange;
  }

  PDPageLabels.fromDictionary(PDDocument document, COSDictionary? dictionary)
      : this.fromDictionaryWithPageCount(
          () => document.numberOfPages,
          dictionary,
        );

  PDPageLabels.fromDictionaryWithPageCount(
    int Function() pageCountProvider,
    COSDictionary? dictionary,
  )   : _pageCountProvider = pageCountProvider,
        _labels = SplayTreeMap<int, PDPageLabelRange>() {
    final defaultRange = PDPageLabelRange()
      ..style = PDPageLabelRange.styleDecimal;
    _labels[0] = defaultRange;
    if (dictionary == null) {
      return;
    }
    final root = PDNumberTreeNode<PDPageLabelRange>(
      dictionary: dictionary,
      valueFactory: (COSBase base) {
        if (base is COSDictionary) {
          return PDPageLabelRange(base);
        }
        return null;
      },
    );
    _populateFromTree(root);
  }

  int Function() _pageCountProvider;
  final SplayTreeMap<int, PDPageLabelRange> _labels;

  int get pageRangeCount => _labels.length;

  PDPageLabelRange? getPageLabelRange(int startPage) => _labels[startPage];

  void setLabelItem(int startPage, PDPageLabelRange range) {
    if (startPage < 0) {
      throw ArgumentError.value(startPage, 'startPage', 'must be >= 0');
    }
    _labels[startPage] = range;
  }

  @override
  COSDictionary get cosObject {
    final array = COSArray();
    _labels.forEach((key, value) {
      array.add(COSInteger(key));
      array.add(value);
    });
    final dict = COSDictionary();
    dict.setItem(COSName.nums, array);
    return dict;
  }

  Map<String, int> getPageIndicesByLabels() {
    final labelMap = <String, int>{};
    final numberOfPages = _pageCountProvider();
    _computeLabels((pageIndex, label) {
      labelMap[label] = pageIndex;
    }, numberOfPages);
    return labelMap;
  }

  List<String?> getLabelsByPageIndices() {
    final numberOfPages = _pageCountProvider();
    final labels = List<String?>.filled(numberOfPages, null);
    _computeLabels((pageIndex, label) {
      if (pageIndex < numberOfPages) {
        labels[pageIndex] = label;
      }
    }, numberOfPages);
    return labels;
  }

  Set<int> getPageIndices() => SplayTreeSet<int>.of(_labels.keys);

  void setPageCountProvider(int Function() provider) {
    _pageCountProvider = provider;
  }

  void _populateFromTree(PDNumberTreeNode<PDPageLabelRange> node) {
    final children = node.kids;
    if (children != null) {
      for (final child in children) {
        _populateFromTree(child);
      }
      return;
    }
    final numbers = node.numbers;
    if (numbers == null) {
      return;
    }
    numbers.forEach((key, value) {
      if (key >= 0 && value != null) {
        _labels[key] = value;
      }
    });
  }

  void _computeLabels(LabelHandler handler, int numberOfPages) {
    if (_labels.isEmpty) {
      return;
    }
    final iterator = _labels.entries.iterator;
    if (!iterator.moveNext()) {
      return;
    }
    var currentEntry = iterator.current;
    var pageIndex = 0;
    while (iterator.moveNext()) {
      final nextEntry = iterator.current;
      final numPages = nextEntry.key - currentEntry.key;
      if (numPages > 0) {
        final generator = _LabelGenerator(currentEntry.value, numPages);
        while (generator.hasNext()) {
          if (pageIndex >= numberOfPages) {
            return;
          }
          handler(pageIndex, generator.next());
          pageIndex++;
        }
      }
      currentEntry = nextEntry;
    }
    final remaining = numberOfPages - currentEntry.key;
    if (remaining <= 0) {
      return;
    }
    final generator = _LabelGenerator(currentEntry.value, remaining);
    while (generator.hasNext()) {
      if (pageIndex >= numberOfPages) {
        return;
      }
      handler(pageIndex, generator.next());
      pageIndex++;
    }
  }
}

typedef LabelHandler = void Function(int pageIndex, String label);

class _LabelGenerator {
  _LabelGenerator(this._range, this._count);

  final PDPageLabelRange _range;
  final int _count;
  int _currentPage = 0;

  bool hasNext() => _currentPage < _count;

  String next() {
    if (!hasNext()) {
      throw StateError('No more labels available');
    }
    final buffer = StringBuffer();
    final prefix = _range.prefix;
    if (prefix != null) {
      final nullIndex = prefix.indexOf(String.fromCharCode(0));
      if (nullIndex >= 0) {
        buffer.write(prefix.substring(0, nullIndex));
      } else {
        buffer.write(prefix);
      }
    }
    final style = _range.style;
    if (style != null) {
      buffer.write(
        _formatNumber(_range.start + _currentPage, style),
      );
    }
    _currentPage++;
    return buffer.toString();
  }

  static String _formatNumber(int value, String style) {
    switch (style) {
      case PDPageLabelRange.styleDecimal:
        return value.toString();
      case PDPageLabelRange.styleLettersLower:
        return _makeLetterLabel(value).toLowerCase();
      case PDPageLabelRange.styleLettersUpper:
        return _makeLetterLabel(value).toUpperCase();
      case PDPageLabelRange.styleRomanLower:
        return _makeRomanLabel(value);
      case PDPageLabelRange.styleRomanUpper:
        return _makeRomanLabel(value).toUpperCase();
      default:
        return value.toString();
    }
  }

  static const List<List<String>> _romanDigits = <List<String>>[
    <String>['', 'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix'],
    <String>['', 'x', 'xx', 'xxx', 'xl', 'l', 'lx', 'lxx', 'lxxx', 'xc'],
    <String>['', 'c', 'cc', 'ccc', 'cd', 'd', 'dc', 'dcc', 'dccc', 'cm'],
  ];

  static String _makeRomanLabel(int number) {
    var value = number;
    final parts = <String>[];
    var power = 0;
    while (power < _romanDigits.length && value > 0) {
      parts.insert(0, _romanDigits[power][value % 10]);
      value ~/= 10;
      power++;
    }
    if (value > 0) {
      final buffer = StringBuffer();
      for (var i = 0; i < value; i++) {
        buffer.write('m');
      }
      parts.insert(0, buffer.toString());
    }
    return parts.join();
  }

  static String _makeLetterLabel(int number) {
    final sign = _signum(number % 26);
    final numLetters = number ~/ 26 + sign;
    final base =
        number % 26 + 26 * (1 - sign) + 'a'.codeUnitAt(0) - 1;
    final buffer = StringBuffer();
    for (var i = 0; i < numLetters; i++) {
      buffer.writeCharCode(base);
    }
    return buffer.toString();
  }

  static int _signum(int value) => value == 0 ? 0 : (value > 0 ? 1 : -1);
}
