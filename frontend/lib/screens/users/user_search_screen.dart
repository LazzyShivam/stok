import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/chat_provider.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  Timer? _debounce;

  void _search(String q) {
    _debounce?.cancel();
    if (q.isEmpty) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      final data = await context.read<ApiService>().get('/users/search', params: {'q': q}) as List<dynamic>;
      setState(() {
        _results = data.map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
        _loading = false;
      });
    });
  }

  Future<void> _openChat(UserModel user) async {
    setState(() => _loading = true);
    try {
      final conv = await context.read<ChatProvider>().startConversation(user.id);
      if (!mounted) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': conv.id,
        'title': user.name.isEmpty ? user.phone : user.name,
        'avatarUrl': user.avatar,
        'userId': user.id,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start chat: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          onChanged: _search,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name or phone...',
            border: InputBorder.none,
            filled: false,
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _ctrl.text.isEmpty
              ? _buildHint()
              : _results.isEmpty
                  ? const Center(child: Text('No users found', style: TextStyle(color: AppTheme.onSurfaceMuted)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) => _buildUserTile(_results[i]),
                    ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      leading: UserAvatar(userId: user.id, avatarUrl: user.avatar, name: user.name, isAgent: user.isAgent),
      title: Text(user.name.isEmpty ? user.phone : user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: user.isAgent
          ? const Text('AI Agent', style: TextStyle(color: AppTheme.secondary, fontSize: 12))
          : Text(user.phone, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
      onTap: () => _openChat(user),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, size: 64, color: AppTheme.onSurfaceMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Search for people to chat with', style: TextStyle(color: AppTheme.onSurfaceMuted)),
        ],
      ),
    );
  }
}
