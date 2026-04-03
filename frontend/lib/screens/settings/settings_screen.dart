import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/socket_service.dart';
import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../../models/user_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.surface,
            child: Row(
              children: [
                UserAvatar(userId: user.id, avatarUrl: user.avatar, name: user.name, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name.isEmpty ? 'Set Name' : user.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(user.phone, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 14)),
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(user.bio!, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                  onPressed: () => _showEditProfile(context, user),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Account section
          _sectionHeader('Account'),
          _settingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {},
          ),
          _settingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            onTap: () {},
          ),
          _settingsTile(
            icon: Icons.lock_outlined,
            title: 'Security',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // AI Agents section
          _sectionHeader('AI Agents'),
          _settingsTile(
            icon: Icons.smart_toy_outlined,
            title: 'Manage AI Agents',
            subtitle: 'Create and configure AI conversation agents',
            onTap: () => Navigator.pushNamed(context, '/agent-creation'),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 8),

          // App section
          _sectionHeader('App'),
          _buildThemeTile(context),
          _settingsTile(
            icon: Icons.storage_outlined,
            title: 'Storage & Data',
            onTap: () {},
          ),
          _settingsTile(
            icon: Icons.phone_android_outlined,
            title: 'Linked Devices',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // About
          _sectionHeader('About'),
          _settingsTile(
            icon: Icons.info_outline,
            title: 'About Stok',
            subtitle: 'Version ${AppConfig.appName} 1.0.0',
            onTap: () {},
          ),
          _settingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
              label: const Text('Logout', style: TextStyle(color: AppTheme.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          themeProvider.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          size: 20,
          color: AppTheme.onSurface,
        ),
      ),
      title: const Text('Appearance', style: TextStyle(fontSize: 15)),
      subtitle: Text(
        themeProvider.isDark ? 'Dark theme' : 'Light theme',
        style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
      ),
      trailing: Switch(
        value: themeProvider.isDark,
        onChanged: (_) => themeProvider.toggleTheme(),
        activeColor: AppTheme.primary,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppTheme.onSurface),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.onSurfaceMuted, size: 18),
      onTap: onTap,
    );
  }

  void _showEditProfile(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final bioCtrl = TextEditingController(text: user.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 2),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await context.read<AuthProvider>().updateProfile(name: nameCtrl.text.trim(), bio: bioCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SocketService>().disconnect();
    await context.read<AuthProvider>().logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }
}
