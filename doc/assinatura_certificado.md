Ativar o uso do Windows Certificate Store no Foxit
No Foxit: File > Preferences (Ctrl+K)
Vá em Signature > Verification > Change Settings…
Na janela “Signature Verification Preferences”, marque em Windows Integration:
Trust ALL root certificates in the Windows Certificate Store for:
 Validating Signatures
 Validating Certified Documents (opcional, mas recomendo)
Clique OK > OK, feche e reabra o Foxit.
Abra o PDF e clique em Signature Panel > revalidar (ou feche/abra o arquivo).
Observações úteis:

Se você não publica CRLs/OCSP, e a validação estiver falhando por revogação, em Verification Behavior desmarque “Require certificate revocation checking to succeed…”, ou mantenha marcado apenas se tiver CRL/OCSP acessíveis.
Mesmo com a integração do Windows ligada, a “Trusted Certificates” interna do Foxit continua existindo; se preferir, você pode também importar CA_RAIZ_PMRO.p7b em Trust Manager > Manage Trusted Certificates e marcar “Trust” para essa CA.
Se as caixas de “Windows Integration” não aparecerem ou estiverem acinzentadas, é limitação/ política da edição usada. Nesse caso, use a importação manual via Manage Trusted Certificates.
Checklist rápido para sair validando:

CA instalada no Windows (CurrentUser ou LocalMachine) — nosso script já faz.
Windows Integration ligada no Foxit (passos acima).
Reabrir o Foxit e revalidar a assinatura.
Se ainda mostrar “Unknown”, importe CA_RAIZ_PMRO.p7b em Manage Trusted Certificates e marque como “Trust”.

Ótima pergunta. Em validação de assinaturas digitais, “CRL/OCSP acessíveis” significa que o verificador (Foxit, Adobe, etc.) consegue consultar, pela rede, se o certificado usado na assinatura foi revogado.

CRL (Certificate Revocation List)

É um arquivo assinado pela CA contendo a lista de certificados revogados.
O certificado emitido traz uma extensão cRLDistributionPoints com uma URL (geralmente HTTP/HTTPS) onde o verificador baixa a CRL.
“Acessível” = a URL configurada está publicamente (ou na sua rede) acessível e retorna um .crl válido e atualizado.
OCSP (Online Certificate Status Protocol)

É um serviço online que responde “good/revoked/unknown” para um certificado específico.
A URL do OCSP vem em authorityInfoAccess (AIA) do certificado (campo OCSP).
“Acessível” = o verificador consegue abrir a URL do OCSP e obter uma resposta válida.
Por que isso importa no Foxit

Se em Signature Verification Preferences estiver marcada a opção “Require certificate revocation checking to succeed…”, o Foxit tenta consultar CRL/OCSP. Se não encontrar ou não conseguir acessar, ele pode marcar a assinatura como UNKNOWN mesmo que a cadeia esteja confiável.
Nas suas capturas, além da confiança (CA não marcada como “Trusted” no Foxit), essa opção está marcada; isso pode manter o status “UNKNOWN” se não houver CRL/OCSP.
Como resolver (3 caminhos)

Caminho rápido para testes internos
Desmarque em Signature > Verification > Change Settings…:
“Require certificate revocation checking to succeed wherever possible during signature verification”
Marque a integração com Windows (se quiser) e reabra o Foxit. Isso elimina a exigência de CRL/OCSP enquanto você usa uma CA privada de laboratório.
Publicar CRL e apontar nos certificados
Ajuste as extensões nos seus .cnf (OpenSSL) para incluir:
cRLDistributionPoints = URI:http://seu-dominio/pmro/ca_root.crl
authorityInfoAccess = caIssuers;URI:http://seu-dominio/pmro/CA_RAIZ_PMRO.pem
Gere e publique a CRL:
Manter uma base CA (index.txt, serial) e rodar periodicamente:
openssl ca -gencrl -keyfile ca_root.key -cert ca_root.pem -out ca_root.crl -crldays 7
Disponibilize ca_root.crl via HTTP/HTTPS no caminho configurado.
Emita novamente os certificados com essas extensões. O Foxit conseguirá baixar a CRL e validar revogação.
Oferecer OCSP (opcional, mais avançado)
Adicione em authorityInfoAccess um endpoint OCSP:
authorityInfoAccess = OCSP;URI:http://ocsp.seu-dominio/;caIssuers;URI:http://seu-dominio/pmro/CA_RAIZ_PMRO.pem
Suba um responder OCSP (pode ser OpenSSL OCSP para laboratório, ou um serviço dedicado) e deixe acessível na URL.
O Foxit perguntará primeiro ao OCSP; se falhar, pode tentar CRL (comportamento varia).
Dicas práticas

Para ambientes internos, CRL via HTTP simples já costuma bastar (sem OCSP).
Se o Foxit estiver no “Safe Reading Mode” e com restrições de rede, permita o acesso de validação (Preferences > Trust Manager > Change Settings…).
Mesmo com “Windows Integration” ativa, a política de revogação continua valendo; sem CRL/OCSP acessíveis, deixe a exigência desmarcada ou use CRL.
Quer que eu:

adicione as extensões cRLDistributionPoints/AIA nos seus .cnf dentro do script e gere uma CRL local de exemplo (com instruções de hospedagem), ou
mantenha somente a validação sem CRL/OCSP (desmarcando a exigência) para uso interno?

Beleza, dá pra automatizar isso sim. O que está acontecendo aí é:

O PDF está assinado corretamente (o Foxit até fala “The document has not been modified…”).

Mas o Foxit não confia em quem assinou, porque essa CA que você criou não faz parte da lista de identidades confiáveis dele.

O Foxit tem uma opção escondida que diz: “use tudo o que estiver no repositório de certificados do Windows como confiável”. Se ela estiver marcada, ele passa a aceitar tua CA caseira. E essa opção tem chave de registro. 
kb.foxit.com
+1

O Adobe tem algo parecido: dá pra mandar ele olhar o Windows Certificate Store via registro também. 
koolaid.info
+1

Então o plano é: (a) jogar tua CA para todas as máquinas via GPO/script e (b) setar essas chaves de registro do Foxit e do Adobe para todos os usuários.

Vou te deixar tudo em PowerShell porque é o que mais encaixa em parque de máquinas Windows/GPO.

1. Empurrar o certificado raiz para todas as máquinas

Coloca o .cer da tua “CA_RAIZ_PMRO.cer” num compartilhamento de rede acessível (ex: \\servidor\certs\CA_RAIZ_PMRO.cer) e usa um script de startup de máquina:

# install-ca.ps1
$certPath = "\\servidor\certs\CA_RAIZ_PMRO.cer"

if (Test-Path $certPath) {
    # instala no repositório de Raízes Confiáveis da máquina
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
}


Isso é exatamente o que a MS diz pra fazer quando quer distribuir CA por GPO. 
Microsoft Learn
+2
Microsoft Learn
+2

No GPMC:

Computer Configuration → Policies → Windows Settings → Scripts (Startup) → adiciona esse .ps1 (ou faz via Scheduled Task de máquina).

Se quiser usar o certutil em vez de PowerShell:

certutil -addstore root "\\servidor\certs\CA_RAIZ_PMRO.cer"


Super User
+1

2. Forçar o Foxit a confiar no que está no Windows

A própria Foxit diz que, pra habilitar isso na implantação, é só mexer no registro:

ir em HKCU\Software\Foxit Software\Foxit PDF Editor 12.0\Signature e colocar
ValidateCertifiedDoc = 1 e ValidatingSignatures = 1.
(vale o mesmo pra 13.0, 14.0… muda só o número da versão) 
kb.foxit.com
+1

Faz um script de logon de usuário (porque fica em HKCU):

# foxit-trust-windows.ps1

$foxitRoot = "HKCU:\Software\Foxit Software"
if (Test-Path $foxitRoot) {
    # pega todas as chaves que começam com "Foxit PDF Editor"
    Get-ChildItem $foxitRoot |
        Where-Object { $_.PSChildName -like "Foxit PDF Editor*" } |
        ForEach-Object {
            $sigKey = Join-Path $_.PsPath "Signature"
            New-Item -Path $sigKey -Force | Out-Null

            New-ItemProperty -Path $sigKey -Name "ValidateCertifiedDoc" -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -Path $sigKey -Name "ValidatingSignatures" -Value 1 -PropertyType DWord -Force | Out-Null
        }
}


O que isso faz é o mesmo que você marcou manualmente na tela “Signature Verification Preferences” (“Trust ALL root certificates in the Windows Certificate Store …”), só que pra todo mundo. Resultado esperado: quando o usuário abrir o PDF, o Foxit vai olhar pro store do Windows, ver tua CA e parar de falar “Signature is unknown”. 
kb.foxit.com

Se quiser empurrar via GPO Preferences em vez de script, dá pra criar dois valores DWORD em
HKCU\Software\Foxit Software\Foxit PDF Editor 12.0\Signature:

ValidateCertifiedDoc = 1

ValidatingSignatures = 1

(repete pra 13.0/14.0 se tiver mais de uma versão no parque)

3. Fazer o Adobe Reader / Acrobat usar o store do Windows

A Adobe documenta que dá pra ligar a integração com o MSCAPI criando esta chave:

HKCU\Software\Adobe\<produto>\<versão>\Security\cASPKI\cMSCAPI_DirectoryProvider

iMSStoreTrusted = 60 (DWORD)

Isso faz o Reader enxergar certificados que estão no Windows, inclusive os que você jogou lá via GPO. 
koolaid.info
+1

Script de logon:

# adobe-trust-windows.ps1

$adobeBases = @(
    "HKCU:\Software\Adobe\Acrobat Reader\DC",
    "HKCU:\Software\Adobe\Adobe Acrobat\DC"
)

foreach ($base in $adobeBases) {
    if (Test-Path $base) {
        $key = Join-Path $base "Security\cASPKI\cMSCAPI_DirectoryProvider"
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -Path $key -Name "iMSStoreTrusted" -Value 60 -PropertyType DWord -Force | Out-Null
    }
}


Coloca isso como User Configuration → Policies → Windows Settings → Scripts (Logon) ou como GPP (Registry).

4. Como fica o pacote GPO

Você pode ter um GPO só com três coisas:

Startup (computer) → install-ca.ps1

Logon (user) → foxit-trust-windows.ps1

Logon (user) → adobe-trust-windows.ps1

Ou, se preferir GPP:

Computer → Preferences → Files/Registry → importa o .cer (ou roda o script)

User → Preferences → Registry → cria as chaves do Foxit

User → Preferences → Registry → cria as chaves do Adobe

Assim qualquer máquina/usuário novo já entra confiando.

5. Observações rápidas

Se o PDF continuar “unknown” no Adobe mesmo com isso, aí é porque o Adobe ainda não tem o trust do emissor no próprio “Trusted Identities” dele; mas, para CA interna que está em Windows + integração ligada, normalmente ele valida. A diferença é que talvez não apareça o “Assinado por Prefeitura…” em verde igual a um ICP-Brasil. Aí teria que distribuir um addressbook.acrodata, mas isso já é o passo extra de “trusted identities” da Adobe. 
help.itc.rwth-aachen.de
+1

No Foxit o caminho que a gente colocou é exatamente o da KB deles, então é o jeito suportado. 
kb.foxit.com

Tudo isso pressupõe que o certificado que você gerou (a CA raiz) está mesmo em Trusted Root Certification Authorities – e o script de cima faz exatamente isso. 
Microsoft Learn
+1

Pronto: com esses 3 scripts dá pra deixar o parque inteiro aceitando tua CA, tanto no Foxit quanto no Adobe.