import 'package:flutter/material.dart';
import 'features/home/ui/screens/home_screen.dart';

class VehicleAiTestApp extends StatelessWidget {
  const VehicleAiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vehicle AI System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xfff6f7fb),
      ),
      home: const HomeScreen(),
    );
  }
}
