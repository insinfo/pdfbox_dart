import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';

Future<void> main() async {
  print('=== GERAÇÃO MELHORADA DE CERTIFICADOS ===\n');

  final workDir = Directory('build/certificados_confiavel').absolute;
  if (workDir.existsSync()) {
    workDir.deleteSync(recursive: true);
  }
  workDir.createSync(recursive: true);
  print('Diretório de trabalho: ${workDir.path}\n');

  // Verificar OpenSSL
  try {
    await _runCmd(['openssl', 'version']);
  } catch (e) {
    print('ERRO: OpenSSL não encontrado. Instale e tente novamente.');
    return;
  }

  // Configurações da CA Raiz
  final rootConfig = '''
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no
default_md = sha256

[req_distinguished_name]
C = BR
ST = Rio de Janeiro
L = Rio das Ostras
O = Prefeitura Municipal de Rio das Ostras
OU = Departamento de TI
CN = CA Raiz PMRO
emailAddress = ti@pmro.gov.br

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:TRUE, pathlen:1
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
''';

  // Configurações do Certificado de Usuário
  final userConfig = '''
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
default_md = sha256

[req_distinguished_name]
C = BR
ST = Rio de Janeiro
L = Rio das Ostras
O = Prefeitura Municipal de Rio das Ostras
OU = Servidor
CN = Isaque Neves Sant Ana
emailAddress = isaque.santana@pmro.gov.br

[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, nonRepudiation, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection, codeSigning
subjectAltName = email:isaque.santana@pmro.gov.br
''';

  // Salvar arquivos de configuração
  File('${workDir.path}/root.cnf').writeAsStringSync(rootConfig);
  File('${workDir.path}/user.cnf').writeAsStringSync(userConfig);

  const senha = 'PMRO@2025!Segura';

  try {
    // PASSO 1: Gerar CA Raiz
    print('[1/7] Gerando chave privada da CA Raiz (4096 bits)...');
    await _runCmd([
      'openssl', 'genrsa',
      '-out', '${workDir.path}/root_ca.key',
      '4096'
    ]);

    print('[2/7] Criando certificado autoassinado da CA Raiz...');
    await _runCmd([
      'openssl', 'req', '-x509', '-new',
      '-key', '${workDir.path}/root_ca.key',
      '-sha256', '-days', '3650',
      '-out', '${workDir.path}/root_ca.crt',
      '-config', '${workDir.path}/root.cnf'
    ]);

    // PASSO 2: Gerar Certificado do Usuário
    print('[3/7] Gerando chave privada do usuário (2048 bits)...');
    await _runCmd([
      'openssl', 'genrsa',
      '-out', '${workDir.path}/user.key',
      '2048'
    ]);

    print('[4/7] Criando requisição de certificado (CSR)...');
    await _runCmd([
      'openssl', 'req', '-new',
      '-key', '${workDir.path}/user.key',
      '-out', '${workDir.path}/user.csr',
      '-config', '${workDir.path}/user.cnf'
    ]);

    print('[5/7] Assinando certificado do usuário com a CA Raiz...');
    await _runCmd([
      'openssl', 'x509', '-req',
      '-in', '${workDir.path}/user.csr',
      '-CA', '${workDir.path}/root_ca.crt',
      '-CAkey', '${workDir.path}/root_ca.key',
      '-CAcreateserial',
      '-out', '${workDir.path}/user.crt',
      '-days', '730', '-sha256',
      '-extfile', '${workDir.path}/user.cnf',
      '-extensions', 'v3_req'
    ]);

    // PASSO 3: Criar PKCS#12 com cadeia completa
    print('[6/7] Empacotando em PKCS#12 com cadeia completa...');
    await _runCmd([
      'openssl', 'pkcs12', '-export',
      '-out', '${workDir.path}/isaque_completo.p12',
      '-inkey', '${workDir.path}/user.key',
      '-in', '${workDir.path}/user.crt',
      '-certfile', '${workDir.path}/root_ca.crt',
      '-name', 'Isaque Neves Sant Ana - PMRO',
      '-passout', 'pass:$senha'
    ]);

    // Copiar para diretório principal
    File('${workDir.path}/root_ca.crt').copySync('CA_RAIZ_PMRO.crt');
    File('${workDir.path}/user.crt').copySync('isaque_santana.crt');
    File('${workDir.path}/isaque_completo.p12').copySync('isaque_santana.p12');

    // PASSO 4: Assinar PDF (pdfbox_dart + OpenSSL)
    print('[7/7] Assinando documento PDF...');
    final Uint8List basePdf = _createSimplePdf();

    final PDSignature signature = PDSignature()
      ..setFilter(PDSignature.filterAdobePpklite)
      ..setSubFilter(PDSignature.subFilterAdbePkcs7Detached)
      ..setReason('Documento oficial da PMRO')
      ..setLocation('Rio das Ostras, RJ, Brasil')
      ..setContactInfo('isaque.santana@pmro.gov.br')
      ..setName('Isaque Neves Sant Ana')
      ..setSignDate(DateTime.now().toUtc());

    final PdfExternalSigningResult prepared =
        await PdfExternalSigning.preparePdf(
      inputBytes: basePdf,
      pageNumber: 1,
      bounds: PDRectangle(50, 250, 250, 80),
      fieldName: 'AssinaturaIsaque',
      signature: signature,
    );

    final Uint8List signedPdf = await _signWithOpenSsl(
      preparedPdfBytes: prepared.preparedPdfBytes,
      fieldName: 'AssinaturaIsaque',
      keyPath: '${workDir.path}/user.key',
      certPath: '${workDir.path}/user.crt',
      chainPath: '${workDir.path}/root_ca.crt',
    );

    File('documento_assinado_pmro.pdf').writeAsBytesSync(signedPdf);

    // Verificação
    print('\n=== VERIFICAÇÃO ===');
    final verifyResult = await Process.run(
      'openssl',
      ['verify', '-CAfile', 'CA_RAIZ_PMRO.crt', 'isaque_santana.crt'],
      stdoutEncoding: systemEncoding,
    );
    print('Verificação OpenSSL: ${verifyResult.stdout}');

    print('\n=== SUCESSO ===');
    print('Arquivos gerados:');
    print('  📜 CA_RAIZ_PMRO.crt         → Importar no Adobe como Raiz Confiável');
    print('  📄 isaque_santana.crt       → Certificado do usuário');
    print('  🔐 isaque_santana.p12       → Para assinar documentos (senha: $senha)');
    print('  📝 documento_assinado_pmro.pdf');
    print('\n⚠️  IMPORTANTE:');
    print('   1. Abra o Adobe Reader/Acrobat');
    print('   2. Editar → Preferências → Assinaturas');
    print('   3. Identidades e Certificados Confiáveis → Mais...');
    print('   4. Certificados Confiáveis → Importar');
    print('   5. Selecione CA_RAIZ_PMRO.crt');
    print('   6. Marque: "Usar como Raiz Confiável" + "Assinaturas"');

  } catch (e, s) {
    print('\n❌ ERRO: $e');
    print(s);
  }
}

Future<void> _runCmd(List<String> args) async {
  final result = await Process.run(
    args[0],
    args.sublist(1),
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );
  
  if (result.exitCode != 0) {
    throw Exception('${args[0]} falhou: ${result.stderr}');
  }
  
  if (result.stdout.toString().trim().isNotEmpty) {
    print('  → ${result.stdout.toString().trim()}');
  }
}

Uint8List _createSimplePdf() {
  final PDDocument document = PDDocument();
  final PDPage page = PDPage();
  document.addPage(page);

  final PDPageContentStream stream = PDPageContentStream(document, page);
  final COSName fontResource = COSName.get('F1');
  stream.resources.registerStandard14Font(fontResource, 'Helvetica');

  stream.beginText();
  stream.setNonStrokingColorRgb(0, 0, 0);
  stream.setFont(fontResource, 11);
  stream.setAutoLeading(13);
  stream.newLineAtOffset(50, 200);
  stream.showParagraph(
    'PREFEITURA MUNICIPAL DE RIO DAS OSTRAS\n\n'
    'Documento Oficial Assinado Digitalmente\n\n'
    'Assinante: Isaque Neves Sant Ana\n'
    'Cargo: Servidor Público\n'
    'Data: ${DateTime.now().toString().substring(0, 19)}',
    trailingLineBreaks: 0,
  );
  stream.endText();

  stream.close();
  final Uint8List out = document.saveToBytes();
  document.close();
  return out;
}

Future<Uint8List> _signWithOpenSsl({
  required Uint8List preparedPdfBytes,
  required String fieldName,
  required String keyPath,
  required String certPath,
  String? chainPath,
}) async {
  final Directory tempDir =
      await Directory.systemTemp.createTemp('pdfbox_dart_external_sign_');
  try {
    final List<int> ranges =
        PdfExternalSigning.extractByteRange(preparedPdfBytes);
    final int start1 = ranges[0];
    final int len1 = ranges[1];
    final int start2 = ranges[2];
    final int len2 = ranges[3];

    final List<int> part1 = preparedPdfBytes.sublist(start1, start1 + len1);
    final List<int> part2 = preparedPdfBytes.sublist(start2, start2 + len2);

    final String dataToSignPath =
        '${tempDir.path}/data_to_sign_$fieldName.bin';
    final IOSink sink = File(dataToSignPath).openWrite();
    sink.add(part1);
    sink.add(part2);
    await sink.close();

    final String sigPath = '${tempDir.path}/signature_$fieldName.p7s';
    final List<String> args = <String>[
      'smime',
      '-sign',
      '-binary',
      '-in',
      dataToSignPath.replaceAll('/', Platform.pathSeparator),
      '-signer',
      certPath.replaceAll('/', Platform.pathSeparator),
      '-inkey',
      keyPath.replaceAll('/', Platform.pathSeparator),
      '-out',
      sigPath.replaceAll('/', Platform.pathSeparator),
      '-outform',
      'DER',
    ];
    if (chainPath != null) {
      args.addAll(<String>[
        '-certfile',
        chainPath.replaceAll('/', Platform.pathSeparator),
      ]);
    }

    await _runCmd(['openssl', ...args]);

    final Uint8List sigBytes =
        Uint8List.fromList(File(sigPath).readAsBytesSync());
    return PdfExternalSigning.embedSignature(
      preparedPdfBytes: preparedPdfBytes,
      pkcs7Bytes: sigBytes,
    );
  } finally {
    await tempDir.delete(recursive: true);
  }
}

