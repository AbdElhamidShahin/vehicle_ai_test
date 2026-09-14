import 'package:flutter/material.dart';
import 'live_speech_feature.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(           // ← ده اللي كان ناقص
      title: 'Car Data Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home:  const LiveSpeechScreen(),
    );
  }
}