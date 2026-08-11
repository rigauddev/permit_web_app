import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/downaload_files.dart';

class ChatObservacoesWidget extends StatefulWidget {
  final String perguntaId;
  final List<dynamic> observacoes;
  final List<String> anexosExistentes;
  final ScrollController scrollController;
  final String userType;

  const ChatObservacoesWidget({
    super.key,
    required this.perguntaId,
    required this.observacoes,
    required this.anexosExistentes,
    required this.scrollController,
    required this.userType,
  });

  @override
  State<ChatObservacoesWidget> createState() => ChatObservacoesWidgetState();
}

class ChatObservacoesWidgetState extends State<ChatObservacoesWidget> {
  final TextEditingController _controller = TextEditingController();
  PlatformFile? _arquivo;
  final baseUrl =
      'https://docs.google.com/document/d/1m4sMMVB85WwWu8C0IMtczhG_N1LOyYEl8tBKJNHroBc/export?format=pdf';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho arrastável
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Lista de mensagens
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.observacoes.length,
            itemBuilder: (ctx, i) {
              final rawObs = widget.observacoes[i];
              final obs =
                  rawObs is Map<String, dynamic>
                      ? rawObs
                      : <String, dynamic>{
                        'user_type': 'operador_secretaria',
                        'user_name': 'Secretaria',
                        'descricao': rawObs.toString(),
                      };
              final userType = obs['user_type']?.toString().toLowerCase() ?? '';
              final isOp =
                  userType == 'operador' ||
                  userType == 'operador_secretaria' ||
                  userType == 'gestor_secretaria' ||
                  userType == 'admin';
              return Align(
                alignment: isOp ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 12,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOp ? Colors.blue[50] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isOp
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      Text(
                        obs['user_name']?.toString() ?? 'Usuário',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(obs['descricao']?.toString() ?? ''),
                      const SizedBox(height: 6),
                      // anexos existentes dentro da mesma pergunta
                      ...widget.anexosExistentes.map(
                        (a) => GestureDetector(
                          onTap: () => downloadAndOpenFile(baseUrl, a),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                a.endsWith('.pdf')
                                    ? Icons.picture_as_pdf
                                    : RegExp(r'\.(png|jpg)$').hasMatch(a)
                                    ? Icons.image
                                    : Icons.attach_file,
                                size: 16,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                a,
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // campo de entrada + ícones
        Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _pickFile,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText:
                        widget.userType.toLowerCase() == 'operador'
                            ? 'Adcionar um comentário...'
                            : 'Responder...',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  minLines: 4,
                  maxLines: 4,
                ),
              ),
              TextButton.icon(
                onPressed: _sendMessage,
                label: const Text('Enviar'),
              ),
              // IconButton(
              //   icon: const Icon(Icons.send, color: Colors.green),
              //   onPressed: _sendMessage,
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (res != null && res.files.single.bytes != null) {
      setState(() => _arquivo = res.files.single);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _arquivo == null) return;

    final uri = Uri.parse('https://sua-api.com/observacoes');
    final req =
        http.MultipartRequest('POST', uri)
          ..fields['descricao'] = text
          ..fields['pergunta_id'] = widget.perguntaId
          ..fields['user_id'] = '456';

    if (_arquivo != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'anexo',
          _arquivo!.bytes!,
          filename: _arquivo!.name,
        ),
      );
    }

    final resp = await req.send();
    if (resp.statusCode == 200) {
      // opcional: atualizar a lista local e limpar o controller
      setState(() {
        widget.observacoes.add({
          'user_type': 'operador',
          'user_name': 'Monica',
          'descricao': text,
        });
        _controller.clear();
        _arquivo = null;
      });
      // rolar até o fim
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Falha ao enviar')));
    }
  }
}
