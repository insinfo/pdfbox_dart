import 'package:test/test.dart';

import 'package:pdfbox_dart/src/jj2000/j2k/module_spec.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/quantization/quant_step_size_spec.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/quantization/dequantizer/std_dequantizer_params.dart';
import 'package:pdfbox_dart/src/jj2000/j2k/util/parameter_list.dart';

void main() {
  group('QuantStepSizeSpec', () {
    test('parses default value from parameters', () {
      final params = ParameterList(null)..put('Qstep', '0.5');
      final spec = QuantStepSizeSpec.fromParameters(
        1,
        1,
        ModuleSpec.SPEC_TYPE_TILE_COMP,
        params,
      );
      final StdDequantizerParams? specParams = spec.getDefault();
      expect(specParams, isNotNull);
      expect(specParams!.nStep, isNotNull);
      expect(specParams.nStep![0][0], closeTo(0.5, 1e-6));
    });

    test('uses defaults when per tile/component unspecified', () {
      final defaults = ParameterList(null)..put('Qstep', '0.75');
      final params = ParameterList(defaults)
        ..put('Qstep', 't0 0.5 c0 0.25');
      final spec = QuantStepSizeSpec.fromParameters(
        2,
        2,
        ModuleSpec.SPEC_TYPE_TILE_COMP,
        params,
      );
      expect(spec.getTileDef(0)!.nStep![0][0], closeTo(0.5, 1e-6));
      expect(spec.getCompDef(0)!.nStep![0][0], closeTo(0.25, 1e-6));
      expect(spec.getTileCompVal(0, 0)!.nStep![0][0], closeTo(0.5, 1e-6));
      expect(spec.getTileCompVal(1, 1)!.nStep![0][0], closeTo(0.75, 1e-6));
      expect(spec.getDefault()!.nStep![0][0], closeTo(0.75, 1e-6));
    });
  });
}
