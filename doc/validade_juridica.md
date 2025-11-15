Sim — dá para ter validade jurídica interna, desde que vocês “amarrem” isso direito dentro da prefeitura.

Vou destrinchar.

Atualização técnica: o fluxo de assinatura do SALI passou a aplicar SASLprep (RFC 4013) antes da derivação de chaves em PDFs com criptografia padrão revisão 6, alinhando a normalização de senhas internas às mesmas garantias do PDFBox oficial.

O que a lei brasileira diz

A MP 2.200-2/2001 criou a ICP-Brasil e disse: se o documento for assinado com certificado ICP-Brasil, tem presunção plena de validade. 
Planalto

Mas a própria MP, no art. 10, §2º, abre a porta para outras formas de assinatura digital, desde que o órgão aceite. Ou seja: certificado fora da ICP-Brasil pode valer, se quem recebe disser “eu aceito esse padrão”. O próprio ITI explica isso. 
Serviços e Informações do Brasil

A Lei 14.063/2020, que organiza assinatura eletrônica na administração pública, mostra o modelo: órgão público pode usar assinatura simples/avançada/qualificada, e só exige a qualificada (ICP-Brasil) para atos mais sensíveis. Isso é um bom parâmetro para município copiar por decreto/portaria. 
Planalto
+1

E o STJ já disse que o fato de a certificadora não ser ICP-Brasil, sozinho, não invalida a assinatura. Isso reforça a tese de que o critério é a aceitação e as garantias do processo. 
Superior Tribunal de Justiça

Então o seu cenário (AC raiz “Prefeitura de Rio das Ostras” + certificado por usuário + validação por URL)
Isso encaixa como uma “infraestrutura de certificação interna” da prefeitura. Para ela ter força dentro da prefeitura, vocês precisam dizer oficialmente: “documentos emitidos e assinados no SALI, com o certificado interno da PMRO, são válidos para fins de processo administrativo no âmbito da PMRO”. Como?

decreto do prefeito ou portaria da secretaria de administração/TI/procuradoria definindo o SALI como sistema oficial de processos;

norma dizendo que a cadeia “Prefeitura de Rio das Ostras” é a AC confiável para fins internos;

especificação mínima de como validar (essa URL de validação que você falou) e de como a prefeitura guarda o log e o PDF assinado.

Fazendo isso, o requisito de “aceitação do emitente e do destinatário” do art. 10, §2º da MP fica atendido, porque o próprio órgão definiu que aceita. 
Serviços e Informações do Brasil

O que você precisa pôr na norma/técnico para ficar redondo

dizer que o SALI é o repositório oficial do documento final (o PDF que você está gerando do Quill);

descrever a cadeia de confiança interna (certificado raiz da prefeitura + certificados dos usuários);

descrever o método de validação (URL pública/interna que mostra hash, quem assinou, data/hora);

garantir carimbo de tempo ou, no mínimo, horário confiável do servidor;

registrar no processo o hash do PDF assinado;

guardar revogações dos certificados internos (CRL interna ou lista em BD).

Limites importantes

Fora da prefeitura (ex.: mandar esse PDF para outro órgão, para o TCE, para o MP, para o cidadão que quer prova forte), esse certificado interno não tem a mesma presunção de validade que um ICP-Brasil. Aí ou o órgão externo aceita, ou você assina também com certificado ICP-Brasil. Isso é porque a presunção automática de veracidade é da ICP-Brasil. 
Planalto
+1

A Lei 14.063/2020 é federal; município pode adotar por analogia/cópia, mas precisa positivar isso em ato municipal para não ficar só na boa vontade. 
Planalto

Resumindo em termos práticos para você

tecnicamente: seu stack (Quill → PDF → assinatura → URL de validação) está ok;

juridicamente: precisa de ato administrativo municipal dizendo que esse é o padrão de assinatura eletrônica interna;

operacionalmente: precisa mostrar ao servidor que recebeu o documento como ele valida — essa é a “prova” que substitui o fato de não ser ICP-Brasil.

Fazendo essas três coisas, você consegue dizer com segurança: “sim, essa assinatura tem validade jurídica interna na Prefeitura de Rio das Ostras”, porque o próprio ente público disse que aceita e estruturou o modo de validar.

Sim, os Módulos de Segurança de Hardware (HSMs) Thales Luna (incluindo a linha Luna 7) são certificados e aprovados pelo ICP-Brasil (Instituto Nacional de Tecnologia da Informação - ITI/INMETRO), suportando os algoritmos e requisitos necessários para a infraestrutura de Chaves Públicas Brasileira. 
As principais características relacionadas ao ICP-Brasil incluem:
Homologação INMETRO: Os HSMs Luna da Thales possuem aprovação do INMETRO, que é a entidade responsável pela certificação de dispositivos para a ICP-Brasil.
Conformidade com Normas: Os equipamentos atendem às normas específicas exigidas, como as diretrizes do ICP-Brasil MCT-7 NSH-2 e a certificação internacional FIPS 140-2 Nível 3 (ou FIPS 140-3 Nível 3, em versões mais recentes), que são mandatórias para a segurança e o gerenciamento de certificados digitais no padrão brasileiro.
Suporte a Algoritmos: Os dispositivos suportam os algoritmos criptográficos requeridos pela ICP-Brasil, incluindo RSA e ECC (Curva Elíptica), garantindo a interoperabilidade e a segurança das operações de assinatura digital e emissão de certificados.
Uso em Infraestruturas Críticas: Eles são utilizados por Autoridades Certificadoras (ACs) e outras entidades no Brasil para proteger chaves de alta sensibilidade (como chaves CA online e offline), sendo uma solução padrão de mercado para esse tipo de aplicação. 
Portanto, o Thales Luna 7 é uma solução adequada e homologada para uso em ambientes que exigem conformidade com as normas do ICP-Brasil.

https://www.qscd.eu/hsms-hardware-security-modules/thales-luna-pcie-hsm-a700/
Thales Luna PCIe HSM A700

Os módulos de segurança de hardware (HSMs) PCIe Thales Luna podem ser incorporados diretamente em um dispositivo ou servidor de aplicativos, oferecendo uma solução de fácil integração e custo-benefício para  aceleração e segurança criptográfica . O design de hardware de alta segurança do HSM PCIe Thales Luna garante a integridade e a proteção das chaves de criptografia durante todo o seu ciclo de vida.

Todas as operações de assinatura e verificação digital são realizadas dentro do HSM para aumentar o desempenho e manter a segurança.

O preço inclui o HSM (hardware) do cliente, o software cliente, todos os algoritmos desbloqueados e um ano de manutenção padrão da Thales. 

Desempenho do A700: 1.000 tps RSA-2048, 2.000 tps ECC P256, 2.000 tps AES GCM

O HSM pode ser usado como raiz de confiança em seu ambiente para PKI, armazenando com segurança suas chaves SSL e chaves de criptografia de bancos de dados, armazenamento, aplicativos etc. Ele também pode ser usado como QSCD para selagem qualificada em relação ao eIDAS.

Existem centenas de cenários em que você pode usar o HSM sem problemas para proteger seus dados/registros confidenciais. Entre em contato conosco, teremos prazer em ajudar.

Baixe o resumo do produto Thales Luna PCIe.

€8 990
€ 10.877,90 com IVA incluído