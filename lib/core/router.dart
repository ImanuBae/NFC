import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'strings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text(S.loginTitle)),
          body: const Center(child: Text(S.loginTitle)),
        ),
      ),
      GoRoute(
        path: '/kiosk',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text(S.appTitle)),
          body: const Center(child: Text(S.tapCardPrompt)),
        ),
      ),
      GoRoute(
        path: '/admin/days',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text(S.navAttendance)),
          body: const Center(child: Text(S.navAttendance)),
        ),
      ),
    ],
  );
});
