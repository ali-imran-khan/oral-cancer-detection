import 'package:flutter/material.dart';
import 'navigation screens/home_screen.dart';
import 'navigation screens/scan_screen.dart';
import 'navigation screens/reports_screen.dart';
import 'navigation screens/profile_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  NavigationScreenState createState() => NavigationScreenState();
}

class NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    HomeScreen(onOpenScan: () {}), // Will be replaced below
    const ScanScreen(),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Home',
    'Scan',
    'Reports',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    // Replace HomeScreen with callback
    _screens[0] = HomeScreen(onOpenScan: () => _goToScan());
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _goToScan() {
    onItemTapped(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        // Allow swipe navigation by removing physics
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_drive_file), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
