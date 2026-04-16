import 'package:flutter/material.dart';
import 'screens/topology_screen.dart';

void main() {
  runApp(const MeshNetworkApp());
}

class MeshNetworkApp extends StatelessWidget {
  const MeshNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh Topology Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9C),
          secondary: Color(0xFF00FF9C),
          surface: Color(0xFF0D1520),
        ),
      ),
      home: const TopologyScreen(),
    );
  }
}
