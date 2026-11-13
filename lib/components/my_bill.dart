import 'package:flutter/material.dart';

class MyBill extends StatelessWidget {
  const MyBill({
    super.key,
    required this.name,
    this.description,
    required this.value,
    required this.dueDate,
    required this.isPaid,
    required this.onChanged,
    required this.onDelete, // <-- Novo parâmetro para lidar com a exclusão
  });

  final String name;
  final String? description;
  final double value;
  final DateTime dueDate;
  final bool isPaid;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete; // <-- Função chamada ao confirmar a exclusão

  @override
  Widget build(BuildContext context) {
    // 1. Lógica para definir o status com base na data e no pagamento
    final hoje = DateTime.now();
    // Zera as horas para comparar apenas os dias de forma justa
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final dataVencimento = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final bool estaAtrasada = !isPaid && dataVencimento.isBefore(dataHoje);

    // 2. Define a cor, ícone e texto de acordo com o estado
    final Color corStatus;
    final String textoStatus;
    final IconData iconeStatus;

    if (isPaid) {
      corStatus = Colors.green;
      textoStatus = 'Pago';
      iconeStatus = Icons.check;
    } else if (estaAtrasada) {
      corStatus = Colors.red;
      textoStatus = 'Atrasada';
      iconeStatus = Icons.warning_amber_rounded;
    } else {
      corStatus = Colors.amber;
      textoStatus = 'Pendente';
      iconeStatus = Icons.schedule;
    }

    // Função que exibe a janela de confirmação antes de apagar
    void _confirmarExclusao() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir Conta'),
          content: Text('Deseja realmente apagar a conta "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // Fecha o diálogo sem apagar
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop(); // Fecha o diálogo
                onDelete(); // Executa a função de exclusão passada pela HomePage
              },
              child: const Text('Apagar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xFF0D9488), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Conteúdo principal da conta
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description != null && description!.isNotEmpty)
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Valor: R\$ ${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Vencimento: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                  style: TextStyle(
                    fontSize: 16,
                    color: !isPaid ? corStatus : Colors.grey,
                    fontWeight: estaAtrasada ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                // Espaço extra embaixo para os botões não sobreporem o texto
                const SizedBox(height: 35), 
              ],
            ),
            
            // Botão de Excluir no canto inferior esquerdo (Lixeira vermelha)
            Positioned(
              bottom: 0,
              left: 0,
              child: GestureDetector(
                onTap: _confirmarExclusao, // Abre a caixa de diálogo de confirmação
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.red,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Apagar',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botão de Status no canto inferior direito dinâmico (Amarelo, Vermelho ou Verde)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => onChanged(!isPaid), // Alterna o estado ao tocar
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: corStatus.withOpacity(0.2),
                    border: Border.all(
                      color: corStatus,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconeStatus,
                        color: corStatus,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        textoStatus,
                        style: TextStyle(
                          color: corStatus,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}