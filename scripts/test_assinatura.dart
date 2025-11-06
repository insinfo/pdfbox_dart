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

import 'package:pdfbox_dart/src/dependencies/basic_utils/basic_utils.dart';
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

  print('[PASSO 2/7] Gerando CSR para a CA Raiz...');
  // É preciso criar um CSR primeiro, conforme a assinatura do método
  final rootCaCsrPem = X509Utils.generateRsaCsrPem(
    caSubject,
    rootCaPrivateKey,
    rootCaPublicKey,
    signingAlgorithm: 'SHA-256',
  );

  print('[PASSO 3/7] Gerando certificado autoassinado da CA Raiz...');
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
  print('[PASSO 4/7] Gerando par de chaves e CSR para o usuário...');
  final userKeyPair = generateRsaKeyPair(secureRandom, bitLength: 2048);
  final RSAPrivateKey userPrivateKey = userKeyPair.privateKey;
  final RSAPublicKey userPublicKey = userKeyPair.publicKey;

  // Informações do Usuário
  final userSubject = {
    'C': 'BR',
    'O': 'Prefeitura Municipal de Rio das Ostras',
    'CN': 'Isaque Neves Sant\'Ana',
    'emailAddress': 'isaque.santana@pmro.gov.br'
  };

  // Gera o CSR do usuário
  final userCsrPem = X509Utils.generateRsaCsrPem(
    userSubject,
    userPrivateKey,
    userPublicKey,
    signingAlgorithm: 'SHA-256',
  );

  print(
      '[PASSO 5/7] Gerando certificado do usuário (assinado pela CA Raiz)...');
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
  );

  File('user.crt').writeAsStringSync(userCertPem);
  print('-> Certificado do usuário salvo em: user.crt');

  // --- 3. CRIAÇÃO DO PACOTE PKCS#12 (PFX) ---
  print(
      '[PASSO 6/7] Empacotando chave/certificados do usuário em .p12 (PFX)...');

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
  );

  File('user.p12').writeAsBytesSync(p12FileBytes);
  print("-> Pacote PFX salvo em: user.p12 (Senha: $p12Password)");

  // --- 4. ASSINATURA DO PDF USANDO dart_pdf ---
  print("[PASSO 7/7] Assinando um novo documento PDF com o PFX gerado...");

  List<int>? pdfBytes;
  try {
    // Cria um novo documento PDF
    final document = pdf.PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    final font = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 12);
    graphics.drawString(
      'Documento de teste assinado por Isaque Neves Sant\'Ana.\n'
      'Emitido pela Autoridade Certificadora Raiz PMRO G1.',
      font,
      bounds: pdf.Rect.fromLTWH(50, 50, 400, 100),
    );

    // 1. Carrega o certificado PFX
    final certificate = pdf.PdfCertificate(p12FileBytes, p12Password);

    // 2. Configura a assinatura
    final signature = pdf.PdfSignature(
      certificate: certificate,
      digestAlgorithm: pdf.DigestAlgorithm.sha256,
      cryptographicStandard: pdf.CryptographicStandard.cms,
      reason: 'Documento oficial',
      locationInfo: 'Rio das Ostras, BR',
    );

    // 3. Adiciona o campo de assinatura ao documento
    final signatureField = pdf.PdfSignatureField(
      page,
      'MinhaAssinatura',
      bounds: pdf.Rect.fromLTWH(50, 200, 200, 50),
      signature: signature, // Vincula a assinatura
    );

    // Adiciona o campo ao formulário
    document.form.fields.add(signatureField);

    // 4. Salva o documento (a assinatura ocorre neste momento)
    pdfBytes = await document.save();
    document.dispose();

    File('documento_assinado.pdf').writeAsBytesSync(pdfBytes);
    print('--- SUCESSO! ---');
    print('-> PDF assinado salvo em: documento_assinado.pdf');
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
