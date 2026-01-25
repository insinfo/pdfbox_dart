import 'text_position.dart';

/// This class is a comparator for TextPosition operators. It handles
/// pages with text in different directions by grouping the text based
/// on direction and sorting in that direction. This allows continuous text
/// in a given direction to be more easily grouped together.
class TextPositionComparator {
  int compare(TextPosition pos1, TextPosition pos2) {
    // only compare text that is in the same direction
    int cmp1 = pos1.getDir().compareTo(pos2.getDir());
    if (cmp1 != 0) {
      return cmp1;
    }

    // get the text direction adjusted coordinates
    double x1 = pos1.getXDirAdj();
    double x2 = pos2.getXDirAdj();

    double pos1YBottom = pos1.getYDirAdj();
    double pos2YBottom = pos2.getYDirAdj();

    // note that the coordinates have been adjusted so 0,0 is in upper left
    double pos1YTop = pos1YBottom - pos1.getHeightDir();
    double pos2YTop = pos2YBottom - pos2.getHeightDir();

    double yDifference = (pos1YBottom - pos2YBottom).abs();

    // we will do a simple tolerance comparison
    if (yDifference < .1 ||
        pos2YBottom >= pos1YTop && pos2YBottom <= pos1YBottom ||
        pos1YBottom >= pos2YTop && pos1YBottom <= pos2YBottom) {
      return x1.compareTo(x2);
    } else if (pos1YBottom < pos2YBottom) {
      return -1;
    } else {
      return 1;
    }
  }
}

