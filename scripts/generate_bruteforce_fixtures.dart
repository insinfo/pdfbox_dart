import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() {
  final outputDir = Directory('test/resources/pdfparser');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  _writeHybridPdf(outputDir);
  _writeBrokenXrefStreamPdf(outputDir);
  stdout.writeln('Fixtures generated in ${outputDir.path}');
}

void _writeHybridPdf(Directory dir) {
  final streamContent = 'BT /F1 12 Tf 10 10 Td (Hello) Tj ET';
  final objectStreamHeader = '7 0 ';
  final objectStreamBody = '<< /Type /XObject /Subtype /Form >>';
  final objectStreamData = '$objectStreamHeader$objectStreamBody';

  final objects = <String>[
    '1 0 obj\n'
        '<< /Type /Catalog /Pages 2 0 R >>\n'
        'endobj',
    '2 0 obj\n'
        '<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n'
        'endobj',
    '3 0 obj\n'
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] '
        '/Resources << /XObject << /Form1 7 0 R >> >> /Contents 5 0 R >>\n'
        'endobj',
    '4 0 obj\n'
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n'
        'endobj',
    '5 0 obj\n'
        '<< /Length ${streamContent.codeUnits.length} >>\n'
        'stream\n'
        '$streamContent\n'
        'endstream\n'
        'endobj',
    '6 0 obj\n'
        '<< /Type /ObjStm /N 1 /First ${objectStreamHeader.codeUnits.length} '
        '/Length ${objectStreamData.codeUnits.length} >>\n'
        'stream\n'
        '$objectStreamData\n'
        'endstream\n'
        'endobj',
  ];

  final buffer = StringBuffer('%PDF-1.5\n');
  for (final entry in objects) {
    buffer.writeln(entry);
  }

  final xrefOffset = buffer.toString().codeUnits.length;
  buffer
    ..writeln('xref')
    ..writeln('0 8');
  for (var i = 0; i < 8; i++) {
    if (i == 0) {
      buffer.writeln('0000000000 65535 f ');
    } else {
      buffer.writeln('0000000000 00000 n ');
    }
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size 8 /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln('$xrefOffset')
    ..writeln('%%EOF');

  final bytes = ascii.encode(buffer.toString());
  final file = File('${dir.path}/hybrid_broken_xref.pdf');
  file.writeAsBytesSync(bytes);
}

void _writeBrokenXrefStreamPdf(Directory dir) {
  final builder = BytesBuilder();
  void writeString(String value) => builder.add(ascii.encode(value));

  writeString('%PDF-1.5\n');

  final offsets = <int>[];

  void addPlainObject(String content) {
    offsets.add(builder.length);
    writeString(content);
    if (!content.endsWith('\n')) {
      writeString('\n');
    }
  }

  addPlainObject('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  addPlainObject(
      '2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n');
  addPlainObject(
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>\nendobj\n');

  final contentData = ascii.encode('BT /F1 12 Tf 20 20 Td (World) Tj ET');
  offsets.add(builder.length);
  writeString('4 0 obj\n<< /Length ${contentData.length} >>\nstream\n');
  builder.add(contentData);
  writeString('\nendstream\nendobj\n');

  final xrefStreamOffset = builder.length;

  final entryOffsets = <int>[
    0,
    offsets[0],
    offsets[1],
    offsets[2],
    offsets[3],
    xrefStreamOffset
  ];
  final data = <int>[];
  void addEntry(int type, int field2, int field3) {
    data.add(type & 0xff);
    data.add((field2 >> 8) & 0xff);
    data.add(field2 & 0xff);
    data.add(field3 & 0xff);
  }

  addEntry(0, 0, 0); // free object
  for (var i = 1; i <= 4; i++) {
    addEntry(1, entryOffsets[i], 0);
  }
  addEntry(1, xrefStreamOffset, 0); // xref stream entry

  final length = data.length;
  writeString('5 0 obj\n');
  writeString(
      '<< /Type /XRef /Size 6 /Index [0 6] /W [1 2 1] /Root 1 0 R /Length $length >>\n');
  writeString('stream\n');
  builder.add(data);
  writeString('\nendstream\nendobj\n');

  const fakeStartXref = 42;
  writeString('startxref\n');
  writeString('$fakeStartXref\n');
  writeString('%%EOF\n');

  final file = File('${dir.path}/broken_xref_stream.pdf');
  file.writeAsBytesSync(builder.toBytes());
}
