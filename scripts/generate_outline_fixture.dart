import 'dart:io';

class _Fixture {
  _Fixture(this.path, this.objects);

  final String path;
  final List<String> objects;
}

Future<void> main(List<String> arguments) async {
  final base = arguments.isNotEmpty
      ? arguments.first
      : 'test${Platform.pathSeparator}resources${Platform.pathSeparator}pdfbox${Platform.pathSeparator}pdmodel${Platform.pathSeparator}interactive';

  final fixtures = <_Fixture>[
    _Fixture(
      _resolvePath(base, 'outline_actions.pdf'),
      const <String>[
        '<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>\n',
        '<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Annots [9 0 R 10 0 R 11 0 R] >>\n',
        '<< /Length 0 >>\nstream\nendstream\n',
        '<< /Type /Outlines /First 6 0 R /Last 8 0 R /Count 3 >>\n',
        '<< /Title (Intro) /Parent 5 0 R /Dest [3 0 R /Fit] /Next 7 0 R >>\n',
        '<< /Title (Next Page) /Parent 5 0 R /Prev 6 0 R /Next 8 0 R /A << /S /Named /N /NextPage >> /First 12 0 R /Last 12 0 R /Count -1 >>\n',
        '<< /Title (Example URI) /Parent 5 0 R /Prev 7 0 R /A << /S /URI /URI (https://example.com) >> >>\n',
        '<< /Type /Annot /Subtype /Link /Rect [0 0 100 20] /Dest [3 0 R /Fit] >>\n',
        '<< /Type /Annot /Subtype /Link /Rect [0 0 100 20] /A << /S /Named /N /NextPage >> >>\n',
        '<< /Type /Annot /Subtype /Link /Rect [0 0 100 20] /A << /S /URI /URI (https://example.com) >> >>\n',
        '<< /Title (Hidden child) /Parent 7 0 R >>\n',
      ],
    ),
    _Fixture(
      _resolvePath(base, 'outline_actions_remote.pdf'),
      const <String>[
        '<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>\n',
        '<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Annots [8 0 R] >>\n',
        '<< /Length 0 >>\nstream\nendstream\n',
        '<< /Type /Outlines /First 6 0 R /Last 7 0 R /Count 2 >>\n',
        '<< /Title (Remote) /Parent 5 0 R /A << /S /GoToR /F (remote.pdf) /D [0 /Fit] >> /Next 7 0 R >>\n',
        '<< /Title (Web) /Parent 5 0 R /Prev 6 0 R /A << /S /URI /URI (https://example.org) >> >>\n',
        '<< /Type /Annot /Subtype /Link /Rect [0 0 100 20] /A << /S /GoToR /F (remote.pdf) /D [0 /Fit] >> >>\n',
      ],
    ),
  ];

  for (final fixture in fixtures) {
    final file = File(fixture.path);
    await file.parent.create(recursive: true);
    final pdf = _buildPdf(fixture.objects);
    await file.writeAsString(pdf, flush: true);
    stdout.writeln(
      'Wrote outline fixture (${fixture.objects.length} objects, ${pdf.length} chars) to ${file.path}',
    );
  }
}

String _buildPdf(List<String> objects) {
  const header = '%PDF-1.4\n';
  final objectStrings = <String>[];
  for (var i = 0; i < objects.length; i++) {
    objectStrings.add('${i + 1} 0 obj\n${objects[i]}endobj\n');
  }

  final buffer = StringBuffer()..write(header);
  final offsets = <int>[0];
  var offset = header.length;
  for (final object in objectStrings) {
    offsets.add(offset);
    buffer.write(object);
    offset += object.length;
  }

  final xrefOffset = offset;
  buffer.writeln('xref');
  buffer.writeln('0 ${objects.length + 1}');
  buffer.writeln('0000000000 65535 f ');
  for (var i = 1; i < offsets.length; i++) {
    final formatted = offsets[i].toString().padLeft(10, '0');
    buffer.writeln('$formatted 00000 n ');
  }
  buffer.writeln('trailer');
  buffer.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
  buffer.writeln('startxref');
  buffer.writeln('$xrefOffset');
  buffer.writeln('%%EOF');
  return buffer.toString();
}

String _resolvePath(String base, String name) {
  if (base.endsWith('.pdf')) {
    if (name == 'outline_actions.pdf') {
      return base;
    }
    final directory = File(base).parent.path;
    return _resolvePath(directory, name);
  }
  if (base.endsWith(Platform.pathSeparator)) {
    return '$base$name';
  }
  return '$base${Platform.pathSeparator}$name';
}
