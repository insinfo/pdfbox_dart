import 'dart:collection';

import '../util/bounding_box.dart';
import 'ligature.dart';

class CharMetric {
  int _characterCode = 0;

  double _wx = 0;
  double _w0x = 0;
  double _w1x = 0;

  double _wy = 0;
  double _w0y = 0;
  double _w1y = 0;

  List<double>? _w;
  List<double>? _w0;
  List<double>? _w1;
  List<double>? _vv;

  String? _name;
  BoundingBox? _boundingBox;
  final List<Ligature> _ligatures = <Ligature>[];

  BoundingBox? get boundingBox => _boundingBox;

  set boundingBox(BoundingBox? boundingBox) {
    _boundingBox = boundingBox;
  }

  BoundingBox? getBoundingBox() => _boundingBox;

  void setBoundingBox(BoundingBox? boundingBox) {
    _boundingBox = boundingBox;
  }

  int get characterCode => _characterCode;

  set characterCode(int characterCode) {
    _characterCode = characterCode;
  }

  int getCharacterCode() => _characterCode;

  void setCharacterCode(int characterCode) {
    _characterCode = characterCode;
  }

  void addLigature(Ligature ligature) {
    _ligatures.add(ligature);
  }

  List<Ligature> get ligatures => UnmodifiableListView(_ligatures);

  List<Ligature> getLigatures() => UnmodifiableListView(_ligatures);

  String? get name => _name;

  set name(String? name) {
    _name = name;
  }

  String? getName() => _name;

  void setName(String? name) {
    _name = name;
  }

  List<double>? get vv => _vv;

  set vv(List<double>? vv) {
    _vv = vv;
  }

  List<double>? getVv() => _vv;

  void setVv(List<double>? vv) {
    _vv = vv;
  }

  List<double>? get w => _w;

  set w(List<double>? w) {
    _w = w;
  }

  List<double>? getW() => _w;

  void setW(List<double>? w) {
    _w = w;
  }

  List<double>? get w0 => _w0;

  set w0(List<double>? w0) {
    _w0 = w0;
  }

  List<double>? getW0() => _w0;

  void setW0(List<double>? w0) {
    _w0 = w0;
  }

  double get w0x => _w0x;

  set w0x(double w0x) {
    _w0x = w0x;
  }

  double getW0x() => _w0x;

  void setW0x(double w0x) {
    _w0x = w0x;
  }

  double get w0y => _w0y;

  set w0y(double w0y) {
    _w0y = w0y;
  }

  double getW0y() => _w0y;

  void setW0y(double w0y) {
    _w0y = w0y;
  }

  List<double>? get w1 => _w1;

  set w1(List<double>? w1) {
    _w1 = w1;
  }

  List<double>? getW1() => _w1;

  void setW1(List<double>? w1) {
    _w1 = w1;
  }

  double get w1x => _w1x;

  set w1x(double w1x) {
    _w1x = w1x;
  }

  double getW1x() => _w1x;

  void setW1x(double w1x) {
    _w1x = w1x;
  }

  double get w1y => _w1y;

  set w1y(double w1y) {
    _w1y = w1y;
  }

  double getW1y() => _w1y;

  void setW1y(double w1y) {
    _w1y = w1y;
  }

  double get wx => _wx;

  set wx(double wx) {
    _wx = wx;
  }

  double getWx() => _wx;

  void setWx(double wx) {
    _wx = wx;
  }

  double get wy => _wy;

  set wy(double wy) {
    _wy = wy;
  }

  double getWy() => _wy;

  void setWy(double wy) {
    _wy = wy;
  }
}
