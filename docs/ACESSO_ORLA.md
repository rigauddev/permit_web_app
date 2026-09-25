# Acesso à Orla de Guaibim

## Fluxo implementado

O cidadão usa o cadastro e login existentes. Em Serviços → Acesso à Orla cadastra placa brasileira (antiga ou Mercosul), marca, modelo e cor. Cada placa é única no sistema, vinculada permanentemente ao titular, sem endpoints de edição ou exclusão. O limite inicial é de dois veículos; cadastro e alteração do limite são serializados no banco para impedir ultrapassagem por requisições concorrentes.

Cada veículo recebe QR Code exclusivo, exibido na tela e impresso em PDF A4 para o para-brisa. O conteúdo `ORLA1:<token aleatório>` referencia os dados do veículo e do titular, consultados pela API autenticada; não contém CPF, telefone ou endereço em texto aberto.

Operadores da DMTRAN e da Guarda Municipal consultam usuários/veículos, leem QR Code ou placa, conferem placa, marca, modelo, cor e titular, e registram entrada explicitamente. A consulta não registra movimento. Por enquanto não há registro de saída; o histórico informa as entradas, data/hora, método e operador. Cidadãos acessam apenas o próprio histórico. Não há geolocalização nem checkout automático por raio, conforme o fluxo revisado.

Gestores vinculados à DMTRAN ou à Guarda Municipal, além de administradores, podem alterar o limite individual. O limite controla **cadastros**, não número de visitas ou ocupação simultânea. Reduzi-lo não exclui registros existentes; limite zero suspende novas entradas. Operadores não alteram limites. Outras secretarias não têm acesso às operações de fiscalização/gestão deste módulo.

## Preparação do servidor

Com o banco existente configurado no ambiente da API, execute:

```sh
cd permit_system
python scripts/setup_orla.py
```

O script cria apenas as tabelas do serviço e garante as secretarias responsáveis, de forma idempotente, sem usuários de demonstração. Associe os gestores/operadores à DMTRAN ou à Guarda Municipal pela gestão existente. Reinicie a API e publique o novo frontend. Não é necessário executar o seed completo de demonstração.

## Leitura de placas pelo celular

A integração usa captura por `image_picker` e envio ao backend, que chama o Plate Recognizer Snapshot com região `br`. Configure apenas no **servidor**:

```dotenv
PLATE_RECOGNIZER_TOKEN=<token do fornecedor>
```

Sem token, consulta manual por placa e QR Code continuam disponíveis. Não há chave no Flutter. O servidor aceita JPEG/PNG/WebP até 5 MB, usa timeout e não persiste a foto. A foto é enviada ao fornecedor; o operador confirma a placa detectada, podendo corrigi-la, antes da consulta e registro. É necessário contratar/ativar uma conta e verificar as condições de tratamento/retenção de imagens do fornecedor antes do uso em produção.

No navegador, publique por HTTPS e permita a câmera. A experiência de captura de foto depende do navegador/dispositivo. QR Code usa `mobile_scanner`. Validar em celulares reais, iluminação, distância, placas antigas/Mercosul, negação de câmera e impressão em escala legível.

Pesquisa em 18/09/2026:
- API especializada em placas e fotos, opção Cloud ou local: https://guides.platerecognizer.com/docs/snapshot/api-reference/
- Alternativa nativa de OCR genérico: https://developers.google.com/ml-kit/vision/text-recognition (exige tratamento de placas e integração específica Android/iOS; não substitui diretamente o fluxo web).

A integração externa foi preparada, mas não testada com credencial real. Os testes locais não enviam imagens ao fornecedor.

## Verificação

```sh
cd permit_system
python -m unittest discover -s tests -p 'test_orla.py' -v
```

Testes usam banco SQLite temporário e cobrem permissões, isolamento por titular, limite, duplicidade de placa, imutabilidade da API, entrada/saída, suspensão, repetição e concorrência. Recomenda-se validar também concorrência no banco de produção em homologação.
