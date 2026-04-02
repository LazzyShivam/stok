import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/channel_model.dart';
import '../../theme/app_theme.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<ChannelModel> _all = [];
  List<ChannelModel> _joined = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _loading = true);
    final data = await context.read<ApiService>().get('/channels') as List<dynamic>;
    final channels = data.map((c) => ChannelModel.fromJson(c as Map<String, dynamic>)).toList();
    setState(() {
      _all = channels;
      _joined = channels.where((c) => c.isJoined).toList();
      _loading = false;
    });
  }

  Future<void> _joinChannel(String id) async {
    await context.read<ApiService>().post('/channels/$id/join');
    await _loadChannels();
  }

  void _createChannel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateChannelSheet(onCreated: _loadChannels),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _createChannel),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceMuted,
          tabs: const [Tab(text: 'Discover'), Tab(text: 'My Channels')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_all, showJoin: true),
                _buildList(_joined, showJoin: false),
              ],
            ),
    );
  }

  Widget _buildList(List<ChannelModel> channels, {required bool showJoin}) {
    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 72, color: AppTheme.onSurfaceMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No channels found', style: TextStyle(color: AppTheme.onSurfaceMuted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadChannels,
      color: AppTheme.primary,
      child: ListView.builder(
        itemCount: channels.length,
        itemBuilder: (_, i) => _buildTile(channels[i], showJoin: showJoin),
      ),
    );
  }

  Widget _buildTile(ChannelModel ch, {required bool showJoin}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primary.withOpacity(0.15),
        child: Text(ch.name[0].toUpperCase(),
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      title: Row(
        children: [
          Expanded(child: Text(ch.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (!ch.isPublic)
            const Icon(Icons.lock_outline, size: 14, color: AppTheme.onSurfaceMuted),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ch.description != null)
            Text(ch.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
          Text('${ch.memberCount} subscribers', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
        ],
      ),
      trailing: showJoin && !ch.isJoined
          ? ElevatedButton(
              onPressed: () => _joinChannel(ch.id),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(70, 34),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Join'),
            )
          : null,
      onTap: ch.isJoined
          ? () => Navigator.pushNamed(context, '/channel', arguments: {
                'channelId': ch.id,
                'channelName': ch.name,
              })
          : null,
    );
  }
}

class _CreateChannelSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateChannelSheet({required this.onCreated});

  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;
  bool _loading = false;

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await context.read<ApiService>().post('/channels', data: {
      'name': name,
      'description': _descCtrl.text.trim(),
      'isPublic': _isPublic,
    });
    setState(() => _loading = false);
    if (!mounted) return;
    widget.onCreated();
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
          const Text('Create Channel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Channel Name'), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            title: const Text('Public Channel'),
            subtitle: const Text('Anyone can find and join'),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ElevatedButton(onPressed: _create, child: const Text('Create Channel')),
        ],
      ),
    );
  }
}
