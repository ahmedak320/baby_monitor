import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'utils/platform_info.dart';

class BabyMonitorApp extends ConsumerWidget {
  const BabyMonitorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Baby Monitor',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: PlatformInfo.isTV ? ThemeMode.dark : ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
