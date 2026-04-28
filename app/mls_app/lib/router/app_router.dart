import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../widgets/bottom_nav.dart';
import '../screens/customer_create_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/direct_showing_create_screen.dart';
import '../screens/listing_create_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/listing_edit_screen.dart';
import '../screens/listing_list_screen.dart';
import '../screens/listing_shared_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/showing_request_create_screen.dart';
import '../screens/showing_request_sent_screen.dart';
import '../screens/showing_request_received_screen.dart';
import '../screens/showing_request_detail_screen.dart';
import '../screens/showing_submit_screen.dart';
import '../screens/showing_confirm_screen.dart';
import '../screens/showing_pending_confirm_screen.dart';
import '../screens/transaction_initiate_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../screens/transaction_pending_la_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/settlement_pending_screen.dart';
import '../screens/settlement_detail_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        // Day 11:/home 改为 5 Tab 主 Shell
        // ?tab=0~4 可指定初始 Tab(默认 0 工作台)
        final tabStr = state.uri.queryParameters['tab'];
        final initial = int.tryParse(tabStr ?? '0') ?? 0;
        return MainShell(initialIndex: initial);
      },
    ),
    GoRoute(
      path: '/settlements/pending-my',
      builder: (context, state) => const SettlementPendingScreen(),
    ),
    GoRoute(
      path: '/settlements/:id',
      builder: (context, state) => SettlementDetailScreen(
        settlementId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/listings/mine',
      builder: (context, state) => const ListingListScreen(),
    ),
    GoRoute(
      path: '/listings/shared',
      builder: (context, state) {
        final q = state.uri.queryParameters;
        return ListingSharedScreen(
          newTodayOnly: q['new_today'] == '1',
        );
      }),
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
    GoRoute(
      path: '/showing-request/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ShowingRequestCreateScreen(
          listingId: extra['listing_id'] as String,
          listingSnapshot: extra['snapshot'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: '/showing-requests/sent',
      builder: (context, state) => const ShowingRequestSentScreen(),
    ),
    GoRoute(
      path: '/showing-requests/received',
      builder: (context, state) => const ShowingRequestReceivedScreen(),
    ),
    GoRoute(
      path: '/showing-request/:id',
      builder: (context, state) => ShowingRequestDetailScreen(
        requestId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/showings/pending-confirm',
      builder: (context, state) => const ShowingPendingConfirmScreen(),
    ),
    // Day 16:直接带看(1:N)
    GoRoute(
      path: '/showings/direct/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return DirectShowingCreateScreen(
          listingId: extra['listing_id'] as String,
          listingSnapshot: extra['snapshot'] as Map<String, dynamic>,
          customerLabel: extra['customer_label'] as String,
        );
      },
    ),
    GoRoute(
      path: '/showing/submit',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ShowingSubmitScreen(
          requestId: extra['request_id'] as String,
          snapshot: extra['snapshot'] as Map<String, dynamic>,
        );
      },
    ),
    GoRoute(
      path: '/showing/:id/confirm',
      builder: (context, state) => ShowingConfirmScreen(
        showingId: state.pathParameters['id']!,
      ),
    ),
    // 模块五:成交确认
    GoRoute(
      path: '/transactions/pending-la',
      builder: (context, state) => const TransactionPendingLaScreen(),
    ),
    GoRoute(
      path: '/transaction/initiate',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return TransactionInitiateScreen(
          showingId: extra['showing_id'] as String,
          snapshot: extra['snapshot'] as Map<String, dynamic>,
          listingPriceWan: extra['listing_price_wan'].toString(),
        );
      },
    ),
    GoRoute(
      path: '/transaction/:id',
      builder: (context, state) => TransactionDetailScreen(
        transactionId: state.pathParameters['id']!,
      ),
    ),

    // 模块:客户管理(Day 12)
    GoRoute(
      path: '/customer/new',
      builder: (context, state) => const CustomerCreateScreen(),
    ),
    GoRoute(
      path: '/customer/:id',
      builder: (context, state) => CustomerDetailScreen(
        customerId: state.pathParameters['id']!,
      ),
    ),
  ],
);