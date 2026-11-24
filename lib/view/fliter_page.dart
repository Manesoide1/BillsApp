import 'dart:async';

import 'package:bills_app/components/my_add_bill_button.dart';
import 'package:bills_app/components/my_bill.dart';
import 'package:bills_app/components/my_botton_nav.dart';
import 'package:bills_app/components/my_filter_app_bar.dart';
import 'package:bills_app/services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  int _filtroSelecionado = 0; // 0: Pagas, 1: Pendentes, 2: Atrasadas
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

  bool _correspondeAoFiltro(bool isPaid, DateTime dueDate) {
    final hoje = DateTime.now();
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final dataVencimento = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final bool estaAtrasada = !isPaid && dataVencimento.isBefore(dataHoje);

    switch (_filtroSelecionado) {
      case 0: // Pagas
        return isPaid;
      case 1: // Pendentes (não pagas e não atrasadas)
        return !isPaid && !estaAtrasada;
      case 2: // Atrasadas
        return estaAtrasada;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: MyFilterAppBar(
        selectedIndex: _filtroSelecionado,
        onSelect: (index) {
          setState(() {
            _filtroSelecionado = index;
          });
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('bills')
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

            final allDocs = snapshot.data?.docs ?? [];

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

                final List<Map<String, dynamic>> combinedBills =
                    [
                        ...allDocs.map((doc) {
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
                        ...pending.creates,
                      ].where((bill) {
                        return _correspondeAoFiltro(
                          bill['isPaid'] as bool,
                          bill['dueDate'] as DateTime,
                        );
                      }).toList()
                      ..sort(
                        (a, b) => (a['dueDate'] as DateTime).compareTo(
                          b['dueDate'] as DateTime,
                        ),
                      );

                if (combinedBills.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma conta encontrada para este filtro.',
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
      bottomNavigationBar: const MyBottomNav(currentIndex: 1),
    );
  }
}
