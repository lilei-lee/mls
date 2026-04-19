import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/listing_create_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/listing_edit_screen.dart';
import '../screens/listing_list_screen.dart';
import '../screens/listing_shared_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

/// 全局 Navigator 钥匙,让 ApiClient 等非 UI 代码也能跳转页面
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 全局路由配置
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final name = state.uri.queryParameters['name'] ?? '';
        return HomeScreen(name: name);
      },
    ),
    GoRoute(
      path: '/listings/mine',
      builder: (context, state) => const ListingListScreen(),
    ),
    GoRoute(
      path: '/listings/shared',
      builder: (context, state) => const ListingSharedScreen(),
    ),
    GoRoute(
      path: '/listing/new',
      builder: (context, state) => const ListingCreateScreen(),
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) => ListingDetailScreen(
        listingId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/listing/:id/edit',
      builder: (context, state) => ListingEditScreen(
        listingId: state.pathParameters['id']!,
        original: state.extra as Map<String, dynamic>,
      ),
    ),
  ],
);