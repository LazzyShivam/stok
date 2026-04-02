import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';
import 'services/webrtc_service.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/call_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/groups/group_chat_screen.dart';
import 'screens/channels/channel_screen.dart';
import 'screens/calls/video_call_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/agent_creation_screen.dart';
import 'screens/users/user_search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize services
  final apiService = ApiService();
  final authService = AuthService(apiService);
  final socketService = SocketService();
  final webrtcService = WebRTCService(socketService);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<SocketService>.value(value: socketService),
        Provider<WebRTCService>.value(value: webrtcService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService, apiService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(apiService, socketService)),
        ChangeNotifierProvider(create: (_) => PresenceProvider(socketService)),
        ChangeNotifierProvider(create: (_) => CallProvider(socketService, webrtcService)),
      ],
      child: const StokApp(),
    ),
  );
}

class StokApp extends StatelessWidget {
  const StokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/otp': (_) => const OtpScreen(),
        '/profile-setup': (_) => const ProfileSetupScreen(),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/agent-creation': (_) => const AgentCreationScreen(),
        '/user-search': (_) => const UserSearchScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => ChatScreen(conversationId: args['conversationId'] as String, title: args['title'] as String, avatarUrl: args['avatarUrl'] as String?, userId: args['userId'] as String?));
          case '/group-chat':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: args['groupId'] as String, groupName: args['groupName'] as String));
          case '/channel':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => ChannelScreen(channelId: args['channelId'] as String, channelName: args['channelName'] as String));
          case '/video-call':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(fullscreenDialog: true, builder: (_) => VideoCallScreen(callId: args['callId'] as String, remoteUserId: args['remoteUserId'] as String, remoteUserName: args['remoteUserName'] as String, isVideo: args['isVideo'] as bool, isIncoming: args['isIncoming'] as bool? ?? false, offer: args['offer'] as Map<String, dynamic>?));
          case '/event-detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: args['eventId'] as String));
          default:
            return null;
        }
      },
    );
  }
}
