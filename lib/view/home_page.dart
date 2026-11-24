import 'dart:async';

import 'package:bills_app/components/my_add_bill_button.dart';
import 'package:bills_app/components/my_bill.dart';
import 'package:bills_app/components/my_botton_nav.dart';
import 'package:bills_app/services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _dataSelecionada = DateTime.now();
  StreamSubscription<int>? _syncSub;

  @override
  void initState() {
    super.initState();
    SyncService.instance.ensureAutoSyncStarted();
    SyncService.instance.syncPendingBills();
    _syncSub = SyncService.instance.onSyncCompleted.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contas sincronizadas com o Firebase!')),
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

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

    final List<int> anos = List.generate(
      DateTime.now().year - 2020 + 10,
      (index) => 2020 + index,
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Selecionar Mês e Ano',
            textAlign: TextAlign.center,
          ),
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
                          nomeMes,
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _dataSelecionada = DateTime(
                    anoSelecionadoTemp,
                    mesSelecionadoTemp,
                    1,
                  );
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarModalFormulario({
    String? billId,
    String nomeInicial = '',
    String descricaoInicial = '',
    String valorInicial = '',
    DateTime? dataInicial,
  }) {
    final bool isEditing = billId != null;
    final nameController = TextEditingController(text: nomeInicial);
    final descriptionController = TextEditingController(text: descricaoInicial);
    final valueController = TextEditingController(text: valorInicial);
    DateTime dueDateTemp = dataInicial ?? DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setStateModal) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Editar Conta'
                    : (nomeInicial.isEmpty
                          ? 'Adicionar Nova Conta'
                          : 'Revisar Dados da Conta'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Nome da conta',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vencimento: ${DateFormat('dd/MM/yyyy').format(dueDateTemp)}',
                        ),
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final DateTime? pickedDate =
                                      await showDatePicker(
                                        context: modalContext,
                                        initialDate: dueDateTemp,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(DateTime.now().year + 40),
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String name = nameController.text.trim();
                          final String description = descriptionController.text
                              .trim();
                          final double? value = double.tryParse(
                            valueController.text.replaceAll(',', '.'),
                          );

                          if (name.isEmpty || value == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Preencha o nome e um valor válido!',
                                ),
                              ),
                            );
                            return;
                          }

                          setStateModal(() => isSaving = true);

                          try {
                            final resultado = await SyncService.instance
                                .saveOrUpdateBill(
                                  billId: billId,
                                  name: name,
                                  description: description,
                                  value: value,
                                  dueDate: dueDateTemp,
                                );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (!mounted) return;
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(resultado.message)),
                            );
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao salvar: $e')),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Atualizar' : 'Salvar'),
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

    final DateTime primeiroDiaMes = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month,
      1,
    );
    final DateTime ultimoDiaMes = DateTime(
      _dataSelecionada.year,
      _dataSelecionada.month + 1,
      0,
      23,
      59,
      59,
    );

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
              .where(
                'dueDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(primeiroDiaMes),
              )
              .where(
                'dueDate',
                isLessThanOrEqualTo: Timestamp.fromDate(ultimoDiaMes),
              )
              .orderBy('dueDate', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Erro ao carregar contas: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            return FutureBuilder<
              ({
                List<Map<String, dynamic>> creates,
                Map<String, Map<String, dynamic>> updatesByBillId,
              })
            >(
              future: SyncService.instance.getPendingChanges(user.uid),
              builder: (context, localSnapshot) {
                final pending =
                    localSnapshot.data ??
                    (
                      creates: [],
                      updatesByBillId: <String, Map<String, dynamic>>{},
                    );

                final localCreates = pending.creates.where((item) {
                  final DateTime d = item['dueDate'] as DateTime;
                  return !d.isBefore(primeiroDiaMes) &&
                      !d.isAfter(ultimoDiaMes);
                }).toList();

                final List<Map<String, dynamic>> combinedBills =
                    [
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final pendingUpdate = pending.updatesByBillId[doc.id];

                        return <String, dynamic>{
                          'id': doc.id,
                          'name': pendingUpdate != null
                              ? pendingUpdate['name']
                              : (data['name'] ?? ''),
                          'description': pendingUpdate != null
                              ? pendingUpdate['description']
                              : data['description'],
                          'value': pendingUpdate != null
                              ? pendingUpdate['value']
                              : (data['value'] ?? 0).toDouble(),
                          'dueDate': pendingUpdate != null
                              ? pendingUpdate['dueDate']
                              : (data['dueDate'] as Timestamp).toDate(),
                          'isPaid': data['isPaid'] ?? false,
                          'isOfflinePending': false,
                          'hasPendingUpdate': pendingUpdate != null,
                        };
                      }),
                      ...localCreates,
                    ]..sort(
                      (a, b) => (a['dueDate'] as DateTime).compareTo(
                        b['dueDate'] as DateTime,
                      ),
                    );

                if (combinedBills.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma conta cadastrada para este mês.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: combinedBills.length,
                  itemBuilder: (context, index) {
                    final bill = combinedBills[index];
                    final bool isOfflinePending =
                        bill['isOfflinePending'] == true;
                    final bool hasPendingUpdate =
                        bill['hasPendingUpdate'] == true;
                    final String? docId = bill['id'] as String?;

                    final String name = bill['name'] as String;
                    final String? description = bill['description'] as String?;
                    final double value = bill['value'] as double;
                    final bool isPaid = bill['isPaid'] as bool;
                    final DateTime dueDate = bill['dueDate'] as DateTime;

                    final bool showPendingLabel =
                        isOfflinePending || hasPendingUpdate;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MyBill(
                        name: showPendingLabel
                            ? '$name (sinc. pendente)'
                            : name,
                        description: description,
                        value: value,
                        dueDate: dueDate,
                        isPaid: isPaid,
                        onTap: isOfflinePending
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Aguardando conexão para sincronizar esta conta.',
                                    ),
                                  ),
                                );
                              }
                            : () => _mostrarModalFormulario(
                                billId: docId,
                                nomeInicial: name,
                                descricaoInicial: description ?? '',
                                valorInicial: value.toString(),
                                dataInicial: dueDate,
                              ),
                        onChanged: (novoStatus) async {
                          if (isOfflinePending || docId == null) return;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('bills')
                              .doc(docId)
                              .update({'isPaid': novoStatus});
                        },
                        onDelete: () async {
                          if (isOfflinePending || docId == null) return;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('bills')
                              .doc(docId)
                              .delete();
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: MyAddBillButton(
        onOpenForm: (prefill) => _mostrarModalFormulario(
          nomeInicial: prefill?.name ?? '',
          valorInicial: prefill != null ? prefill.value.toString() : '',
          dataInicial: prefill?.dueDate,
        ),
      ),
      bottomNavigationBar: MyBottomNav(
        currentIndex: 0,
        onFilterTap: _listaMeses,
      ),
    );
  }
}
