import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget for the GoalPulse application.
///
/// Uses [ConsumerWidget] so the [GoRouter] instance (which depends on auth
/// state) can be read from Riverpod.
class GoalPulseApp extends ConsumerWidget {
  const GoalPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'GoalPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
