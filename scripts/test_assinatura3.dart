import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pdfbox_dart/qr.dart' as qr;
import 'package:dart_pdf/pdf.dart' as pdf;

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<void> main() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║  GERAÇÃO DE CERTIFICADO PARA FOXIT PDF EDITOR           ║');
  print('║  Formatos: .p7b, .p7c, .cer                              ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  // Verificar OpenSSL
  try {
    await Process.run('openssl', ['version'], stdoutEncoding: systemEncoding);
  } catch (e) {
    print('❌ OpenSSL não encontrado. Instale e tente novamente.\n');
    return;
  }

  final workDir = Directory('build/foxit_certs').absolute;
  if (workDir.existsSync()) {
    workDir.deleteSync(recursive: true);
  }
  workDir.createSync(recursive: true);

  const senha = 'Pmro@2025!Seguro';

  // Configuração da CA Raiz
  final rootConfig = '''
[req]
distinguished_name = req_dn
x509_extensions = v3_ca
prompt = no

[req_dn]
C = BR
ST = Rio de Janeiro
L = Rio das Ostras
O = Prefeitura Municipal de Rio das Ostras
OU = Departamento de TI
CN = CA Raiz PMRO 2025
emailAddress = ti@pmro.gov.br

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign, digitalSignature
''';

  // Configuração do Usuário (CSR - sem authorityKeyIdentifier)
  final userCsrConfig = '''
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no

[req_dn]
C = BR
ST = Rio de Janeiro
L = Rio das Ostras
O = Prefeitura Municipal de Rio das Ostras
OU = Servidor Publico
CN = Isaque Neves Sant Ana
emailAddress = isaque.santana@pmro.gov.br

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, nonRepudiation
extendedKeyUsage = emailProtection, clientAuth
subjectKeyIdentifier = hash
subjectAltName = email:isaque.santana@pmro.gov.br
''';

  // Configuração para assinatura do certificado (com authorityKeyIdentifier)
  final userCertConfig = '''
[usr_cert]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, nonRepudiation
extendedKeyUsage = emailProtection, clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName = email:isaque.santana@pmro.gov.br
''';

  File('${workDir.path}/root.cnf').writeAsStringSync(rootConfig);
  File('${workDir.path}/user_csr.cnf').writeAsStringSync(userCsrConfig);
  File('${workDir.path}/user_cert.cnf').writeAsStringSync(userCertConfig);

  try {
    print('[1/10] Gerando chave privada da CA Raiz (4096 bits)...');
    await _exec([
      'openssl', 'genrsa',
      '-out', '${workDir.path}/ca_root.key',
      '4096'
    ]);

    print('[2/10] Criando certificado autoassinado da CA...');
    await _exec([
      'openssl', 'req', '-x509', '-new',
      '-key', '${workDir.path}/ca_root.key',
      '-sha256', '-days', '3650',
      '-out', '${workDir.path}/ca_root.pem',
      '-config', '${workDir.path}/root.cnf'
    ]);

    print('[3/10] Convertendo CA para formato DER (.cer)...');
    await _exec([
      'openssl', 'x509',
      '-in', '${workDir.path}/ca_root.pem',
      '-outform', 'DER',
      '-out', '${workDir.path}/ca_root.cer'
    ]);

    print('[4/10] Gerando chave do usuário (2048 bits)...');
    await _exec([
      'openssl', 'genrsa',
      '-out', '${workDir.path}/user.key',
      '2048'
    ]);

    print('[5/10] Criando requisição CSR do usuário...');
    await _exec([
      'openssl', 'req', '-new',
      '-key', '${workDir.path}/user.key',
      '-out', '${workDir.path}/user.csr',
      '-config', '${workDir.path}/user_csr.cnf'
    ]);

    print('[6/10] Assinando certificado do usuário pela CA...');
    await _exec([
      'openssl', 'x509', '-req',
      '-in', '${workDir.path}/user.csr',
      '-CA', '${workDir.path}/ca_root.pem',
      '-CAkey', '${workDir.path}/ca_root.key',
      '-CAcreateserial',
      '-out', '${workDir.path}/user.pem',
      '-days', '730', '-sha256',
      '-extfile', '${workDir.path}/user_cert.cnf',
      '-extensions', 'usr_cert',
      // '-copy_extensions' não é suportado pelo "openssl x509";
      // as extensões necessárias já são fornecidas via -extfile/-extensions.
    ]);

    print('[7/10] Criando arquivo PKCS#7 (.p7b) com a cadeia completa...');
    await _exec([
      'openssl', 'crl2pkcs7', '-nocrl',
      '-certfile', '${workDir.path}/ca_root.pem',
      '-out', '${workDir.path}/ca_root_chain.p7b'
    ]);

    print('[8/10] Convertendo certificado do usuário para .cer...');
    await _exec([
      'openssl', 'x509',
      '-in', '${workDir.path}/user.pem',
      '-outform', 'DER',
      '-out', '${workDir.path}/user.cer'
    ]);

    print('[9/10] Criando PKCS#12 (.p12) para assinatura...');
    await _exec([
      'openssl', 'pkcs12', '-export',
      '-out', '${workDir.path}/isaque_pmro.p12',
      '-inkey', '${workDir.path}/user.key',
      '-in', '${workDir.path}/user.pem',
      '-certfile', '${workDir.path}/ca_root.pem',
      '-name', 'Isaque Neves Sant Ana - PMRO',
      '-passout', 'pass:$senha'
    ]);

    // Copiar arquivos finais para diretório principal
    File('${workDir.path}/ca_root.cer').copySync('CA_RAIZ_PMRO.cer');
    File('${workDir.path}/ca_root.pem').copySync('CA_RAIZ_PMRO.pem');
    File('${workDir.path}/ca_root_chain.p7b').copySync('CA_RAIZ_PMRO.p7b');
    File('${workDir.path}/user.cer').copySync('isaque_santana.cer');
    File('${workDir.path}/user.pem').copySync('isaque_santana.pem');
    File('${workDir.path}/isaque_pmro.p12').copySync('isaque_pmro.p12');

    // Tentar instalar automaticamente o certificado raiz no Windows
    print('🔐 Instalando certificado raiz no Windows...');
    final cerAbs = File('CA_RAIZ_PMRO.cer').absolute.path;
    bool userInstalled = false;
    bool machineInstalled = false;

    // Instala no repositório do USUÁRIO (não requer admin)
    try {
      await _exec([
        'certutil', '-user', '-addstore', 'Root', cerAbs
      ]);
      userInstalled = true;
      print('  → Instalado no repositório do usuário (CurrentUser\\Root)');
    } catch (_) {
      print('  → Falhou a instalação no repositório do usuário');
    }

    // Tenta instalar no repositório da MÁQUINA (requer admin - UAC)
    try {
      final psCmd =
          'Start-Process -FilePath "certutil" -ArgumentList "-addstore Root `"$cerAbs`"" -Verb RunAs -WindowStyle Hidden -Wait';
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psCmd],
        stdoutEncoding: systemEncoding,
        stderrEncoding: systemEncoding,
      );
      if (res.exitCode == 0) {
        machineInstalled = true;
        print('  → Instalado no repositório da máquina (LocalMachine\\Root)');
      } else {
        print('  → Sem privilégios para instalar em LocalMachine (ignore se não for necessário)');
      }
    } catch (_) {
      print('  → Não foi possível solicitar elevação para instalar em LocalMachine');
    }

    if (userInstalled || machineInstalled) {
      print('✅ Certificado raiz adicionado ao Windows.');
    } else {
      print('⚠️  Não foi possível instalar automaticamente. Será gerado um instalador .bat como alternativa.');
    }

    print('[10/10] Assinando documento PDF de teste...');
  final doc = pdf.PdfDocument();
  final page = doc.pages.add(); // página de conteúdo
  final graphics = page.graphics;

    // Cabeçalho
    graphics.drawRectangle(
      bounds: pdf.Rect.fromLTWH(40, 40, 515, 220),
      pen: pdf.PdfPen(pdf.PdfColor(0, 51, 153), width: 2.5),
      brush: pdf.PdfSolidBrush(pdf.PdfColor(240, 248, 255)),
    );

    graphics.drawString(
      'PREFEITURA MUNICIPAL DE RIO DAS OSTRAS\n'
      'Estado do Rio de Janeiro\n\n'
      '═══════════════════════════════════════════════\n\n'
      'DOCUMENTO OFICIALMENTE ASSINADO\n\n'
      'Servidor: Isaque Neves Sant Ana\n'
      'Matrícula: [informar]\n'
      'E-mail: isaque.santana@pmro.gov.br\n'
      'Setor: Tecnologia da Informação\n\n'
      'Data/Hora: ${DateTime.now().toString().substring(0, 19)}\n'
      'Localização: Rio das Ostras, RJ, Brasil\n\n'
      'Este documento possui validade jurídica conforme\n'
      'MP 2.200-2/2001 e Lei 14.063/2020',
      pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 10),
      brush: pdf.PdfSolidBrush(pdf.PdfColor(0, 0, 0)),
      bounds: pdf.Rect.fromLTWH(50, 50, 495, 200),
    );

    // Calcula o hash SHA-256 do PDF ANTES da assinatura (somente conteúdo)
    final preSignBytes = await doc.save();
    final pdfHash = crypto.sha256.convert(preSignBytes).bytes;
    final pdfHashHex = _toHex(pdfHash);

    // Reabre o documento a partir do bytes para continuar (evita apagar conteúdo da página 1)
    final docSigned = pdf.PdfDocument(inputBytes: preSignBytes);
    // Cria a ÚLTIMA página dedicada à assinatura
    final lastPage = docSigned.pages.add();

    // Desenha um QR Code com o hash ao lado da área da assinatura
    void drawQr(
        pdf.PdfGraphics g, double x, double y, double size, String data) {
      // 1. Crie o objeto de dados do QrCode usando a fábrica
      // Isso substitui o loop try...catch
      final qrCode = qr.QrCode.fromData(
        data: data,
        errorCorrectLevel: qr.QrErrorCorrectLevel.M,
      );

      // 2. Crie um objeto QrImage para renderização
      final qrImage = qr.QrImage(qrCode);

      // 3. Desenhe os módulos com base no qrImage
      final int count = qrImage.moduleCount;
      final double cell = size / count;
      for (int r = 0; r < count; r++) {
        for (int c = 0; c < count; c++) {
          // Use qrImage.isDark() em vez de code.isDark()
          if (qrImage.isDark(r, c)) {
            g.drawRectangle(
              bounds: pdf.Rect.fromLTWH(x + c * cell, y + r * cell, cell, cell),
              brush: pdf.PdfSolidBrush(pdf.PdfColor(0, 0, 0)),
            );
          }
        }
      }

      // 4. Desenhe a borda
      g.drawRectangle(
        bounds: pdf.Rect.fromLTWH(x, y, size, size),
        pen: pdf.PdfPen(pdf.PdfColor(0, 0, 0), width: 1),
      );
    }
    // Posição da assinatura e QR na última página
    final sigBounds = pdf.Rect.fromLTWH(50, 120, 320, 95);
    final qrSize = 95.0;
    final qrX = sigBounds.left + sigBounds.width + 20;
    final qrY = sigBounds.top;

    // QR com hash do PDF (pré-assinatura)
  final lastG = lastPage.graphics;
    drawQr(lastG, qrX, qrY, qrSize, 'SHA256:$pdfHashHex');
    // Rótulo com hash abreviado
    lastG.drawString(
      'Hash (SHA-256): ${pdfHashHex.substring(0, 16)}…',
      pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 9),
      bounds: pdf.Rect.fromLTWH(qrX, qrY + qrSize + 6, 260, 12),
    );

    // Assinar
  final p12Bytes = File('isaque_pmro.p12').readAsBytesSync();
    final cert = pdf.PdfCertificate(p12Bytes, senha);

    final signature = pdf.PdfSignature(
      certificate: cert,
      digestAlgorithm: pdf.DigestAlgorithm.sha256,
      cryptographicStandard: pdf.CryptographicStandard.cms,
      reason: 'Aprovacao de documento oficial da PMRO',
      locationInfo: 'Rio das Ostras, RJ, Brasil',
      contactInfo: 'isaque.santana@pmro.gov.br',
      signedName: 'Isaque Neves Sant Ana',
    );

    // Campo de assinatura VISÍVEL (com aparência personalizada)
    final field = pdf.PdfSignatureField(
      lastPage,
      'AssinaturaDigitalPMRO',
      bounds: sigBounds,
      signature: signature,
      borderWidth: 1,
      borderStyle: pdf.PdfBorderStyle.solid,
      borderColor: pdf.PdfColor(0, 51, 153),
      backColor: pdf.PdfColor(255, 255, 255),
    );
  docSigned.form.fields.add(field);

    // Desenha a aparência (AP/N) com informações úteis dentro do retângulo
  final normalAp = field.appearance.normal; // cria o template /AP se necessário
    final apG = normalAp.graphics!;

    // Fundo e borda
    apG.drawRectangle(
      bounds: pdf.Rect.fromLTWH(0, 0, normalAp.size.width, normalAp.size.height),
      pen: pdf.PdfPen(pdf.PdfColor(0, 51, 153), width: 1),
      brush: pdf.PdfSolidBrush(pdf.PdfColor(255, 255, 255)),
    );

    // Título e detalhes
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
      'Por: ${signature.signedName ?? 'Usuário'}',
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

    final pdfBytes = await docSigned.save();
    docSigned.dispose();
    File('documento_assinado_pmro.pdf').writeAsBytesSync(pdfBytes);



  // Criar script de instalação automática (backup/manual)
  final installScript = '''
@echo off
title Instalador de Certificado Raiz - PMRO
color 0A

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║  INSTALADOR DE CERTIFICADO RAIZ - PMRO                   ║
echo ║  Prefeitura Municipal de Rio das Ostras                  ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.
echo Este script ira instalar o certificado raiz CA_RAIZ_PMRO.cer
echo na lista de Autoridades Certificadoras Confiaveis do Windows.
echo.
echo ATENCAO: Requer permissoes de Administrador!
echo.
pause

echo.
echo Instalando certificado...
echo.

REM Instala no repositório do usuário (não requer admin)
certutil -user -addstore -f "Root" "%~dp0CA_RAIZ_PMRO.cer"

REM Tenta instalar no repositório da máquina (pede admin via UAC)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath certutil -ArgumentList '-addstore Root %~dp0CA_RAIZ_PMRO.cer' -Verb RunAs -Wait"

if %errorlevel% equ 0 (
    color 0B
    echo.
    echo ╔═══════════════════════════════════════════════════════════╗
    echo ║              ✓ INSTALACAO CONCLUIDA COM SUCESSO!        ║
    echo ╚═══════════════════════════════════════════════════════════╝
    echo.
    echo O certificado foi instalado no Windows Certificate Store.
    echo.
    echo PROXIMOS PASSOS NO FOXIT PDF EDITOR:
    echo.
    echo 1. Abra o Foxit PDF Editor
    echo 2. Va em: File ^> Preferences (Ctrl+K)
    echo 3. Selecione: Trust Manager
    echo 4. Clique em: Manage Trusted Certificates
    echo 5. Clique em: Add... ou Import...
    echo 6. Selecione o arquivo: CA_RAIZ_PMRO.p7b ou CA_RAIZ_PMRO.cer
    echo 7. Na coluna Trust, marque: Abrir (Trust)
    echo 8. Clique OK
    echo.
    echo Agora abra o PDF assinado e a assinatura deve aparecer como valida!
    echo.
) else (
    color 0C
    echo.
    echo ╔═══════════════════════════════════════════════════════════╗
    echo ║                    ✗ ERRO NA INSTALACAO                  ║
    echo ╚═══════════════════════════════════════════════════════════╝
    echo.
    echo SOLUCAO:
    echo 1. Clique com botao DIREITO neste arquivo
    echo 2. Selecione "Executar como Administrador"
    echo 3. Tente novamente
    echo.
    echo OU instale manualmente:
    echo 1. Clique DUPLO em CA_RAIZ_PMRO.cer
    echo 2. Install Certificate ^> Local Machine
    echo 3. Trusted Root Certification Authorities
    echo.
)

pause
''';
    File('INSTALAR_CERTIFICADO.bat').writeAsStringSync(installScript);

    // Criar arquivo de instruções
  final instructions = '''
╔═══════════════════════════════════════════════════════════════════╗
║        INSTRUÇÕES DE IMPORTAÇÃO - FOXIT PDF EDITOR               ║
╚═══════════════════════════════════════════════════════════════════╝

📋 ARQUIVOS GERADOS:

  ✓ CA_RAIZ_PMRO.cer  → Certificado raiz formato DER (Windows)
  ✓ CA_RAIZ_PMRO.p7b  → Certificado raiz formato PKCS#7 (recomendado)
  ✓ CA_RAIZ_PMRO.pem  → Certificado raiz formato PEM
  ✓ isaque_santana.cer → Certificado do usuário
  ✓ isaque_pmro.p12   → Arquivo para assinar PDFs (senha: $senha)
  ✓ documento_assinado_pmro.pdf → Documento de teste
  ✓ INSTALAR_CERTIFICADO.bat → Instalador automático

══════════════════════════════════════════════════════════════════════

🚀 MÉTODO 1 - INSTALAÇÃO AUTOMÁTICA (RECOMENDADO):

  • Este script já tentou instalar automaticamente o certificado no
    Windows (CurrentUser e LocalMachine). Na maioria dos casos, o
    Foxit passa a reconhecer imediatamente as assinaturas.

  Se ainda assim precisar instalar manualmente:
  1. Feche completamente o Foxit PDF Editor
  2. Clique com BOTÃO DIREITO em "INSTALAR_CERTIFICADO.bat"
  3. Selecione "Executar como Administrador"
  4. Aguarde a confirmação de sucesso
  5. Abra o Foxit PDF Editor
  6. File → Preferences (Ctrl+K)
  7. Trust Manager → Manage Trusted Certificates
  8. O certificado já deve estar listado
  9. Se não estiver, clique Add e selecione CA_RAIZ_PMRO.p7b
  10. Marque a opção "Trust" ou "Abrir"

══════════════════════════════════════════════════════════════════════

📝 MÉTODO 2 - IMPORTAÇÃO DIRETA NO FOXIT:

  1. Abra o Foxit PDF Editor
  2. Vá em: File → Preferences (Ctrl+K)
  3. No painel esquerdo: Trust Manager
  4. Clique em: Manage Trusted Certificates
  5. Clique no botão: Add... (ou Import...)
  6. Na janela de seleção de arquivo:
     - Tipo de arquivo: Certificados (*.p7b,*.p7c,*.cer)
     - Selecione: CA_RAIZ_PMRO.p7b (RECOMENDADO)
       OU
     - Selecione: CA_RAIZ_PMRO.cer
  7. Na lista de certificados importados:
     - Localize: "CA Raiz PMRO 2025"
     - Na coluna "Trust", marque: "Abrir" ou clique para ativar
  8. Clique: OK
  9. Feche e reabra o Foxit PDF Editor

══════════════════════════════════════════════════════════════════════

🔧 MÉTODO 3 - INSTALAÇÃO MANUAL NO WINDOWS:

  1. Clique DUPLO no arquivo: CA_RAIZ_PMRO.cer
  2. Clique em: "Install Certificate..."
  3. Selecione: "Local Machine" (requer admin)
  4. Avançar
  5. Selecione: "Place all certificates in the following store"
  6. Clique em: Browse
  7. Selecione: "Trusted Root Certification Authorities"
  8. OK → Avançar → Concluir
  9. Confirme a instalação clicando em "Sim"
  10. Abra o Foxit e verifique se o certificado aparece automaticamente

══════════════════════════════════════════════════════════════════════

✅ VERIFICAÇÃO:

  1. Abra o arquivo: documento_assinado_pmro.pdf
  2. Clique na assinatura digital
  3. Deve aparecer:
     ✓ "Signature is valid"
     ✓ "Signed by: Isaque Neves Sant Ana"
     ✓ "The document has not been modified"

══════════════════════════════════════════════════════════════════════

⚠️  IMPORTANTE:

  • Senha do arquivo .p12: $senha
  • Guarde esta senha em local seguro!
  • O certificado raiz é válido por 10 anos
  • O certificado do usuário é válido por 2 anos

══════════════════════════════════════════════════════════════════════

🆘 PROBLEMAS COMUNS:

  1. "Signature is unknown"
    → O certificado raiz não foi importado corretamente
    → Primeiro feche e reabra o Foxit
    → Se persistir, rode INSTALAR_CERTIFICADO.bat como Administrador

  2. "Cannot open file"
     → Use o arquivo .p7b em vez do .cer
     → Ou tente o Método 3 (instalação no Windows)

  3. "Access denied"
     → Execute como Administrador
     → Verifique se o Foxit está fechado

══════════════════════════════════════════════════════════════════════

Para suporte: isaque.santana@pmro.gov.br
''';
    File('INSTRUCOES.txt').writeAsStringSync(instructions);

    // Verificação
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║                  ✅ GERAÇÃO CONCLUÍDA!                   ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    final verifyResult = await Process.run(
      'openssl',
      ['verify', '-CAfile', 'CA_RAIZ_PMRO.pem', 'isaque_santana.pem'],
      stdoutEncoding: systemEncoding,
    );
    print('Verificação OpenSSL: ${verifyResult.stdout.trim()}\n');

    print('📦 ARQUIVOS GERADOS:\n');
    print('  Certificados Raiz (escolha um para importar no Foxit):');
    print('  📜 CA_RAIZ_PMRO.p7b    ← RECOMENDADO (formato PKCS#7)');
    print('  📜 CA_RAIZ_PMRO.cer    ← Alternativa (formato DER)');
    print('  📜 CA_RAIZ_PMRO.pem    ← Formato texto\n');
    print('  Certificados do Usuário:');
    print('  📄 isaque_santana.cer  ← Certificado público');
    print('  📄 isaque_santana.pem  ← Formato texto\n');
    print('  Para Assinatura:');
    print('  🔐 isaque_pmro.p12     ← Use este para assinar (senha: $senha)\n');
    print('  Documentos:');
    print('  📝 documento_assinado_pmro.pdf ← PDF de teste assinado\n');
    print('  Utilitários:');
    print('  ⚙️  INSTALAR_CERTIFICADO.bat   ← Instalador automático');
    print('  📖 INSTRUCOES.txt              ← Guia completo\n');

    print('╔═══════════════════════════════════════════════════════════╗');
    print('║                  PRÓXIMOS PASSOS                         ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');
    print('1️⃣  Execute INSTALAR_CERTIFICADO.bat como Administrador');
    print('2️⃣  Abra o Foxit: File > Preferences > Trust Manager');
    print('3️⃣  Manage Trusted Certificates > Add');
    print('4️⃣  Selecione: CA_RAIZ_PMRO.p7b');
    print('5️⃣  Marque: Trust (Abrir)');
    print('6️⃣  Abra documento_assinado_pmro.pdf para testar\n');
    print('📖 Leia INSTRUCOES.txt para mais detalhes\n');

  } catch (e, s) {
    print('\n❌ ERRO: $e');
    print(s);
  }
}

Future<void> _exec(List<String> cmd) async {
  final result = await Process.run(
    cmd[0],
    cmd.sublist(1),
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );

  if (result.exitCode != 0) {
    throw Exception('${cmd[0]} falhou:\n${result.stderr}');
  }

  final output = result.stdout.toString().trim();
  if (output.isNotEmpty && 
      !output.contains('Generating') && 
      !output.contains('writing')) {
    print('  → $output');
  }
}