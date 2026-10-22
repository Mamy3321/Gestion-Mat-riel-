import 'package:flutter/material.dart';

import 'api.dart';
import 'app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Api.init();
  await AppTheme.init();

  runApp(
    const GestionMaterielApp(),
  );
}

class GestionMaterielApp extends StatelessWidget {
  const GestionMaterielApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDark,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Gestion Matériel',
          debugShowCheckedModeBanner: false,

          themeMode: isDark
              ? ThemeMode.dark
              : ThemeMode.light,

          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.light,
          ),

          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),

          home: Api.token == null
              ? const LoginScreen()
              : const HomeShell(),
        );
      },
    );
  }
}