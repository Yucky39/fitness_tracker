import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'meal_screen.dart';
import 'training_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    MealScreen(),
    TrainingScreen(),
    ProgressScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().userEmail ?? '';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fitness Tracker'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'アカウント',
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(email,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('ログアウト'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'signout') _signOut(context);
            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.restaurant),
            label: '食事',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'トレーニング',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: '進捗',
          ),
        ],
      ),
    );
  }
}
