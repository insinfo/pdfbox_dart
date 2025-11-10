import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../fontbox/cff/cff_font.dart';
import '../../../fontbox/cff/char_string_path.dart' as cff_path;
import '../../../fontbox/ttf/cmap_lookup.dart';
import '../../../fontbox/ttf/glyph_renderer.dart' as glyph;
import '../../../fontbox/ttf/open_type_font.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_parser.dart';
import '../../../fontbox/util/bounding_box.dart';
import '../../../io/exceptions.dart';
import '../../../io/random_access_read_buffer.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_number.dart';
import '../../util/matrix.dart';
import 'pd_cid_font.dart';
import 'pd_cid_font_parent.dart';
import 'pd_font_descriptor.dart';

/// Concrete CIDFont implementation backed by TrueType outlines (Type 2).
class PDCIDFontType2 extends PDCIDFont {
	PDCIDFontType2(
		COSDictionary dict,
		PDCIDFontParent parent, {
		TrueTypeFont? providedFont,
	})  : _logger = Logger('pdfbox.PDCIDFontType2'),
				super(dict, parent) {
		final fontDescriptor = getFontDescriptor();

		var embedded = false;
		var damaged = false;
		TrueTypeFont? font = providedFont;

		if (font == null && fontDescriptor != null) {
			font = _loadEmbeddedFont(fontDescriptor);
			embedded = font != null;
			damaged = !embedded;
		} else {
			embedded = font != null;
		}

		if (font == null) {
			throw StateError('Embedded TrueType font data is not available for ${parent.name ?? 'untitled font'}');
		}

		_ttf = font;
		_otf = font is OpenTypeFont && font.isSupportedOtf ? font : null;
		_unicodeCmap = _ttf.getUnicodeCmapLookup(isStrict: false);
		_cidToGid = readCidToGidMap();
		_isEmbedded = embedded;
		_isDamaged = damaged;
	}

	final Logger _logger;
	late final TrueTypeFont _ttf;
	OpenTypeFont? _otf;
	CMapLookup? _unicodeCmap;
	List<int>? _cidToGid;
	bool _isEmbedded = true;
	bool _isDamaged = false;
	Matrix? _fontMatrix;
	BoundingBox? _cachedBoundingBox;

	TrueTypeFont get trueTypeFont => _ttf;

	@override
		BoundingBox? get cidFontBoundingBox => _descriptorBoundingBox() ?? _ttf.getFontBBox();

	@override
	List<num>? get cidFontMatrix => null;

	@override
	Matrix getFontMatrix() {
		return _fontMatrix ??= Matrix.fromComponents(0.001, 0, 0, 0.001, 0, 0);
	}

	@override
	BoundingBox getBoundingBox() {
		final cached = _cachedBoundingBox;
		if (cached != null) {
			return cached;
		}
		final descriptorBox = _descriptorBoundingBox();
		if (descriptorBox != null) {
			_cachedBoundingBox = descriptorBox;
			return descriptorBox;
		}
		final fontBox = _ttf.getFontBBox();
		if (fontBox != null) {
			_cachedBoundingBox = fontBox;
			return fontBox;
		}
		final fallback = BoundingBox();
		_cachedBoundingBox = fallback;
		return fallback;
	}

	@override
	double getHeight(int code) {
		final header = _ttf.getHorizontalHeaderTable();
		if (header == null) {
			return 0;
		}
		final unitsPerEm = _ttf.unitsPerEm;
		final ascender = header.ascender.toDouble();
		final descender = header.descender.toDouble();
		if (unitsPerEm <= 0) {
			return ascender - descender;
		}
		return (ascender - descender) * (1000.0 / unitsPerEm);
	}

	@override
	double getWidthFromFont(int code) {
		final gid = codeToGID(code);
		final unitsPerEm = _ttf.unitsPerEm;
		final width = _ttf.getAdvanceWidth(gid).toDouble();
		if (unitsPerEm <= 0 || unitsPerEm == 1000) {
			return width;
		}
		return width * (1000.0 / unitsPerEm);
	}

	@override
	bool isEmbedded() => _isEmbedded;

	@override
	bool isDamaged() => _isDamaged;

	@override
		cff_path.CharStringPath getPath(int code) {
		if (_otf != null && _otf!.isPostScript) {
			return _getPathFromCff(code);
		}
		final glyphTable = _ttf.getGlyphTable();
		if (glyphTable == null) {
			return cff_path.CharStringPath();
		}
		final gid = codeToGID(code);
		if (gid == 0) {
			return cff_path.CharStringPath();
		}
		try {
			final glyph = glyphTable.getGlyph(gid);
					if (glyph == null) {
						return cff_path.CharStringPath();
			}
			final glyphPath = glyph.getPath();
					if (glyphPath.isEmpty) {
						return cff_path.CharStringPath();
			}
			return _glyphPathToCharString(glyphPath);
		} on IOException catch (error, stackTrace) {
			_logger.warning('Failed to read glyph $gid for code $code', error, stackTrace);
			return cff_path.CharStringPath();
		} on StateError catch (error, stackTrace) {
			_logger.warning('State error while reading glyph $gid for code $code', error, stackTrace);
			return cff_path.CharStringPath();
		}
	}

	@override
			cff_path.CharStringPath getNormalizedPath(int code) {
				final path = getPath(code);
				if (path.commands.isEmpty) {
					return cff_path.CharStringPath();
		}
		final unitsPerEm = _ttf.unitsPerEm;
		if (unitsPerEm <= 0 || unitsPerEm == 1000) {
			return path.clone();
		}
		final scale = 1000.0 / unitsPerEm;
			return _scalePath(path, scale);
	}

	@override
	bool hasGlyph(int code) => codeToGID(code) != 0;

	@override
	int codeToCID(int code) => parent.codeToCid(code);

	@override
	int codeToGID(int code) {
		final cid = codeToCID(code);
		final mapping = _cidToGid;
		if (mapping != null) {
			return cid < mapping.length ? mapping[cid] : 0;
		}
		final otf = _otf;
		if (otf != null && otf.isPostScript) {
			return cid;
		}
		return cid < _ttf.numberOfGlyphs ? cid : 0;
	}

	@override
	Uint8List encodeGlyphId(int glyphId) {
		final data = Uint8List(2);
		data[0] = (glyphId >> 8) & 0xff;
		data[1] = glyphId & 0xff;
		return data;
	}

	@override
	Uint8List encode(int unicode) {
			final cmap = _unicodeCmap;
			if (cmap != null) {
			final gid = cmap.getGlyphId(unicode);
			if (gid != 0) {
				return encodeGlyphId(gid);
			}
		}
		final ucs2 = parent.cMapUcs2;
		if (ucs2 != null) {
				final cid = ucs2.toCIDFromInt(unicode);
			if (cid != 0) {
				return encodeGlyphId(cid);
			}
		}
		throw ArgumentError('No glyph for U+${unicode.toRadixString(16).padLeft(4, '0')} in font ${getName()}');
	}

	TrueTypeFont? _loadEmbeddedFont(PDFontDescriptor descriptor) {
		final stream = descriptor.fontFile2Stream;
		if (stream == null) {
			return null;
		}
		final decoded = stream.decode();
		if (decoded == null || decoded.isEmpty) {
			return null;
		}
		final parser = TtfParser(isEmbedded: true);
		try {
			return parser.parse(RandomAccessReadBuffer.fromBytes(decoded));
		} on IOException catch (error, stackTrace) {
			_logger.warning('Failed to parse embedded TrueType font for ${parent.name}', error, stackTrace);
			return null;
		}
	}

	BoundingBox? _descriptorBoundingBox() {
		final descriptor = getFontDescriptor();
		if (descriptor == null) {
			return null;
		}
		final array = descriptor.cosObject.getCOSArray(COSName.fontBBox);
		if (array == null || array.length < 4) {
			return null;
		}
		final values = <double>[];
		for (var index = 0; index < 4; index++) {
			final element = array.getObject(index);
			if (element is COSNumber) {
				values.add(element.doubleValue);
			}
		}
		if (values.length == 4) {
			return BoundingBox.fromValues(values[0], values[1], values[2], values[3]);
		}
		return null;
	}

		cff_path.CharStringPath _getPathFromCff(int code) {
		final otf = _otf;
		if (otf == null || !otf.isPostScript) {
				return cff_path.CharStringPath();
		}
				try {
					final CFFFont cffFont = otf.getCffTable().font;
					final gid = codeToGID(code);
					if (cffFont is CFFType1Font) {
					return cffFont.getType2CharString(gid).getPath().clone();
					}
					if (cffFont is CFFCIDFont) {
						final cid = codeToCID(code);
					return cffFont.getType2CharString(cid).getPath().clone();
					}
		} on IOException catch (error, stackTrace) {
			_logger.warning('Failed to extract CFF path for code $code', error, stackTrace);
		} on StateError catch (error, stackTrace) {
			_logger.warning('State error while extracting CFF path for code $code', error, stackTrace);
		}
			return cff_path.CharStringPath();
	}

		cff_path.CharStringPath _glyphPathToCharString(glyph.GlyphPath glyphPath) {
			final path = cff_path.CharStringPath();
		var currentX = 0.0;
		var currentY = 0.0;

		for (final command in glyphPath.commands) {
				if (command is glyph.MoveToCommand) {
				path.moveTo(command.x, command.y);
				currentX = command.x;
				currentY = command.y;
				} else if (command is glyph.LineToCommand) {
				path.lineTo(command.x, command.y);
				currentX = command.x;
				currentY = command.y;
				} else if (command is glyph.QuadToCommand) {
				final x1 = command.cx;
				final y1 = command.cy;
				final x2 = command.x;
				final y2 = command.y;
				final c1x = currentX + (2.0 / 3.0) * (x1 - currentX);
				final c1y = currentY + (2.0 / 3.0) * (y1 - currentY);
				final c2x = x2 + (2.0 / 3.0) * (x1 - x2);
				final c2y = y2 + (2.0 / 3.0) * (y1 - y2);
			path.curveTo(c1x, c1y, c2x, c2y, x2, y2);
				currentX = x2;
				currentY = y2;
				} else if (command is glyph.CubicToCommand) {
			path.curveTo(
					command.cx1,
					command.cy1,
					command.cx2,
					command.cy2,
					command.x,
					command.y,
				);
				currentX = command.x;
				currentY = command.y;
					} else if (command is glyph.ClosePathCommand) {
						path.closePath();
			}
		}
		return path;
	}

			cff_path.CharStringPath _scalePath(cff_path.CharStringPath path, double scale) {
		if (scale == 1.0) {
			return path.clone();
		}
				final scaled = cff_path.CharStringPath();
			for (final command in path.commands) {
						if (command is cff_path.MoveToCommand) {
				scaled.moveTo(command.x * scale, command.y * scale);
						} else if (command is cff_path.LineToCommand) {
				scaled.lineTo(command.x * scale, command.y * scale);
						} else if (command is cff_path.CurveToCommand) {
				scaled.curveTo(
					command.x1 * scale,
					command.y1 * scale,
					command.x2 * scale,
					command.y2 * scale,
					command.x3 * scale,
					command.y3 * scale,
				);
						} else if (command is cff_path.ClosePathCommand) {
				scaled.closePath();
			}
		}
		return scaled;
	}
}
