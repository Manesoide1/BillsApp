import 'dart:io';

import 'package:bills_app/services/gemini_api.dart';
import 'package:bills_app/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BillFormPrefill {
  final String name;
  final double value;
  final DateTime dueDate;

  const BillFormPrefill({
    required this.name,
    required this.value,
    required this.dueDate,
  });
}

class MyAddBillButton extends StatelessWidget {
  const MyAddBillButton({super.key, required this.onOpenForm});

  final ValueChanged<BillFormPrefill?> onOpenForm;

  void _mostrarAlertaSemConexao(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sem conexão com a internet. O Gemini AI requer internet; use o preenchimento manual.',
        ),
      ),
    );
  }

  Future<void> _mostrarOpcoesAdicionar(BuildContext context) async {
    final bool isOnline = await SyncService.instance.hasConnection();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.teal),
              title: const Text('Preencher manualmente'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onOpenForm(null);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: isOnline ? Colors.teal : Colors.grey,
              ),
              title: Text(
                'Tirar foto da conta (Gemini AI)',
                style: TextStyle(color: isOnline ? null : Colors.grey),
              ),
              subtitle: isOnline
                  ? null
                  : const Text(
                      'Indisponível sem internet',
                      style: TextStyle(fontSize: 12),
                    ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (!isOnline) {
                  _mostrarAlertaSemConexao(context);
                  return;
                }
                _processarImagemComGemini(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: isOnline ? Colors.teal : Colors.grey,
              ),
              title: Text(
                'Selecionar imagem do dispositivo (Gemini AI)',
                style: TextStyle(color: isOnline ? null : Colors.grey),
              ),
              subtitle: isOnline
                  ? null
                  : const Text(
                      'Indisponível sem internet',
                      style: TextStyle(fontSize: 12),
                    ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (!isOnline) {
                  _mostrarAlertaSemConexao(context);
                  return;
                }
                _processarImagemComGemini(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processarImagemComGemini(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile == null || !context.mounted) return;

    final File arquivoImagem = File(pickedFile.path);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 15),
            Text(
              'Gemini analisando a conta...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      final resultado = await GeminiService.extractBillFromImage(arquivoImagem);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Fecha o loading

      onOpenForm(
        BillFormPrefill(
          name: resultado.name,
          value: resultado.value,
          dueDate: resultado.dueDate,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Fecha o loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao ler a conta com o Gemini: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: FloatingActionButton(
        onPressed: () => _mostrarOpcoesAdicionar(context),
        child: const Icon(Icons.add, size: 35),
      ),
    );
  }
}
