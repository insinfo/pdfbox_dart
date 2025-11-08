import 'cff_charset.dart';

class _ExpertSubsetEntry {
  const _ExpertSubsetEntry(this.sid, this.name);

  final int sid;
  final String name;
}

/// Expert subset charset used when the charset id equals 2.
class CFFExpertSubsetCharset extends EmbeddedCharset {
  CFFExpertSubsetCharset._internal() : super(isCidFont: false) {
    var gid = 0;
    for (final entry in _entries) {
      addSID(gid++, entry.sid, entry.name);
    }
  }

  static CFFExpertSubsetCharset get instance => _instance;

  static final CFFExpertSubsetCharset _instance = CFFExpertSubsetCharset._internal();
}

const List<_ExpertSubsetEntry> _entries = <_ExpertSubsetEntry>[
  _ExpertSubsetEntry(0, '.notdef'),
  _ExpertSubsetEntry(1, 'space'),
  _ExpertSubsetEntry(231, 'dollaroldstyle'),
  _ExpertSubsetEntry(232, 'dollarsuperior'),
  _ExpertSubsetEntry(235, 'parenleftsuperior'),
  _ExpertSubsetEntry(236, 'parenrightsuperior'),
  _ExpertSubsetEntry(237, 'twodotenleader'),
  _ExpertSubsetEntry(238, 'onedotenleader'),
  _ExpertSubsetEntry(13, 'comma'),
  _ExpertSubsetEntry(14, 'hyphen'),
  _ExpertSubsetEntry(15, 'period'),
  _ExpertSubsetEntry(99, 'fraction'),
  _ExpertSubsetEntry(239, 'zerooldstyle'),
  _ExpertSubsetEntry(240, 'oneoldstyle'),
  _ExpertSubsetEntry(241, 'twooldstyle'),
  _ExpertSubsetEntry(242, 'threeoldstyle'),
  _ExpertSubsetEntry(243, 'fouroldstyle'),
  _ExpertSubsetEntry(244, 'fiveoldstyle'),
  _ExpertSubsetEntry(245, 'sixoldstyle'),
  _ExpertSubsetEntry(246, 'sevenoldstyle'),
  _ExpertSubsetEntry(247, 'eightoldstyle'),
  _ExpertSubsetEntry(248, 'nineoldstyle'),
  _ExpertSubsetEntry(27, 'colon'),
  _ExpertSubsetEntry(28, 'semicolon'),
  _ExpertSubsetEntry(249, 'commasuperior'),
  _ExpertSubsetEntry(250, 'threequartersemdash'),
  _ExpertSubsetEntry(251, 'periodsuperior'),
  _ExpertSubsetEntry(253, 'asuperior'),
  _ExpertSubsetEntry(254, 'bsuperior'),
  _ExpertSubsetEntry(255, 'centsuperior'),
  _ExpertSubsetEntry(256, 'dsuperior'),
  _ExpertSubsetEntry(257, 'esuperior'),
  _ExpertSubsetEntry(258, 'isuperior'),
  _ExpertSubsetEntry(259, 'lsuperior'),
  _ExpertSubsetEntry(260, 'msuperior'),
  _ExpertSubsetEntry(261, 'nsuperior'),
  _ExpertSubsetEntry(262, 'osuperior'),
  _ExpertSubsetEntry(263, 'rsuperior'),
  _ExpertSubsetEntry(264, 'ssuperior'),
  _ExpertSubsetEntry(265, 'tsuperior'),
  _ExpertSubsetEntry(266, 'ff'),
  _ExpertSubsetEntry(109, 'fi'),
  _ExpertSubsetEntry(110, 'fl'),
  _ExpertSubsetEntry(267, 'ffi'),
  _ExpertSubsetEntry(268, 'ffl'),
  _ExpertSubsetEntry(269, 'parenleftinferior'),
  _ExpertSubsetEntry(270, 'parenrightinferior'),
  _ExpertSubsetEntry(272, 'hyphensuperior'),
  _ExpertSubsetEntry(300, 'colonmonetary'),
  _ExpertSubsetEntry(301, 'onefitted'),
  _ExpertSubsetEntry(302, 'rupiah'),
  _ExpertSubsetEntry(305, 'centoldstyle'),
  _ExpertSubsetEntry(314, 'figuredash'),
  _ExpertSubsetEntry(315, 'hypheninferior'),
  _ExpertSubsetEntry(158, 'onequarter'),
  _ExpertSubsetEntry(155, 'onehalf'),
  _ExpertSubsetEntry(163, 'threequarters'),
  _ExpertSubsetEntry(320, 'oneeighth'),
  _ExpertSubsetEntry(321, 'threeeighths'),
  _ExpertSubsetEntry(322, 'fiveeighths'),
  _ExpertSubsetEntry(323, 'seveneighths'),
  _ExpertSubsetEntry(324, 'onethird'),
  _ExpertSubsetEntry(325, 'twothirds'),
  _ExpertSubsetEntry(326, 'zerosuperior'),
  _ExpertSubsetEntry(150, 'onesuperior'),
  _ExpertSubsetEntry(164, 'twosuperior'),
  _ExpertSubsetEntry(169, 'threesuperior'),
  _ExpertSubsetEntry(327, 'foursuperior'),
  _ExpertSubsetEntry(328, 'fivesuperior'),
  _ExpertSubsetEntry(329, 'sixsuperior'),
  _ExpertSubsetEntry(330, 'sevensuperior'),
  _ExpertSubsetEntry(331, 'eightsuperior'),
  _ExpertSubsetEntry(332, 'ninesuperior'),
  _ExpertSubsetEntry(333, 'zeroinferior'),
  _ExpertSubsetEntry(334, 'oneinferior'),
  _ExpertSubsetEntry(335, 'twoinferior'),
  _ExpertSubsetEntry(336, 'threeinferior'),
  _ExpertSubsetEntry(337, 'fourinferior'),
  _ExpertSubsetEntry(338, 'fiveinferior'),
  _ExpertSubsetEntry(339, 'sixinferior'),
  _ExpertSubsetEntry(340, 'seveninferior'),
  _ExpertSubsetEntry(341, 'eightinferior'),
  _ExpertSubsetEntry(342, 'nineinferior'),
  _ExpertSubsetEntry(343, 'centinferior'),
  _ExpertSubsetEntry(344, 'dollarinferior'),
  _ExpertSubsetEntry(345, 'periodinferior'),
  _ExpertSubsetEntry(346, 'commainferior'),
];
