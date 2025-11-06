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
import 'dart:typed_data';
import 'dart:math';
import 'package:dart_pdf/pdf.dart' as pdf;
import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/basic_utils.dart';
import 'package:pointycastle/api.dart';
import 'package:qr/qr.dart' as qr;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart' hide Padding;
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
//import 'package:pointycastle/pointycastle.dart';
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
    // ****** CORREÇÃO AQUI ******
    // O parâmetro na sua biblioteca é 'cA' (maiúsculo) [cite: 2723]
    cA: true, // Define que é uma CA
    // ****** FIM DA CORREÇÃO ******
    keyUsage: [
      // Enums corrigidos para maiúsculas [cite: 2618]
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
    // ****** CORREÇÃO AQUI ******
    // O parâmetro na sua biblioteca é 'cA' (maiúsculo) [cite: 2723]
    cA: false, // Não é uma CA
    // ****** FIM DA CORREÇÃO ******
    keyUsage: [
      // Enums corrigidos para maiúsculas [cite: 2618]
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

  // --- 4. ASSINATURA DO PDF USANDO dart_pdf ---
  print("[PASSO 7/9] Assinando um novo documento PDF com o PFX gerado...");

  List<int>? pdfBytes;
  try {
    // 1) Cria o documento e adiciona conteúdo na página 1
    final doc = pdf.PdfDocument();
    final page1 = doc.pages.add();
    final g1 = page1.graphics;
    final font = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 10);
    g1.drawRectangle(
      bounds: pdf.Rect.fromLTWH(40, 40, 515, 220),
      pen: pdf.PdfPen(pdf.PdfColor(0, 51, 153), width: 2.5),
      brush: pdf.PdfSolidBrush(pdf.PdfColor(240, 248, 255)),
    );
    g1.drawString(
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
      font,
      brush: pdf.PdfSolidBrush(pdf.PdfColor(0, 0, 0)),
      bounds: pdf.Rect.fromLTWH(50, 50, 495, 200),
    );

    // 2) Salva os bytes pré-assinatura e calcula o hash SHA-256
    final preSignBytes = await doc.save();
    final pdfHash = crypto.sha256.convert(preSignBytes).bytes;
    final pdfHashHex = _toHex(pdfHash);

    // 3) Reabre a partir dos bytes para evitar perda de conteúdo da página 1
    final docSigned = pdf.PdfDocument(inputBytes: preSignBytes);
    final lastPage = docSigned.pages.add();
    final lastG = lastPage.graphics;

    // 3.1) Desenha QR com o hash ao lado da assinatura
    void drawQr(pdf.PdfGraphics g, double x, double y, double size, String data) {
      qr.QrCode code;
      for (int type = 2;; type++) {
        try {
          code = qr.QrCode(type, qr.QrErrorCorrectLevel.M)
            ..addData(data)
            ..make();
          break;
        } catch (_) {
          if (type >= 40) rethrow;
        }
      }
      final int count = code.moduleCount;
      final double cell = size / count;
      for (int r = 0; r < count; r++) {
        for (int c = 0; c < count; c++) {
          if (code.isDark(r, c)) {
            g.drawRectangle(
              bounds: pdf.Rect.fromLTWH(x + c * cell, y + r * cell, cell, cell),
              brush: pdf.PdfSolidBrush(pdf.PdfColor(0, 0, 0)),
            );
          }
        }
      }
      g.drawRectangle(
        bounds: pdf.Rect.fromLTWH(x, y, size, size),
        pen: pdf.PdfPen(pdf.PdfColor(0, 0, 0), width: 1),
      );
    }

    final sigBounds = pdf.Rect.fromLTWH(50, 120, 320, 95);
    final qrSize = 95.0;
    final qrX = sigBounds.left + sigBounds.width + 20;
    final qrY = sigBounds.top;

    drawQr(lastG, qrX, qrY, qrSize, 'SHA256:$pdfHashHex');
    lastG.drawString(
      'Hash (SHA-256): ${pdfHashHex.substring(0, 16)}…',
      pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 9),
      bounds: pdf.Rect.fromLTWH(qrX, qrY + qrSize + 6, 260, 12),
    );

    // 4) Carrega o certificado PFX
    final certificate = pdf.PdfCertificate(p12FileBytes, p12Password);

    // 5) Configura a assinatura
    final signature = pdf.PdfSignature(
      certificate: certificate,
      digestAlgorithm: pdf.DigestAlgorithm.sha256,
      cryptographicStandard: pdf.CryptographicStandard.cms,
      reason: 'Documento oficial',
      locationInfo: 'Rio das Ostras, BR',
      contactInfo: 'isaque.santana@pmro.gov.br',
      signedName: 'Isaque Neves Sant\'Ana',
    );

    // 6) Campo de assinatura VISÍVEL com aparência personalizada
    final signatureField = pdf.PdfSignatureField(
      lastPage,
      'MinhaAssinatura',
      bounds: sigBounds,
      signature: signature,
      borderWidth: 1,
      borderStyle: pdf.PdfBorderStyle.solid,
      borderColor: pdf.PdfColor(0, 51, 153),
      backColor: pdf.PdfColor(255, 255, 255),
    );
    docSigned.form.fields.add(signatureField);

    final normalAp = signatureField.appearance.normal;
    final apG = normalAp.graphics!;
    apG.drawRectangle(
      bounds: pdf.Rect.fromLTWH(0, 0, normalAp.size.width, normalAp.size.height),
      pen: pdf.PdfPen(pdf.PdfColor(0, 51, 153), width: 1),
      brush: pdf.PdfSolidBrush(pdf.PdfColor(255, 255, 255)),
    );
    final titleFont = pdf.PdfStandardFont(
      pdf.PdfFontFamily.helvetica,
      10,
      style: pdf.PdfFontStyle.bold,
    );
    final textFont = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 9);
    const double padX = 8;
    const double padY = 6;
    final double innerWidth = normalAp.size.width - (padX * 2);
    apG.drawString(
      'ASSINADO DIGITALMENTE',
      titleFont,
      bounds: pdf.Rect.fromLTWH(padX, padY, innerWidth, 14),
    );
    final nowStr = DateTime.now().toString().substring(0, 19);
    apG.drawString(
      'Por: \'Isaque Neves Sant\'Ana\'',
      textFont,
      bounds: pdf.Rect.fromLTWH(padX, padY + 18, innerWidth, 12),
    );
    apG.drawString(
      'E-mail: isaque.santana@pmro.gov.br',
      textFont,
      bounds: pdf.Rect.fromLTWH(padX, padY + 33, innerWidth, 12),
    );
    apG.drawString(
      'Data/Hora: $nowStr',
      textFont,
      bounds: pdf.Rect.fromLTWH(padX, padY + 48, innerWidth, 12),
    );

    // 7) Salva o documento final (assinatura acontece aqui)
    pdfBytes = await docSigned.save();
    docSigned.dispose();

    File('documento_assinado_native.pdf').writeAsBytesSync(pdfBytes);
    print('--- SUCESSO! ---');
    print('-> PDF assinado salvo em: documento_assinado_native.pdf');
  } catch (e, s) {
    print('\n--- ERRO AO ASSINAR O PDF ---');
    print('Houve um erro ao usar a biblioteca dart_pdf para assinar:');
    print(e);
    print(s);
  }

  // --- 5. VALIDAÇÃO DA ASSINATURA (NOVO) ---
  if (pdfBytes != null) {
    print('\n[PASSO 8/9] Verificando a assinatura dentro do PDF...');
    try {
      final loadedDocument = pdf.PdfDocument(inputBytes: pdfBytes);
      final loadedSignatureField =
          loadedDocument.form.fields[0] as pdf.PdfSignatureField;

      // Verifica se o campo de assinatura está de fato assinado
      if (loadedSignatureField.isSigned) {
        print(
            '-> Verificação interna (dart_pdf): Campo "MinhaAssinatura" ESTÁ assinado.');
        print(
            '-> Motivo da assinatura: ${loadedSignatureField.signature!.reason}');
      } else {
        print(
            '-> Verificação interna (dart_pdf): ERRO! O campo não está assinado.');
      }
      loadedDocument.dispose();
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

String _toHex(List<int> bytes) =>
  bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
