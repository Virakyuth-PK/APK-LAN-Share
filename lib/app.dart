import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';
import 'theme/app_theme.dart';

class ApkLanShareApp extends StatelessWidget {
  const ApkLanShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APK LAN Share',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const DashboardPage(),
    );
  }
}
