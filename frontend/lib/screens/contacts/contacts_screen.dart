import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _loading = true;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  String? _error;

  List<_ContactItem> _onStok = [];
  List<Contact> _notOnStok = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
      _permissionPermanentlyDenied = false;
    });

    // Request contacts permission
    final status = await Permission.contacts.request();

    if (status.isPermanentlyDenied) {
      setState(() { _loading = false; _permissionPermanentlyDenied = true; });
      return;
    }

    if (!status.isGranted) {
      setState(() { _loading = false; _permissionDenied = true; });
      return;
    }

    try {
      // Fetch all contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final contactsWithPhone = contacts.where((c) => c.phones.isNotEmpty).toList();

      if (contactsWithPhone.isEmpty) {
        setState(() { _loading = false; _onStok = []; _notOnStok = []; });
        return;
      }

      // Build phone→contact map with normalized numbers
      final Map<String, Contact> phoneToContact = {};
      for (final c in contactsWithPhone) {
        for (final phone in c.phones) {
          for (final variant in _phoneVariants(phone.number)) {
            phoneToContact.putIfAbsent(variant, () => c);
          }
        }
      }

      if (phoneToContact.isEmpty) {
        setState(() { _loading = false; _onStok = []; _notOnStok = contactsWithPhone; });
        return;
      }

      // Batch check with backend (max 500 per call)
      final allPhones = phoneToContact.keys.toList();
      final List<UserModel> registeredUsers = [];

      for (int i = 0; i < allPhones.length; i += 500) {
        final chunk = allPhones.sublist(i, i + 500 > allPhones.length ? allPhones.length : i + 500);
        try {
          final api = context.read<ApiService>();
          final result = await api.post('/users/batch-check', data: {'phones': chunk}) as List<dynamic>;
          registeredUsers.addAll(result.map((u) => UserModel.fromJson(u as Map<String, dynamic>)));
        } catch (_) {
          // Skip failed chunk, continue
        }
      }

      // Build "On Stok" list with matched contact names
      final onStokItems = <_ContactItem>[];
      final seenUserIds = <String>{};
      final seenContactIds = <String>{};

      for (final user in registeredUsers) {
        if (seenUserIds.contains(user.id)) continue;
        Contact? matched;
        for (final v in _phoneVariants(user.phone)) {
          if (phoneToContact.containsKey(v)) {
            matched = phoneToContact[v];
            break;
          }
        }
        if (matched != null) seenContactIds.add(matched.id);
        onStokItems.add(_ContactItem(
          user: user,
          contactName: matched?.displayName ?? user.name,
        ));
        seenUserIds.add(user.id);
      }

      // Build "Not on Stok" list
      final notOnStok = contactsWithPhone
          .where((c) => !seenContactIds.contains(c.id))
          .toList();

      setState(() {
        _onStok = onStokItems;
        _notOnStok = notOnStok;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load contacts. Pull to refresh.';
      });
    }
  }

  /// Returns normalized phone variants for matching
  List<String> _phoneVariants(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return [];
    final variants = <String>{digits};
    if (digits.length == 10) {
      variants.add('1$digits');
      variants.add('+1$digits');
    } else if (digits.length == 11 && digits.startsWith('1')) {
      variants.add(digits.substring(1));
      variants.add('+$digits');
    } else if (!digits.startsWith('+')) {
      variants.add('+$digits');
    }
    return variants.toList();
  }

  Future<void> _inviteContact(Contact contact) async {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    if (phone.isEmpty) return;
    final msg = Uri.encodeComponent(
      "Hey! I'm using Stok to chat — it's fast and free. Join me! Search for me by my phone number once you're in.",
    );
    final smsUri = Uri.parse('sms:$phone?body=$msg');
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> _startChat(UserModel user) async {
    try {
      final api = context.read<ApiService>();
      final conv = await api.post('/conversations', data: {'participantId': user.id});
      if (!mounted) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': (conv as Map<String, dynamic>)['id'],
        'participantName': user.name.isNotEmpty ? user.name : user.phone,
        'participantId': user.id,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Syncing contacts...', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14)),
          ],
        ),
      );
    }

    if (_permissionPermanentlyDenied) {
      return _buildPermissionGate(
        icon: Icons.contacts_outlined,
        title: 'Contacts Access Required',
        subtitle: 'Please allow contacts permission in your phone settings so Stok can show which of your contacts are already on the app.',
        buttonLabel: 'Open Settings',
        onButton: openAppSettings,
      );
    }

    if (_permissionDenied) {
      return _buildPermissionGate(
        icon: Icons.contacts_outlined,
        title: 'Contacts Permission Denied',
        subtitle: 'Stok needs contacts access to show which friends are already using the app.',
        buttonLabel: 'Grant Permission',
        onButton: _load,
      );
    }

    if (_error != null) {
      return _buildPermissionGate(
        icon: Icons.wifi_off_rounded,
        title: 'Connection Error',
        subtitle: _error!,
        buttonLabel: 'Retry',
        onButton: _load,
      );
    }

    return _buildContent();
  }

  Widget _buildPermissionGate({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle,
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceMuted, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onButton,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(buttonLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final q = _search.toLowerCase();
    final filteredOnStok = q.isEmpty
        ? _onStok
        : _onStok.where((c) =>
            c.contactName.toLowerCase().contains(q) ||
            c.user.name.toLowerCase().contains(q) ||
            c.user.phone.contains(q)).toList();

    final filteredNotOnStok = q.isEmpty
        ? _notOnStok
        : _notOnStok.where((c) => c.displayName.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.onSurfaceMuted, size: 20),
              filled: true,
              fillColor: const Color(0xFF1C1C2E),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Stats banner
        if (!_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _statChip('${_onStok.length} on Stok', AppTheme.primary),
                const SizedBox(width: 8),
                _statChip('${_notOnStok.length} to invite', AppTheme.onSurfaceMuted),
              ],
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppTheme.primary,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                if (filteredOnStok.isNotEmpty) ...[
                  _sectionHeader(
                    Icons.check_circle_rounded,
                    'ON STOK',
                    AppTheme.primary,
                  ),
                  ...filteredOnStok.map((item) => _buildStokContact(item)),
                ],
                if (filteredNotOnStok.isNotEmpty) ...[
                  _sectionHeader(
                    Icons.person_add_rounded,
                    'INVITE TO STOK',
                    AppTheme.onSurfaceMuted,
                  ),
                  ...filteredNotOnStok.map((c) => _buildInviteContact(c)),
                ],
                if (filteredOnStok.isEmpty && filteredNotOnStok.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.onSurfaceMuted),
                        const SizedBox(height: 12),
                        Text(
                          _search.isNotEmpty ? 'No contacts match "$_search"' : 'No contacts found',
                          style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStokContact(_ContactItem item) {
    final displayName = item.contactName.isNotEmpty ? item.contactName : item.user.name;
    final isOnline = item.user.status == UserStatus.online;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        children: [
          UserAvatar(
            userId: item.user.id,
            name: displayName,
            avatarUrl: item.user.avatar,
            size: 46,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.onlineColor : AppTheme.offlineColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        item.user.phone,
        style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
      ),
      trailing: GestureDetector(
        onTap: () => _startChat(item.user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Message',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteContact(Contact contact) {
    final name = contact.displayName.isNotEmpty ? contact.displayName : 'Unknown';
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: AppTheme.surfaceVariant,
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(phone, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
      trailing: GestureDetector(
        onTap: () => _inviteContact(contact),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ios_share_rounded, size: 13, color: AppTheme.onSurface),
              SizedBox(width: 5),
              Text(
                'Invite',
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem {
  final UserModel user;
  final String contactName;
  const _ContactItem({required this.user, required this.contactName});
}
