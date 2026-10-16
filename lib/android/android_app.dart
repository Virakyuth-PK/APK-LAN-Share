import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'host_page.dart';

class AndroidShareApp extends StatelessWidget {
  const AndroidShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APK LAN Share',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HostPage(),
    );
  }
}
