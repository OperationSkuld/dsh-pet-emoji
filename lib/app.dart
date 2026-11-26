import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_services.dart';
import 'core/app_links.dart';
import 'platform/pet_window_service.dart';
import 'presentation/pet/home_shell.dart';
import 'presentation/theme/app_theme.dart';

class DshPetApp extends StatelessWidget {
  const DshPetApp({super.key, required this.services, required this.window});

  final AppServices services;
  final PetWindowService window;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeShell(services: services, window: window),
    );
  }
}
