import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_factory.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_go_to.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_java_script.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_named.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_remote_go_to.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_launch.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_uri.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_unknown.dart';
import 'package:test/test.dart';

void main() {
  group('PDActionFactory', () {
    test('creates typed go-to action and destination name accessors work', () {
      final destArray = COSArray()
        ..add(COSInteger(0))
        ..add(COSName.get('XYZ'))
        ..add(COSFloat(12))
        ..add(COSFloat(34))
        ..add(COSFloat(1));
      final dict = COSDictionary()
        ..setName(COSName.s, 'GoTo')
        ..setItem(COSName.d, destArray);

      final action = PDActionFactory.instance.createAction(dict);
      expect(action, isA<PDActionGoTo>());
      final goTo = action as PDActionGoTo;
      expect(goTo.destination, isNotNull);
      expect(goTo.destination, isA<PDPageDestination>());

      goTo.destinationName = 'Chapter1';
      expect(goTo.destinationName, 'Chapter1');
    });

    test('creates URI and Named actions', () {
      final uriDict = COSDictionary()
        ..setName(COSName.s, 'URI')
        ..setString(COSName.uri, 'https://example.com')
        ..setBoolean(COSName.isMap, true);
      final uriAction =
          PDActionFactory.instance.createAction(uriDict) as PDActionURI;
      expect(uriAction.uri, 'https://example.com');
      expect(uriAction.isMap, isTrue);

      final namedDict = COSDictionary()
        ..setName(COSName.s, 'Named')
        ..setName(COSName.n, 'GoToPage');
      final namedAction =
          PDActionFactory.instance.createAction(namedDict) as PDActionNamed;
      expect(namedAction.namedAction, 'GoToPage');
    });

    test('creates remote go-to and launch wrappers for strings', () {
      final remoteDict = COSDictionary()
        ..setName(COSName.s, 'GoToR')
        ..setString(COSName.f, 'other.pdf')
        ..setString(COSName.d, 'NamedDest');
      final remote = PDActionFactory.instance.createAction(remoteDict)
          as PDActionRemoteGoTo;
      expect(remote.fileName, 'other.pdf');
      expect(remote.destinationName, 'NamedDest');

      final launchDict = COSDictionary()
        ..setName(COSName.s, 'Launch')
        ..setString(COSName.f, 'calc.exe');
      final launch = PDActionFactory.instance.createAction(launchDict);
      expect(launch, isA<PDActionLaunch>());
      expect((launch as PDActionLaunch).fileName, 'calc.exe');
    });

    test('falls back to unknown action when subtype is not recognised', () {
      final dict = COSDictionary()
        ..setName(COSName.s, 'CustomAction');
      final action = PDActionFactory.instance.createAction(dict);
      expect(action, isA<PDActionUnknown>());
      expect(action!.subtype, 'CustomAction');
    });
  });

  group('PDAction JavaScript handling', () {
    test('reads script from stream when stored compressed', () {
      final scriptBytes = Uint8List.fromList(utf8.encode('app.alert("hi");'));
      final stream = COSStream()..data = scriptBytes;
      final dict = COSDictionary()
        ..setName(COSName.s, 'JavaScript')
        ..setItem(COSName.js, stream);

      final action = PDActionJavaScript(dictionary: dict);
      expect(action.script, 'app.alert("hi");');

      action.script = null;
      expect(dict.getDictionaryObject(COSName.js), isNull);
      action.script = 'app.alert("bye");';
      expect(action.script, 'app.alert("bye");');
    });
  });
}
