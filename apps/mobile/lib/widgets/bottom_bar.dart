import 'package:flutter/material.dart';

/// Bottom tab bar shared by the Student and Family shells.
class LLBottomBar extends StatelessWidget {
  const LLBottomBar({super.key, required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        destinations: [
          for (final (o, s, l) in items) NavigationDestination(icon: Icon(o), selectedIcon: Icon(s), label: l),
        ],
      ),
    );
  }
}
