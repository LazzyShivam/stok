import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/chat_provider.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class AgentCreationScreen extends StatefulWidget {
  const AgentCreationScreen({super.key});

  @override
  State<AgentCreationScreen> createState() => _AgentCreationScreenState();
}

class _AgentCreationScreenState extends State<AgentCreationScreen> {
  List<UserModel> _agents = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _loading = true);
    final data = await context.read<ApiService>().get('/agents') as List<dynamic>;
    setState(() {
      _agents = data.map((a) => UserModel.fromJson(a as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _chatWithAgent(UserModel agent) async {
    try {
      final conv = await context.read<ChatProvider>().startConversation(agent.id);
      if (!mounted) return;
      Navigator.pushNamed(context, '/chat', arguments: {
        'conversationId': conv.id,
        'title': agent.name,
        'avatarUrl': agent.avatar,
        'userId': agent.id,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _createAgent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AgentFormSheet(
        onSaved: _loadAgents,
      ),
    );
  }

  void _editAgent(UserModel agent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AgentFormSheet(agent: agent, onSaved: _loadAgents),
    );
  }

  Future<void> _deleteAgent(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Agent'),
        content: const Text('This will permanently delete the AI agent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<ApiService>().delete('/agents/$id');
    await _loadAgents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agents'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _createAgent),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _agents.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _agents.length,
                  itemBuilder: (_, i) => _buildAgentCard(_agents[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAgent,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('New Agent'),
      ),
    );
  }

  Widget _buildAgentCard(UserModel agent) {
    final config = agent.agentConfig ?? {};
    final model = config['model'] as String? ?? 'claude-sonnet-4-6';
    final provider = config['provider'] as String? ?? 'anthropic';
    final prompt = config['systemPrompt'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (agent.bio != null && agent.bio!.isNotEmpty)
                        Text(agent.bio!, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppTheme.surfaceVariant,
                  onSelected: (v) {
                    if (v == 'edit') _editAgent(agent);
                    if (v == 'delete') _deleteAgent(agent.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppTheme.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.error))])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Model: $model', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (provider == 'openai' ? Colors.green : AppTheme.secondary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider == 'openai' ? 'OpenAI' : 'Claude',
                    style: TextStyle(
                      color: provider == 'openai' ? Colors.green : AppTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (prompt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _chatWithAgent(agent),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chat with Agent'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.smart_toy_outlined, size: 48, color: AppTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 20),
          const Text('No AI Agents yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Create agents to automate conversations', style: TextStyle(color: AppTheme.onSurfaceMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createAgent,
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Agent'),
          ),
        ],
      ),
    );
  }
}

class _AgentFormSheet extends StatefulWidget {
  final UserModel? agent;
  final VoidCallback onSaved;

  const _AgentFormSheet({this.agent, required this.onSaved});

  @override
  State<_AgentFormSheet> createState() => _AgentFormSheetState();
}

class _AgentFormSheetState extends State<_AgentFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _promptCtrl;
  late String _model;
  late String _provider;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.agent?.name);
    _bioCtrl = TextEditingController(text: widget.agent?.bio);
    _promptCtrl = TextEditingController(
      text: widget.agent?.agentConfig?['systemPrompt'] as String? ??
          'You are a helpful assistant. Be concise, friendly, and informative.',
    );
    _provider = (widget.agent?.agentConfig?['provider'] as String?) ?? 'anthropic';
    _model = (widget.agent?.agentConfig?['model'] as String?) ?? 'claude-sonnet-4-6';
  }

  final _claudeModels = const [
    ('claude-sonnet-4-6', 'Claude Sonnet 4.6', 'Best balance of speed and intelligence'),
    ('claude-opus-4-6', 'Claude Opus 4.6', 'Most capable, complex reasoning'),
    ('claude-haiku-4-5-20251001', 'Claude Haiku 4.5', 'Fastest responses'),
  ];

  final _openaiModels = const [
    ('gpt-4o', 'GPT-4o', 'Most capable OpenAI model'),
    ('gpt-4o-mini', 'GPT-4o Mini', 'Fast and cost-efficient'),
    ('gpt-4-turbo', 'GPT-4 Turbo', 'High intelligence, large context'),
    ('o3-mini', 'o3-mini', 'Advanced reasoning model'),
  ];

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final prompt = _promptCtrl.text.trim();
    if (name.isEmpty || prompt.isEmpty) return;

    setState(() => _loading = true);
    final api = context.read<ApiService>();

    if (widget.agent == null) {
      await api.post('/agents', data: {
        'name': name,
        'bio': _bioCtrl.text.trim(),
        'systemPrompt': prompt,
        'model': _model,
        'provider': _provider,
      });
    } else {
      await api.patch('/agents/${widget.agent!.id}', data: {
        'name': name,
        'bio': _bioCtrl.text.trim(),
        'systemPrompt': prompt,
        'model': _model,
        'provider': _provider,
      });
    }

    setState(() => _loading = false);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final models = _provider == 'anthropic' ? _claudeModels : _openaiModels;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.agent == null ? 'Create AI Agent' : 'Edit Agent',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // Provider selection
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'anthropic',
                    label: Text('Claude'),
                    icon: Icon(Icons.psychology_outlined),
                  ),
                  ButtonSegment(
                    value: 'openai',
                    label: Text('OpenAI'),
                    icon: Icon(Icons.smart_toy_outlined),
                  ),
                ],
                selected: {_provider},
                onSelectionChanged: (v) => setState(() {
                  _provider = v.first;
                  _model = _provider == 'anthropic' ? 'claude-sonnet-4-6' : 'gpt-4o-mini';
                }),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Agent Name', prefixIcon: Icon(Icons.smart_toy_outlined)), autofocus: widget.agent == null),
            const SizedBox(height: 12),
            TextField(controller: _bioCtrl, decoration: const InputDecoration(labelText: 'Description / Role')),
            const SizedBox(height: 16),
            const Text('Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...models.map((m) => RadioListTile<String>(
              value: m.$1,
              groupValue: _model,
              onChanged: (v) => setState(() => _model = v!),
              title: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(m.$3, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primary,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: _promptCtrl,
              decoration: const InputDecoration(
                labelText: 'System Prompt',
                alignLabelWithHint: true,
                hintText: 'Define the agent\'s personality and behavior...',
              ),
              maxLines: 5,
              maxLength: 2000,
            ),
            const SizedBox(height: 16),
            _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ElevatedButton(
                    onPressed: _save,
                    child: Text(widget.agent == null ? 'Create Agent' : 'Save Changes'),
                  ),
          ],
        ),
      ),
    );
  }
}
