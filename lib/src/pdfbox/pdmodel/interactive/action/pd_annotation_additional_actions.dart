import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_base.dart';
import 'pd_action.dart';
import 'pd_action_factory.dart';

/// This class represents an annotation's dictionary of actions
/// that occur due to events.
class PDAnnotationAdditionalActions implements COSObjectable {
  final COSDictionary _actions;

  /// Default constructor.
  PDAnnotationAdditionalActions([COSDictionary? actions])
      : _actions = actions ?? COSDictionary();

  /// Convert this standard java object to a COS object.
  @override
  COSDictionary get cosObject => _actions;

  /// This will get an action to be performed when the cursor
  /// enters the annotation's active area.
  PDAction? get e {
    COSDictionary? e = _actions.getCOSDictionary(COSName.e);
    return e != null ? PDActionFactory.instance.createAction(e) : null;
  }

  /// This will set an action to be performed when the cursor
  /// enters the annotation's active area.
  set e(PDAction? e) {
    _actions.setItem(COSName.e, e);
  }

  /// This will get an action to be performed when the cursor
  /// exits the annotation's active area.
  PDAction? get x {
    COSDictionary? x = _actions.getCOSDictionary(COSName.x);
    return x != null ? PDActionFactory.instance.createAction(x) : null;
  }

  /// This will set an action to be performed when the cursor
  /// exits the annotation's active area.
  set x(PDAction? x) {
    _actions.setItem(COSName.x, x);
  }

  /// This will get an action to be performed when the mouse button
  /// is pressed inside the annotation's active area.
  PDAction? get d {
    COSDictionary? d = _actions.getCOSDictionary(COSName.d);
    return d != null ? PDActionFactory.instance.createAction(d) : null;
  }

  /// This will set an action to be performed when the mouse button
  /// is pressed inside the annotation's active area.
  set d(PDAction? d) {
    _actions.setItem(COSName.d, d);
  }

  /// This will get an action to be performed when the mouse button
  /// is released inside the annotation's active area.
  PDAction? get u {
    COSDictionary? u = _actions.getCOSDictionary(COSName.u);
    return u != null ? PDActionFactory.instance.createAction(u) : null;
  }

  /// This will set an action to be performed when the mouse button
  /// is released inside the annotation's active area.
  set u(PDAction? u) {
    _actions.setItem(COSName.u, u);
  }

  /// This will get an action to be performed when the annotation
  /// receives the input focus.
  PDAction? get fo {
    COSDictionary? fo = _actions.getCOSDictionary(COSName.fo);
    return fo != null ? PDActionFactory.instance.createAction(fo) : null;
  }

  /// This will set an action to be performed when the annotation
  /// receives the input focus.
  set fo(PDAction? fo) {
    _actions.setItem(COSName.fo, fo);
  }

  /// This will get an action to be performed when the annotation
  /// loses the input focus.
  PDAction? get bl {
    COSDictionary? bl = _actions.getCOSDictionary(COSName.bl);
    return bl != null ? PDActionFactory.instance.createAction(bl) : null;
  }

  /// This will set an action to be performed when the annotation
  /// loses the input focus.
  set bl(PDAction? bl) {
    _actions.setItem(COSName.bl, bl);
  }

  /// This will get an action to be performed when the page containing
  /// the annotation is opened.
  PDAction? get po {
    COSDictionary? po = _actions.getCOSDictionary(COSName.po);
    return po != null ? PDActionFactory.instance.createAction(po) : null;
  }

  /// This will set an action to be performed when the page containing
  /// the annotation is opened.
  set po(PDAction? po) {
    _actions.setItem(COSName.po, po);
  }

  /// This will get an action to be performed when the page containing
  /// the annotation is closed.
  PDAction? get pc {
    COSDictionary? pc = _actions.getCOSDictionary(COSName.pc);
    return pc != null ? PDActionFactory.instance.createAction(pc) : null;
  }

  /// This will set an action to be performed when the page containing
  /// the annotation is closed.
  set pc(PDAction? pc) {
    _actions.setItem(COSName.pc, pc);
  }

  /// This will get an action to be performed when the page containing
  /// the annotation becomes visible.
  PDAction? get pv {
    COSDictionary? pv = _actions.getCOSDictionary(COSName.pv);
    return pv != null ? PDActionFactory.instance.createAction(pv) : null;
  }

  /// This will set an action to be performed when the page containing
  /// the annotation becomes visible.
  set pv(PDAction? pv) {
    _actions.setItem(COSName.pv, pv);
  }

  /// This will get an action to be performed when the page containing
  /// the annotation is no longer visible.
  PDAction? get pi {
    COSDictionary? pi = _actions.getCOSDictionary(COSName.pi);
    return pi != null ? PDActionFactory.instance.createAction(pi) : null;
  }

  /// This will set an action to be performed when the page containing
  /// the annotation is no longer visible.
  set pi(PDAction? pi) {
    _actions.setItem(COSName.pi, pi);
  }
}
