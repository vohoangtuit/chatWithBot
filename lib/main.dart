import 'package:chat_bot_ai/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: TextSelectionThemeData(
          selectionHandleColor: Colors.transparent,
        ),
      ),
      home: MainScreen(),
    );
  }
}
// tôi
