import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_list_screen.dart';
import '../groups/groups_screen.dart';
import '../channels/channels_screen.dart';
import '../events/events_screen.dart';
import '../settings/settings_screen.dart';
import '../contacts/contacts_screen.dart';
import '../../widgets/incoming_call_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    ChatListScreen(),
    ContactsScreen(),
    GroupsScreen(),
    ChannelsScreen(),
    EventsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _currentIndex, children: _tabs),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
                BottomNavigationBarItem(icon: Icon(Icons.contacts_outlined), activeIcon: Icon(Icons.contacts_rounded), label: 'Contacts'),
                BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group_rounded), label: 'Groups'),
                BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign_rounded), label: 'Channels'),
                BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event_rounded), label: 'Events'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
          ),
        ),
        // Incoming call overlay
        Consumer<CallProvider>(
          builder: (_, call, __) {
            if (!call.hasIncomingCall) return const SizedBox.shrink();
            return IncomingCallOverlay(callData: call.incomingCall!);
          },
        ),
      ],
    );
  }
}
