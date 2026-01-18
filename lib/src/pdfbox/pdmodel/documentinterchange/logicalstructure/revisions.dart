class Revisions<T> {
  final List<T> _objects = <T>[];
  final List<int> _revisionNumbers = <int>[];

  T getObject(int index) => _objects[index];

  int getRevisionNumber(int index) => _revisionNumbers[index];

  void addObject(T object, int revisionNumber) {
    _objects.add(object);
    _revisionNumbers.add(revisionNumber);
  }

  void setRevisionNumber(T object, int revisionNumber) {
    final index = _objects.indexOf(object);
    if (index >= 0) {
      _revisionNumbers[index] = revisionNumber;
    }
  }

  int get size => _objects.length;

  @override
  String toString() {
    final parts = <String>[];
    for (var i = 0; i < _objects.length; i++) {
      parts.add('object=${_objects[i]}, revisionNumber=${_revisionNumbers[i]}');
    }
    return '{${parts.join('; ')}}';
  }
}
