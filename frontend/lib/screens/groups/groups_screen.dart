import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/group_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadGroups();
    });
  }

  void _createGroup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CreateGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(icon: const Icon(Icons.group_add_outlined), onPressed: _createGroup),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (_, chat, __) {
          if (chat.loading && chat.groups.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (chat.groups.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            onRefresh: () => chat.loadGroups(),
            color: AppTheme.primary,
            child: ListView.builder(
              itemCount: chat.groups.length,
              itemBuilder: (_, i) => _buildGroupTile(chat.groups[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.group_add_rounded),
      ),
    );
  }

  Widget _buildGroupTile(GroupModel group) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: group.avatar != null
          ? CircleAvatar(backgroundImage: NetworkImage(group.avatar!), radius: 26)
          : CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(group.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text('${group.memberCount} members', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.onSurfaceMuted),
      onTap: () => Navigator.pushNamed(context, '/group-chat', arguments: {
        'groupId': group.id,
        'groupName': group.name,
      }),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 72, color: AppTheme.onSurfaceMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No groups yet', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await context.read<ChatProvider>().createGroup(name, []);
    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group Name'),
            autofocus: true,
          ),
          const SizedBox(height: 20),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ElevatedButton(onPressed: _create, child: const Text('Create')),
        ],
      ),
    );
  }
}
