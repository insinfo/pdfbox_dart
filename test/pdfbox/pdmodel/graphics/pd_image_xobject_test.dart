import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/markedcontent/pd_property_list.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/form/pd_form_xobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pattern/pd_abstract_pattern.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pd_post_script_xobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pdxobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/resource_cache.dart';

void main() {
  group('PDImageXObject', () {
    test('metadata extraction and caching', () {
      final stream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.image.name)
        ..setInt(COSName.width, 16)
        ..setInt(COSName.height, 32)
        ..setInt(COSName.bitsPerComponent, 8)
        ..setName(COSName.colorSpace, COSName.deviceRGB.name);

      final xObjects = COSDictionary();
      final object = COSObject(4, 0, stream);
      xObjects[COSName('Im1')] = object;

      final resourcesDictionary = COSDictionary()..[COSName.xObject] = xObjects;
      final cache = ResourceCache();
      final resources = PDResources(resourcesDictionary, cache);

      final xObject = resources.getXObject(COSName('Im1'));
      expect(xObject, isA<PDImageXObject>());

      final image = xObject! as PDImageXObject;
      expect(image.width, 16);
      expect(image.height, 32);
      expect(image.bitsPerComponent, 8);
      expect(image.colorSpace?.name, 'DeviceRGB');
      expect(image.decode, isNull);

      final cached = resources.getXObject(COSName('Im1'));
      expect(identical(xObject, cached), isTrue);
    });
  });

  group('PDResources shading', () {
    test('shading lookup uses cache', () {
      final shadingDictionary = COSDictionary()
        ..setInt(COSName.shadingType, 2)
        ..setItem(COSName.colorSpace, COSName.deviceGray);

      final shadingContainer = COSDictionary();
      final shadingObject = COSObject(9, 0, shadingDictionary);
      shadingContainer[COSName('Sh1')] = shadingObject;

      final resourcesDictionary = COSDictionary()
        ..[COSName.shading] = shadingContainer;
      final cache = ResourceCache();
      final resources = PDResources(resourcesDictionary, cache);

      final shading = resources.getShading(COSName('Sh1'));
      expect(shading, isNotNull);
      expect(shading!.shadingType, 2);
      expect(shading.colorSpace?.name, 'DeviceGray');

      final cached = resources.getShading(COSName('Sh1'));
      expect(identical(shading, cached), isTrue);
    });
  });

  group('PDResources extended caching', () {
    test('pattern lookup caches shading patterns', () {
      final shadingDictionary = COSDictionary()
        ..setInt(COSName.shadingType, 2)
        ..setItem(COSName.colorSpace, COSName.deviceRGB);
      final patternDictionary = COSDictionary()
        ..setInt(COSName.patternType, 2)
        ..setItem(COSName.shading, shadingDictionary);

      final patternContainer = COSDictionary();
      final patternObject = COSObject(12, 0, patternDictionary);
      patternContainer[COSName('Pat1')] = patternObject;

      final resourcesDictionary = COSDictionary()
        ..[COSName.pattern] = patternContainer;
      final cache = ResourceCache();
      final resources = PDResources(resourcesDictionary, cache);

      final pattern = resources.getPattern(COSName('Pat1'));
      expect(pattern, isA<PDShadingPattern>());
      final shading = (pattern as PDShadingPattern).shading;
      expect(shading, isNotNull);
      expect(shading!.colorSpace?.name, 'DeviceRGB');

      final cached = resources.getPattern(COSName('Pat1'));
      expect(identical(pattern, cached), isTrue);
    });

    test('property list lookup caches optional content groups', () {
      final propertyDictionary = COSDictionary()
        ..setItem(COSName.type, COSName.ocg)
        ..setString(COSName.nameKey, 'Layer 1');

      final propertiesContainer = COSDictionary();
      final propertyObject = COSObject(21, 0, propertyDictionary);
      propertiesContainer[COSName('MC0')] = propertyObject;

      final resourcesDictionary = COSDictionary()
        ..[COSName.properties] = propertiesContainer;
      final cache = ResourceCache();
      final resources = PDResources(resourcesDictionary, cache);

      final propertyList = resources.getPropertyList(COSName('MC0'));
      expect(propertyList, isA<PDOptionalContentGroup>());
      expect((propertyList as PDOptionalContentGroup).name, 'Layer 1');

      final cached = resources.getPropertyList(COSName('MC0'));
      expect(identical(propertyList, cached), isTrue);
    });

    test('form XObject inherits document resource cache', () {
      final formStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.form.name);

      final xObjectDict = COSDictionary();
      final formObject = COSObject(30, 0, formStream);
      xObjectDict[COSName('Fm1')] = formObject;

      final resourcesDictionary = COSDictionary()
        ..[COSName.xObject] = xObjectDict;
      final cache = ResourceCache();
      final resources = PDResources(resourcesDictionary, cache);

      final xObject = resources.getXObject(COSName('Fm1'));
      expect(xObject, isA<PDFormXObject>());
      final form = xObject! as PDFormXObject;
      expect(form.resourceCache, same(cache));
    });

    test('PostScript XObject is recognised', () {
      final psStream = COSStream()
        ..setName(COSName.type, COSName.xObject.name)
        ..setName(COSName.subtype, COSName.ps.name);

      final xObjectDict = COSDictionary();
      xObjectDict[COSName('PS1')] = COSObject(45, 0, psStream);

      final resourcesDictionary = COSDictionary()
        ..[COSName.xObject] = xObjectDict;
      final resources = PDResources(resourcesDictionary, ResourceCache());

      final xObject = resources.getXObject(COSName('PS1'));
      expect(xObject, isA<PDPostScriptXObject>());
    });
  });
}
