import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/background_sync.dart';
import 'services/session_service.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar Firebase.
  await Firebase.initializeApp();
  
  // 2. Establecer la sesión antes de iniciar WorkManager.
  await SessionService.instance.ensureUser();

  // 3. Configurar las tareas en segundo plano.
  await configureBackgroundSync();

  // 4. Iniciar la aplicación.
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Semana 11 - Offline First',
      home: HomeScreen(),
    ),
  );
}