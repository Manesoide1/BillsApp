import 'dart:io';
import 'package:apk_auth/components/my_bill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Importação do Gemini
import 'dart:convert';
import './user_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _dataSelecionada = DateTime.now();

  void _alterarMes(int mesesParaMudar) {
    setState(() {
      _dataSelecionada = DateTime(
        _dataSelecionada.year,
        _dataSelecionada.month + mesesParaMudar,
        _dataSelecionada.day,
      );
    });
  }

  void _listaMeses() {
    int mesSelecionadoTemp = _dataSelecionada.month;
    int anoSelecionadoTemp = _dataSelecionada.year;

    final List<int> anos = List.generate(_dataSelecionada.year - 2020 + 2, (index) => 2020 + index);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Selecionar Mês e Ano', textAlign: TextAlign.center),
          content: SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: mesSelecionadoTemp - 1,
                    ),
                    onSelectedItemChanged: (int index) {
                      mesSelecionadoTemp = index + 1;
                    },
                    children: List.generate(12, (index) {
                      final mes = DateTime(2026, index + 1);
                      final nomeMes = toBeginningOfSentenceCase(
                        DateFormat('MMMM', 'pt_BR').format(mes),
                      );
                      return Center(
                        child: Text(
                          nomeMes ?? '',
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: anos.indexOf(anoSelecionadoTemp),
                    ),
                    onSelectedItemChanged: (int index) {
                      anoSelecionadoTemp = anos[index];
                    },
                    children: anos.map((ano) {
                      return Center(
                        child: Text(
                          ano.toString(),
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _dataSelecionada = DateTime(anoSelecionadoTemp, mesSelecionadoTemp, 1);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // 1. Modal para escolher entre Manual ou IA
  void _mostrarOpcoesAdicionar() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.teal),
              title: const Text('Preencher manualmente'),
              onTap: () {
                Navigator.of(context).pop();
                _mostrarModalFormulario();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Tirar foto da conta (Gemini AI)'),
              onTap: () {
                Navigator.of(context).pop();
                _processarImagemComGemini(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('Selecionar imagem do dispositivo (Gemini AI)'),
              onTap: () {
                Navigator.of(context).pop();
                _processarImagemComGemini(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 2. Processa a imagem enviando diretamente para o Google Gemini
  Future<void> _processarImagemComGemini(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile == null) return;

    File arquivoImagem = File(pickedFile.path);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 15),
            Text('Gemini analisando a conta...', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );

    try {
      // Substitua pela sua chave de API válida gerada no Google AI Studio (começa com AIzaSy...)
      const apiKey = 'Chave da API do Gemini aqui'; 

      // Inicializa o modelo Gemini corrigido para a versão Flash estável
      final model = GenerativeModel(
        model: 'gemini-3.5-flash-lite',
        apiKey: apiKey,
      );

      // Lê os bytes da imagem capturada
      final imageBytes = await arquivoImagem.readAsBytes();

      // Prompt estruturado exigindo estritamente um JSON de resposta
      final prompt = TextPart(
        'Analise esta imagem de conta, fatura ou boleto. '
        'Extraia as seguintes informações e retorne APENAS um objeto JSON válido (sem blocos de código markdown ou texto extra): '
        '{"name": "Nome da empresa ou fornecedor", "value": 00.00 (formato numérico com ponto para centavos), "dueDate": "AAAA-MM-DD" (data de vencimento no formato yyyy-mm-dd. Se não encontrar, use a data de hoje)}'
        'Certifique-se de que o JSON seja válido e não inclua explicações ou texto adicional. Se não conseguir identificar algum campo, retorne um valor padrão (ex: "" para strings, 0.0 para valores numéricos).',
      );

      final imagePart = DataPart('image/jpeg', imageBytes);

      // Envia a imagem e o prompt para o Gemini
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final respostaTexto = response.text?.trim() ?? '';
      
      // Limpeza caso o Gemini retorne blocos de código markdown ```json ... ```
      String jsonLimpo = respostaTexto
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> dadosExtraidos = jsonDecode(jsonLimpo);

      String nomeExtraido = dadosExtraidos['name'] ?? '';
      double valorExtraido = (dadosExtraidos['value'] ?? 0.0).toDouble();
      DateTime dataExtraida = DateTime.tryParse(dadosExtraidos['dueDate'] ?? '') ?? DateTime.now();

      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o loading

      // Abre o formulário pré-preenchido com os dados que a IA leu
      _mostrarModalFormulario(
        nomeInicial: nomeExtraido,
        valorInicial: valorExtraido.toString(),
        dataInicial: dataExtraida,
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao ler a conta com o Gemini: $e')),
      );
    }
  }

  // 3. Modal unificado do formulário
  void _mostrarModalFormulario({
    String nomeInicial = '',
    String valorInicial = '',
    DateTime? dataInicial,
  }) {
    final nameController = TextEditingController(text: nomeInicial);
    final descriptionController = TextEditingController();
    final valueController = TextEditingController(text: valorInicial);
    DateTime dueDateTemp = dataInicial ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Text(nomeInicial.isEmpty ? 'Adicionar Nova Conta' : 'Revisar Dados da Conta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome da conta'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(dueDateTemp)}'),
                        TextButton(
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: dueDateTemp,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (pickedDate != null) {
                              setStateModal(() {
                                dueDateTemp = pickedDate;
                              });
                            }
                          },
                          child: const Text('Alterar Data'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    final String description = descriptionController.text.trim();
                    final double? value = double.tryParse(valueController.text.replaceAll(',', '.'));

                    if (name.isEmpty || value == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preencha o nome e um valor válido!')),
                      );
                      return;
                    }

                    try {
                      final user = FirebaseAuth.instance.currentUser!;
                      
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('bills')
                          .add({
                        'name': name,
                        'description': description.isEmpty ? null : description,
                        'value': value,
                        'dueDate': Timestamp.fromDate(dueDateTemp),
                        'isPaid': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Conta salva com sucesso!')),
                      );
                    } catch (e) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao salvar: $e')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    final DateTime primeiroDiaMes = DateTime(_dataSelecionada.year, _dataSelecionada.month, 1);
    final DateTime ultimoDiaMes = DateTime(_dataSelecionada.year, _dataSelecionada.month + 1, 0, 23, 59, 59);

    String mesAnoFormatado =
        toBeginningOfSentenceCase(
          DateFormat('MMMM yyyy', 'pt_BR').format(_dataSelecionada),
        ) ??
        '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_left_sharp, size: 35),
          onPressed: () => _alterarMes(-1),
        ),
        title: TextButton(
          onPressed: () => _listaMeses(),
          child: Text(
            mesAnoFormatado,
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_right_sharp, size: 35),
            onPressed: () => _alterarMes(1),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('bills')
              .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(primeiroDiaMes))
              .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(ultimoDiaMes))
              .orderBy('dueDate', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Erro ao carregar contas: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhuma conta cadastrada para este mês.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final String name = data['name'] ?? '';
                final String? description = data['description'];
                final double value = (data['value'] ?? 0).toDouble();
                final bool isPaid = data['isPaid'] ?? false;
                
                final Timestamp timestamp = data['dueDate'];
                final DateTime dueDate = timestamp.toDate();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MyBill(
                    name: name,
                    description: description,
                    value: value,
                    dueDate: dueDate,
                    isPaid: isPaid,
                    onChanged: (novoStatus) async {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('bills')
                          .doc(docs[index].id)
                          .update({'isPaid': novoStatus});
                    },
                    onDelete: () async {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('bills')
                          .doc(docs[index].id)
                          .delete();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: _mostrarOpcoesAdicionar,
          child: const Icon(Icons.add, size: 35),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            // Lógica para Filtrar
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Filtrar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}