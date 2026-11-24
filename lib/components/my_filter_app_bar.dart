import 'package:flutter/material.dart';

class MyFilterAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyFilterAppBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.height = kToolbarHeight + 8,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.check_circle_outline,
        label: 'Pagas',
        color: Colors.green,
      ),
      (
        icon: Icons.schedule,
        label: 'Pendentes',
        color: Colors.amber,
      ),
      (
        icon: Icons.warning_amber_rounded,
        label: 'Atrasadas',
        color: Colors.red,
      ),
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: height,
      titleSpacing: 0,
      title: Row(
        children: List.generate(items.length, (index) {
          final isSelected = selectedIndex == index;
          final item = items[index];
          final corAtual = isSelected ? item.color : Colors.grey;

          return Expanded(
            child: InkWell(
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? item.color.withOpacity(0.15) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? item.color : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: corAtual,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: corAtual,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}