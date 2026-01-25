// Aqui está um script Dart completo que executa todo o fluxo solicitado:
// Cria uma Autoridade Certificadora (CA) Raiz para a "Prefeitura Municipal de Rio das Ostras".
// Emite um certificado de usuário para "Isaque Neves Sant'Ana", assinado pela CA Raiz.
// Empacota a chave privada e o certificado do usuário em um arquivo PFX (.p12).
// Usa a biblioteca dart_pdf (conforme sua documentação) para criar um PDF simples.
// Assina digitalmente esse PDF usando o certificado PFX (.p12) gerado.
// Salva os artefatos (certificados e o PDF assinado) no disco.
// Este script utiliza as funcionalidades de criptografia e X.509 da sua própria biblioteca pdfbox_dart
//(que contém basic_utils, pointycastle, etc.) e as funcionalidades de assinatura de PDF da sua biblioteca dart_pdf.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/basic_utils.dart';
import 'package:pdfbox_dart/qr.dart' as qr;
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/external_pdf_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/pdf_signature_validator.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/api.dart' hide Padding;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

/// Retorna um gerador de números aleatórios seguros.
SecureRandom getSecureRandom() {
  final secureRandom = FortunaRandom();
  final seedSource = Random.secure();
  final seeds = <int>[];
  for (int i = 0; i < 32; i++) {
    seeds.add(seedSource.nextInt(256));
  }
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}

/// Gera um par de chaves RSA
AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRsaKeyPair(
    SecureRandom secureRandom,
    {int bitLength = 2048}) {
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), bitLength, 64),
        secureRandom));
  return keyGen.generateKeyPair();
}

// --- Execução Principal ---

Future<void> main() async {
  print('--- INICIANDO TESTE DE ASSINATURA DE PDF ---');

  // --- 1. GERAÇÃO DA CA RAIZ ---
  print('[PASSO 1/7] Gerando par de chaves da CA Raiz (4096 bits)...');
  final secureRandom = getSecureRandom();
  final rootCaKeyPair = generateRsaKeyPair(secureRandom, bitLength: 4096);
  final RSAPrivateKey rootCaPrivateKey = rootCaKeyPair.privateKey;
  final RSAPublicKey rootCaPublicKey = rootCaKeyPair.publicKey;

  // Informações da CA Raiz
  final caSubject = {
    'C': 'BR',
    'ST': 'RJ',
    'L': 'Rio das Ostras',
    'O': 'Prefeitura Municipal de Rio das Ostras',
    'CN': 'Autoridade Certificadora Raiz PMRO G1',
  };

  print('[PASSO 2/9] Gerando CSR para a CA Raiz...');
  // É preciso criar um CSR primeiro, conforme a assinatura do método
  final rootCaCsrPem = X509Utils.generateRsaCsrPem(
    caSubject,
    rootCaPrivateKey,
    rootCaPublicKey,
    signingAlgorithm: 'SHA-256',
  );

  print('[PASSO 3/9] Gerando certificado autoassinado da CA Raiz...');
  final rootCaCertPem = X509Utils.generateSelfSignedCertificate(
    rootCaPrivateKey, // A chave para assinar
    rootCaCsrPem, // O CSR a ser assinado
    365 * 10, // Validade em dias
    issuer: caSubject, // O Emissor é a própria CA
    serialNumber: '1',
    notBefore: DateTime.now().toUtc(), // Parâmetro correto
    // O parâmetro na biblioteca é 'cA' (maiúsculo)
    cA: true, // Define que é uma CA
    keyUsage: [
      // Enums corrigidos para maiúsculas
      KeyUsage.KEY_CERT_SIGN, // Pode assinar certificados
      KeyUsage.CRL_SIGN, // Pode assinar Listas de Revogação
    ],
  );

  File('root_ca.crt').writeAsStringSync(rootCaCertPem);
  print('-> Certificado da CA Raiz salvo em: root_ca.crt');

  // --- 2. GERAÇÃO DO CERTIFICADO DO USUÁRIO ---
  print('[PASSO 4/9] Gerando par de chaves e CSR para o usuário...');
  final userKeyPair = generateRsaKeyPair(secureRandom, bitLength: 2048);
  final RSAPrivateKey userPrivateKey = userKeyPair.privateKey;
  final RSAPublicKey userPublicKey = userKeyPair.publicKey;

  // Informações do Usuário
  final userSubject = {
    'C': 'BR',
    'O': 'Prefeitura Municipal de Rio das Ostras',
    'CN': 'Isaque Neves Sant\'Ana',
    // Observação: alguns mapeamentos de OID podem não reconhecer 'emailAddress'.
    // Para manter compatibilidade ampla, vamos manter apenas CN/O/C aqui.
  };

  // Gera o CSR do usuário
  final userCsrPem = X509Utils.generateRsaCsrPem(
    userSubject,
    userPrivateKey,
    userPublicKey,
    signingAlgorithm: 'SHA-256',
  );

  print(
      '[PASSO 5/9] Gerando certificado do usuário (assinado pela CA Raiz)...');
  // Usa o *mesmo* método, mas agora passando a chave da CA e o CSR do usuário
  final userCertPem = X509Utils.generateSelfSignedCertificate(
    rootCaPrivateKey, // Assinado pela chave privada da CA
    userCsrPem, // O CSR do usuário
    365 * 2, // 2 anos
    issuer: caSubject, // O "emissor" (Issuer) = nossa CA
    serialNumber: '2', // Serial deve ser único
    notBefore: DateTime.now().toUtc(),

    // O parâmetro na biblioteca é 'cA' (maiúsculo)
    cA: false, // Não é uma CA

    keyUsage: [
      // Enums corrigidos para maiúsculas
      KeyUsage.DIGITAL_SIGNATURE, // Pode ser usado para assinar
      KeyUsage.NON_REPUDIATION, // Usado para não-repúdio
    ],
    extKeyUsage: [
      ExtendedKeyUsage.EMAIL_PROTECTION,
      ExtendedKeyUsage.CLIENT_AUTH,
    ],
  );

  File('user.crt').writeAsStringSync(userCertPem);
  print('-> Certificado do usuário salvo em: user.crt');

  // --- 3. CRIAÇÃO DO PACOTE PKCS#12 (PFX) ---
  print(
      '[PASSO 6/9] Empacotando chave/certificados do usuário em .p12 (PFX)...');

  // Converte a chave privada do formato PointyCastle para o formato PEM
  final userPrivateKeyPem =
      CryptoUtils.encodeRSAPrivateKeyToPem(userPrivateKey);

  // A cadeia de certificados (Certificado do usuário primeiro, depois a CA)
  final certChainPems = [
    userCertPem,
    rootCaCertPem,
  ];

  const p12Password = '123456'; // Senha para o arquivo PFX

  // Gera os bytes do PFX
  final p12FileBytes = Pkcs12Utils.generatePkcs12(
    userPrivateKeyPem,
    certChainPems,
    password: p12Password,
    // Usar MAC baseado em SHA-256 melhora a compatibilidade com alguns validadores
    digestAlgorithm: 'SHA-256',
  );

  File('user.p12').writeAsBytesSync(p12FileBytes);
  print("-> Pacote PFX salvo em: user.p12 (Senha: $p12Password)");

  // --- 4. ASSINATURA DO PDF USANDO pdfbox_dart (assinatura externa + OpenSSL) ---
  print("[PASSO 7/9] Assinando um novo documento PDF com o PFX gerado...");

  List<int>? pdfBytes;
  try {
    // Salva chave e certificado em PEM para uso no OpenSSL.
    File('user_key.pem').writeAsStringSync(userPrivateKeyPem);
    File('user_cert.pem').writeAsStringSync(userCertPem);

    // 1) Cria o PDF base e calcula hash (pré-assinatura).
    final Uint8List basePdf = _createBasePdf();
    final String pdfHashHex = _toHex(crypto.sha256.convert(basePdf).bytes);

    // 2) Reabre e adiciona QR/legenda com o hash.
    final Uint8List pdfWithQr = _appendQrAndHash(basePdf, pdfHashHex);

    // 3) Prepara PDF para assinatura externa.
    final PDSignature signature = PDSignature()
      ..setFilter(PDSignature.filterAdobePpklite)
      ..setSubFilter(PDSignature.subFilterAdbePkcs7Detached)
      ..setReason('Documento oficial')
      ..setLocation('Rio das Ostras, BR')
      ..setContactInfo('isaque.santana@pmro.gov.br')
      ..setName('Isaque Neves Sant Ana')
      ..setSignDate(DateTime.now().toUtc());

    final PdfExternalSigningResult prepared =
        await PdfExternalSigning.preparePdf(
      inputBytes: pdfWithQr,
      pageNumber: 1,
      bounds: PDRectangle(50, 120, 320, 95),
      fieldName: 'MinhaAssinatura',
      signature: signature,
    );

    final Uint8List signedBytes = await _signWithOpenSsl(
      preparedPdfBytes: prepared.preparedPdfBytes,
      fieldName: 'MinhaAssinatura',
      keyPath: 'user_key.pem',
      certPath: 'user_cert.pem',
      chainPath: 'root_ca.crt',
    );

    pdfBytes = signedBytes;
    File('documento_assinado_native.pdf').writeAsBytesSync(signedBytes);
    print('--- SUCESSO! ---');
    print('-> PDF assinado salvo em: documento_assinado_native.pdf');
  } catch (e, s) {
    print('\n--- ERRO AO ASSINAR O PDF ---');
    print('Houve um erro ao usar a assinatura externa via OpenSSL:');
    print(e);
    print(s);
  }

  // --- 5. VALIDAÇÃO DA ASSINATURA (NOVO) ---
  if (pdfBytes != null) {
    print('\n[PASSO 8/9] Verificando a assinatura dentro do PDF...');
    try {
      final PdfSignatureValidationReport report =
          await PdfSignatureValidator().validateAllSignatures(
        Uint8List.fromList(pdfBytes),
        trustedRootsPem: <String>[rootCaCertPem],
      );

      if (report.signatures.isEmpty) {
        print('-> Nenhuma assinatura encontrada no PDF.');
      } else {
        for (final PdfSignatureValidationItem item in report.signatures) {
          print(
              '-> Campo "${item.fieldName}": cms=${item.validation.cmsSignatureValid}, '
              'digest=${item.validation.byteRangeDigestOk}, '
              'intact=${item.validation.documentIntact}, '
              'chainTrusted=${item.chainTrusted}');
        }
      }
    } catch (e, s) {
      print('\n--- ERRO AO VALIDAR O PDF ASSINADO ---');
      print(e);
      print(s);
    }
  }

  // --- 6. VALIDAÇÃO DA CADEIA COM OPENSSL (NOVO) ---
  print('\n[PASSO 9/9] Verificando a cadeia de certificados com OpenSSL...');
  try {
    // Executa o comando: openssl verify -CAfile root_ca.crt user.crt
    final result = Process.runSync(
        'openssl', ['verify', '-CAfile', 'root_ca.crt', 'user.crt']);

    if (result.exitCode == 0 && (result.stdout as String).contains('OK')) {
      print('--- SUCESSO (OpenSSL)! ---');
      print('Saída do OpenSSL: ${result.stdout.trim()}');
    } else {
      print('--- ERRO (OpenSSL)! ---');
      print(
          'A cadeia de certificados é INVÁLIDA ou o OpenSSL não foi encontrado.');
      print('Saída STDOUT: ${result.stdout}');
      print('Saída STDERR: ${result.stderr}');
    }
  } catch (e) {
    print('\n--- ERRO AO EXECUTAR OpenSSL ---');
    print(
        'Certifique-se de que o "openssl" está instalado e no PATH do seu sistema.');
    print(e);
  }
}

Future<void> _runCmd(String cmd, List<String> args) async {
  final ProcessResult res = await Process.run(cmd, args);
  if (res.exitCode != 0) {
    throw Exception('Command failed: $cmd ${args.join(' ')}');
  }
}

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _createBasePdf() {
  final PDDocument document = PDDocument();
  final PDPage page = PDPage();
  document.addPage(page);

  final PDPageContentStream stream = PDPageContentStream(document, page);
  stream.saveGraphicsState();
  stream.setLineWidth(2.5);
  stream.setStrokingColorRgb(0.0, 0.2, 0.6);
  stream.setNonStrokingColorRgb(0.941, 0.973, 1.0);
  stream.rectangle(40, 40, 515, 220);
  stream.fill();
  stream.rectangle(40, 40, 515, 220);
  stream.stroke();
  stream.restoreGraphicsState();

  final COSName fontResource = COSName.get('F1');
  stream.resources.registerStandard14Font(fontResource, 'Helvetica');

  stream.beginText();
  stream.setNonStrokingColorRgb(0, 0, 0);
  stream.setFont(fontResource, 10);
  stream.setAutoLeading(12);
  stream.newLineAtOffset(50, 240);
  stream.showParagraph(
    'PREFEITURA MUNICIPAL DE RIO DAS OSTRAS\n'
    'Estado do Rio de Janeiro\n\n'
    '═══════════════════════════════════════════════\n\n'
    'DOCUMENTO OFICIALMENTE ASSINADO\n\n'
    'Servidor: Isaque Neves Sant\'Ana\n'
    'Matrícula: [informar]\n'
    'E-mail: isaque.santana@pmro.gov.br\n'
    'Setor: Tecnologia da Informação\n\n'
    'Data/Hora: ${DateTime.now().toString().substring(0, 19)}\n'
    'Localização: Rio das Ostras, RJ, Brasil\n\n'
    'Este documento possui validade jurídica conforme\n'
    'MP 2.200-2/2001 e Lei 14.063/2020',
    trailingLineBreaks: 0,
  );
  stream.endText();

  // Moldura visual da área de assinatura.
  stream.setStrokingColorRgb(0.0, 0.2, 0.6);
  stream.setLineWidth(1);
  stream.rectangle(50, 120, 320, 95);
  stream.stroke();

  stream.close();

  final Uint8List out = document.saveToBytes();
  document.close();
  return out;
}

Uint8List _appendQrAndHash(Uint8List basePdf, String pdfHashHex) {
  final PDDocument document = PDDocument.loadFromBytes(basePdf);
  try {
    final PDPage page = document.getPage(0);
    final PDPageContentStream stream = PDPageContentStream(
      document,
      page,
      mode: PDPageContentMode.append,
    );

    final double sigX = 50;
    final double sigY = 120;
    final double sigW = 320;
    const double qrSize = 95.0;
    final double qrX = sigX + sigW + 20;
    final double qrY = sigY;

    _drawQr(stream, qrX, qrY, qrSize, 'SHA256:$pdfHashHex');

    final COSName fontResource = COSName.get('F1');
    stream.resources.registerStandard14Font(fontResource, 'Helvetica');
    stream.beginText();
    stream.setNonStrokingColorRgb(0, 0, 0);
    stream.setFont(fontResource, 9);
    stream.newLineAtOffset(qrX, qrY - 12);
    stream.showText('Hash (SHA-256): ${pdfHashHex.substring(0, 16)}…');
    stream.endText();
    stream.close();

    final Uint8List out = document.saveToBytes();
    return out;
  } finally {
    document.close();
  }
}

void _drawQr(
  PDPageContentStream stream,
  double x,
  double y,
  double size,
  String data,
) {
  final qrCode = qr.QrCode.fromData(
    data: data,
    errorCorrectLevel: qr.QrErrorCorrectLevel.M,
  );
  final qrImage = qr.QrImage(qrCode);

  final int count = qrImage.moduleCount;
  final double cell = size / count;

  stream.saveGraphicsState();
  stream.setNonStrokingColorRgb(0, 0, 0);
  for (int r = 0; r < count; r++) {
    for (int c = 0; c < count; c++) {
      if (qrImage.isDark(r, c)) {
        stream.rectangle(x + c * cell, y + r * cell, cell, cell);
        stream.fill();
      }
    }
  }

  stream.setStrokingColorRgb(0, 0, 0);
  stream.setLineWidth(1);
  stream.rectangle(x, y, size, size);
  stream.stroke();
  stream.restoreGraphicsState();
}

Future<Uint8List> _signWithOpenSsl({
  required Uint8List preparedPdfBytes,
  required String fieldName,
  required String keyPath,
  required String certPath,
  String? chainPath,
}) async {
  final Directory tempDir = await Directory.systemTemp
      .createTemp('pdfbox_dart_external_sign_');
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

    await _runCmd('openssl', args);

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

