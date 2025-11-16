import '../image/comp_transf_spec.dart';
import '../image/invcomptransf/inv_comp_transf.dart';
import '../integer_spec.dart';
import '../module_spec.dart';
import '../quantization/guard_bits_spec.dart';
import '../quantization/quant_step_size_spec.dart';
import '../quantization/dequantizer/std_dequantizer_params.dart';
import '../quantization/quant_type_spec.dart';
import '../wavelet/synthesis/syn_wt_filter_spec.dart';
import '../roi/max_shift_spec.dart';
import '../roi/rect_roi_spec.dart';

/// Aggregated decoder specifications required by the inverse wavelet stage.
///
/// The original JJ2000 implementation exposes a wide collection of module
/// specifications (quantization, entropy options, precincts, etc.). For the
/// synthesis pipeline we surface the subset currently required by the decoder
/// (decomposition levels, wavelet filters, quantization metadata and component
/// transform choices).
class DecoderSpecs {
  DecoderSpecs({
    required this.dls,
    required this.wfs,
    required this.qts,
    required this.qsss,
    required this.gbs,
    required this.rois,
    required this.cts,
    this.rectRois,
  });

  factory DecoderSpecs.basic(int numTiles, int numComps) {
    final dls = IntegerSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE_COMP)
      ..setDefault(0);
    final wfs = SynWTFilterSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE_COMP);
    final qts = QuantTypeSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE_COMP)
      ..setDefault('reversible');
    final qsss = QuantStepSizeSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE_COMP)
      ..setDefault(
        StdDequantizerParams(
          nStep: <List<double>>[<double>[1.0]],
        ),
      );
    final gbs = GuardBitsSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE_COMP)
      ..setDefault(1);
    final rois = MaxShiftSpec(numTiles, numComps)
      ..setDefault(0);
    final cts = CompTransfSpec(numTiles, numComps, ModuleSpec.SPEC_TYPE_TILE)
      ..setDefault(InvCompTransf.none);
    return DecoderSpecs(
      dls: dls,
      wfs: wfs,
      qts: qts,
      qsss: qsss,
      gbs: gbs,
      rois: rois,
      cts: cts,
    );
  }

  /// Number of decomposition levels specifications (`dls` in JJ2000).
  final IntegerSpec dls;

  /// Synthesis wavelet filters per tile/component (`wfs`).
  final SynWTFilterSpec wfs;

  /// Quantization type selections (`qts`).
  final QuantTypeSpec qts;

  /// Quantization step sizes (`qsss`).
  final QuantStepSizeSpec qsss;

  /// Guard bits (`gbs`).
  final GuardBitsSpec gbs;

  /// ROI max-shift specifications (`rois`).
  final MaxShiftSpec rois;

  /// Optional rectangular ROI definitions (`rectRois`).
  final RectROISpec? rectRois;

  /// Component transform usage (`cts`).
  final CompTransfSpec cts;
}
