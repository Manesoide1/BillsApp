import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class BillExtractionResult {
  final String name;
  final double value;
  final DateTime dueDate;

  const BillExtractionResult({
    required this.name,
    required this.value,
    required this.dueDate,
  });
}

class GeminiService {
  // Cole aqui a chave gerada no Google AI Studio (começa com AIzaSy...)
  static const String _apiKey = 'COLE_AQUI_SUA_CHAVE_DE_API_DO_GOOGLE_AI_STUDIO';

  static Future<BillExtractionResult> extractBillFromImage(File imageFile) async {

    final model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: _apiKey,
    );

    final imageBytes = await imageFile.readAsBytes();

    final prompt = TextPart(
      'Analise esta imagem de conta, fatura ou boleto. '
      'Extraia as seguintes informações e retorne APENAS um objeto JSON válido (sem blocos de código markdown ou texto extra): '
      '{"name": "Nome da empresa ou fornecedor", "value": 00.00 (formato numérico com ponto para centavos), "dueDate": "AAAA-MM-DD" (data de vencimento no formato yyyy-mm-dd. Se não encontrar, use a data de hoje)} '
      'Certifique-se de que o JSON seja válido e não inclua explicações ou texto adicional. Se não conseguir identificar algum campo, retorne um valor padrão (ex: "" para strings, 0.0 para valores numéricos).',
    );

    final imagePart = DataPart('image/jpeg', imageBytes);

    final response = await model.generateContent([
      Content.multi([prompt, imagePart]),
    ]);

    final respostaTexto = response.text?.trim() ?? '';
    final jsonLimpo = respostaTexto
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final Map<String, dynamic> dadosExtraidos = jsonDecode(jsonLimpo);

    final String nomeExtraido = (dadosExtraidos['name'] ?? '').toString();
    final num valorBruto = dadosExtraidos['value'] is num
        ? dadosExtraidos['value'] as num
        : num.tryParse(dadosExtraidos['value']?.toString().replaceAll(',', '.') ?? '') ?? 0.0;
    final DateTime dataExtraida =
        DateTime.tryParse(dadosExtraidos['dueDate']?.toString() ?? '') ?? DateTime.now();

    return BillExtractionResult(
      name: nomeExtraido,
      value: valorBruto.toDouble(),
      dueDate: dataExtraida,
    );
  }
}