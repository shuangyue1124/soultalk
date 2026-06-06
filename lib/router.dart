import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/contact.dart';
import '../pages/main_scaffold.dart';
import '../pages/chat_list/chat_list_page.dart';
import '../pages/chat/chat_page.dart';
import '../pages/contacts/contacts_page.dart';
import '../pages/contacts/contact_detail_page.dart';
import '../pages/discover/discover_page.dart';
import '../pages/discover/moments_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/settings/api_settings_page.dart';
import '../pages/settings/general_settings_page.dart';
import '../pages/settings/extension_settings_page.dart';
import '../pages/delivery/delivery_page.dart';
import '../pages/memory/memory_page.dart';
import '../pages/settings/update_page.dart';
import '../pages/settings/backup_page.dart';
import '../pages/onboarding/onboarding_page.dart';
import 'pc_connect/qrcode_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/chats',
  redirect: (context, state) async {
    final done = await isOnboardingDone();
    final onOnboarding = state.matchedLocation == '/onboarding';
    if (!done && !onOnboarding) return '/onboarding';
    if (done && onOnboarding) return '/chats';
    return null;
  },
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/chats',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatListPage()),
        ),
        GoRoute(
          path: '/contacts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ContactsPage()),
        ),
        GoRoute(
          path: '/discover',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DiscoverPage()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfilePage()),
        ),
      ],
    ),
    GoRoute(
      path: '/chat/:contactId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final contactId = state.pathParameters['contactId']!;
        final contact = state.extra as Contact?;
        return ChatPage(contactId: contactId, contact: contact);
      },
    ),
    GoRoute(
      path: '/contact/detail/:contactId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final contactId = state.pathParameters['contactId']!;
        final contact = state.extra as Contact?;
        return ContactDetailPage(contactId: contactId, contact: contact);
      },
    ),
    GoRoute(
      path: '/settings/api',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ApiSettingsPage(),
    ),
    GoRoute(
      path: '/settings/general',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GeneralSettingsPage(),
    ),
    GoRoute(
      path: '/settings/extensions',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExtensionSettingsPage(),
    ),
    GoRoute(
      path: '/discover/moments',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MomentsPage(),
    ),
    GoRoute(
      path: '/delivery',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DeliveryPage(),
    ),
    GoRoute(
      path: '/settings/update',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UpdatePage(),
    ),
    GoRoute(
      path: '/settings/backup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BackupPage(),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/memory/:contactId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final contactId = state.pathParameters['contactId']!;
        final contact = state.extra as Contact?;
        return MemoryPage(contactId: contactId, contact: contact);
      },
    ),
    GoRoute(
      path: '/pc-connect',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const QRCodePage(),
    ),
  ],
);
