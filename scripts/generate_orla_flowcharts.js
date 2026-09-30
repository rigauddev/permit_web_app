const pptxgen = require('pptxgenjs');
const path = require('path');

const pptx = new pptxgen();
pptx.layout = 'LAYOUT_WIDE';
pptx.author = 'SEMOP — Prefeitura de Valença';
pptx.subject = 'Fluxos do Acesso à Orla de Guaibim';
pptx.title = 'Fluxos operacionais — Acesso à Orla';
pptx.company = 'Prefeitura de Valença';
pptx.lang = 'pt-BR';
pptx.theme = {
  headFontFace: 'Aptos Display', bodyFontFace: 'Aptos', lang: 'pt-BR',
};

const C = { green: '0E5F2F', teal: '126E82', gold: 'B7791F', red: 'B3261E', ink: '19362A', pale: 'F5FAF6', line: 'B9D7C1', white: 'FFFFFF' };
const out = path.resolve(__dirname, '../docs/arquivos/fluxos_acesso_orla.pptx');

function title(slide, text, subtitle) {
  slide.background = { color: C.pale };
  slide.addShape(pptx.ShapeType.rect, { x: 0, y: 0, w: 13.333, h: .38, fill: { color: C.green }, line: { color: C.green } });
  slide.addText(text, { x: .55, y: .56, w: 12.1, h: .42, fontFace: 'Aptos Display', fontSize: 25, bold: true, color: C.ink, margin: 0 });
  slide.addText(subtitle, { x: .56, y: 1.04, w: 12, h: .3, fontSize: 10.5, color: '537061', margin: 0 });
}

function box(slide, text, x, y, w, h, type = 'normal') {
  const fill = type === 'decision' ? 'FFF5D6' : type === 'success' ? 'E5F4EA' : type === 'danger' ? 'FBEAEA' : C.white;
  const color = type === 'decision' ? C.gold : type === 'success' ? C.green : type === 'danger' ? C.red : C.teal;
  slide.addShape(pptx.ShapeType.roundRect, { x, y, w, h, rectRadius: .08, fill: { color: fill }, line: { color, width: 1.2 }, shadow: { type: 'outer', color: 'AAB9AE', opacity: .14, blur: 1, angle: 45, distance: 1 } });
  slide.addText(text, { x: x + .08, y: y + .07, w: w - .16, h: h - .14, fontSize: 10.5, color: C.ink, bold: type !== 'normal', align: 'center', valign: 'mid', breakLine: false, margin: .02, fit: 'shrink' });
}

function arrow(slide, x, y, label = '') {
  slide.addText('→', { x, y, w: .34, h: .28, fontSize: 20, bold: true, color: C.green, align: 'center', margin: 0 });
  if (label) slide.addText(label, { x: x - .01, y: y + .26, w: .38, h: .18, fontSize: 7.5, color: '537061', align: 'center', margin: 0 });
}

function footer(slide) {
  slide.addText('SEMOP • Prefeitura de Valença • Fluxo do MVP', { x: .55, y: 7.15, w: 8, h: .18, fontSize: 8.5, color: '537061', margin: 0 });
}

function touristSlide(titleText, identity, fields) {
  const s = pptx.addSlide();
  title(s, titleText, 'A solicitação só libera a entrada depois da aprovação da pousada/hotel e da validação do período.');
  const labels = ['Inicia cadastro', identity, fields, 'Seleciona pousada/hotel\ne período da estadia', 'Cadastra veículo\nplaca • marca • modelo • cor', 'Solicita acesso à Orla\ne compartilha link no WhatsApp', 'Pousada/hotel\naprova a solicitação', 'Fiscal valida QR/placa,\nperíodo e pousada na Orla'];
  const xs = [.45, 2.08, 3.72, 5.36, 7.00, 8.64, 10.28, 11.92];
  labels.forEach((label, index) => box(s, label, xs[index], 2.42, 1.3, 1.04, index === 6 ? 'decision' : index === 7 ? 'success' : 'normal'));
  for (let i = 0; i < labels.length - 1; i++) arrow(s, xs[i] + 1.3, 2.77);
  box(s, 'Não aprovada\nstatus recusado', 10.28, 4.55, 1.3, .78, 'danger');
  s.addText('não', { x: 10.75, y: 3.65, w: .35, h: .22, fontSize: 9, color: C.red, bold: true, align: 'center', margin: 0 });
  s.addShape(pptx.ShapeType.downArrow, { x: 10.75, y: 3.84, w: .34, h: .54, fill: { color: C.red }, line: { color: C.red } });
  s.addText('sim', { x: 11.62, y: 3.65, w: .3, h: .22, fontSize: 9, color: C.green, bold: true, align: 'center', margin: 0 });
  s.addText('Resultado: acesso ativo apenas enquanto a estadia estiver vigente.', { x: .7, y: 5.96, w: 11.9, h: .32, fontSize: 14, bold: true, color: C.green, align: 'center', margin: 0 });
  footer(s);
}

touristSlide('Turista — pessoa física', 'Turista + pessoa física', 'Dados pessoais\nCPF • e-mail único • senha');
touristSlide('Turista — pessoa jurídica', 'Turista + pessoa jurídica', 'Razão social\nCNPJ • telefone • e-mail único');

const s = pptx.addSlide();
title(s, 'Pousada/hotel — cadastro e aprovação de hóspede', 'A pousada pode aprovar a solicitação enviada pelo turista ou cadastrar diretamente o hóspede e seu veículo.');
box(s, 'Login da pousada/hotel', .55, 2.05, 1.55, .82);
arrow(s, 2.12, 2.31);
box(s, 'Meus serviços\nHóspedes', 2.48, 2.05, 1.55, .82);
arrow(s, 4.05, 2.31);
box(s, 'Escolhe a origem\ndo atendimento', 4.42, 2.05, 1.55, .82, 'decision');
box(s, 'Solicitação enviada\npelo turista', 3.25, 3.72, 1.55, .82);
box(s, 'Cadastro feito\npela pousada', 6.25, 3.72, 1.55, .82);
s.addShape(pptx.ShapeType.downArrow, { x: 4.98, y: 2.93, w: .34, h: .56, fill: { color: C.gold }, line: { color: C.gold } });
arrow(s, 4.85, 4.01);
box(s, 'Confere hóspede,\nveículo e período', 5.22, 3.72, 1.55, .82);
arrow(s, 6.78, 4.01);
box(s, 'Aprova ou recusa\no acesso', 7.15, 3.72, 1.55, .82, 'decision');
arrow(s, 8.72, 4.01);
box(s, 'Status aprovado\nou recusado', 9.08, 3.72, 1.55, .82, 'success');
s.addShape(pptx.ShapeType.downArrow, { x: 7.07, y: 2.93, w: .34, h: .56, fill: { color: C.gold }, line: { color: C.gold } });
arrow(s, 7.82, 4.01);
box(s, 'Informa hóspede,\nveículo e período', 8.18, 3.72, 1.55, .82);
arrow(s, 9.75, 4.01);
box(s, 'Marca liberar acesso,\ngera QR e envia WhatsApp', 10.12, 3.72, 2.25, .82, 'success');
s.addText('Nos dois caminhos, o fiscal confere QR Code ou placa, período da estadia e autorização da pousada na área da Orla.', { x: .75, y: 5.75, w: 11.7, h: .38, fontSize: 14, bold: true, color: C.green, align: 'center', margin: 0 });
footer(s);

pptx.writeFile({ fileName: out });
