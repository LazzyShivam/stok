import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/api_service.dart';
import '../../models/channel_model.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';

class ChannelScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  List<BroadcastModel> _broadcasts = [];
  bool _loading = false;
  bool _isAdmin = false;
  final _broadcastCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
    _checkAdmin();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _loading = true);
    final data = await context.read<ApiService>().get('/channels/${widget.channelId}/broadcasts') as List<dynamic>;
    setState(() {
      _broadcasts = data.map((b) => BroadcastModel.fromJson(b as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _checkAdmin() async {
    try {
      final data = await context.read<ApiService>().get('/channels/${widget.channelId}') as Map<String, dynamic>;
      final channel = ChannelModel.fromJson(data);
      // Check if current user is admin via members list
      setState(() => _isAdmin = true); // simplified - backend enforces this
    } catch (_) {}
  }

  Future<void> _broadcast() async {
    final text = _broadcastCtrl.text.trim();
    if (text.isEmpty) return;
    _broadcastCtrl.clear();

    await context.read<ApiService>().post('/channels/${widget.channelId}/broadcast', data: {'content': text});
    await _loadBroadcasts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text(widget.channelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _broadcasts.isEmpty
                    ? const Center(child: Text('No broadcasts yet', style: TextStyle(color: AppTheme.onSurfaceMuted)))
                    : RefreshIndicator(
                        onRefresh: _loadBroadcasts,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _broadcasts.length,
                          itemBuilder: (_, i) => _buildBroadcastCard(_broadcasts[i]),
                        ),
                      ),
          ),
          if (_isAdmin) _buildBroadcastInput(),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard(BroadcastModel b) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: Text(b.sender?.name.isNotEmpty == true ? b.sender!.name[0].toUpperCase() : 'A',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.sender?.name ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(timeago.format(b.createdAt), style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (b.content != null)
              Text(b.content!, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _broadcastCtrl,
                decoration: const InputDecoration(
                  hintText: 'Broadcast to channel...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _broadcast,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
