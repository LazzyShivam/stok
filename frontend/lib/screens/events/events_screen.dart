import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<EventModel> _events = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final data = await context.read<ApiService>().get('/events') as List<dynamic>;
    setState(() {
      _events = data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  void _createEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateEventSheet(onCreated: _loadEvents),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _createEvent),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _events.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (_, i) => _buildEventCard(_events[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        child: const Icon(Icons.event_rounded),
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    final fmt = DateFormat('MMM d · h:mm a');
    final isOngoing = event.isOngoing;
    final isUpcoming = event.isUpcoming;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/event-detail', arguments: {'eventId': event.id}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isOngoing ? AppTheme.success.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(event.startTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isOngoing ? AppTheme.success : AppTheme.primary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(event.startTime).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOngoing ? AppTheme.success : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (isOngoing)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('LIVE', style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(fmt.format(event.startTime),
                        style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
                    if (event.location != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.onSurfaceMuted),
                          const SizedBox(width: 3),
                          Text(event.location!, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: AppTheme.onSurfaceMuted),
                        const SizedBox(width: 4),
                        Text('${event.attendeeCount} attending',
                            style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 72, color: AppTheme.onSurfaceMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No events yet', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
        ],
      ),
    );
  }
}

class _CreateEventSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateEventSheet({required this.onCreated});

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  bool _loading = false;

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() { if (isStart) _startTime = dt; else _endTime = dt; });
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);

    await context.read<ApiService>().post('/events', data: {
      'title': title,
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'startTime': _startTime.toIso8601String(),
      'endTime': _endTime.toIso8601String(),
    });

    setState(() => _loading = false);
    if (!mounted) return;
    widget.onCreated();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, y · h:mm a');
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
            const Text('Create Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Event Title'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined))),
            const SizedBox(height: 16),
            _datePickerTile('Start Time', _startTime, fmt, () => _pickDate(true)),
            const SizedBox(height: 10),
            _datePickerTile('End Time', _endTime, fmt, () => _pickDate(false)),
            const SizedBox(height: 20),
            _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ElevatedButton(onPressed: _create, child: const Text('Create Event')),
          ],
        ),
      ),
    );
  }

  Widget _datePickerTile(String label, DateTime dt, DateFormat fmt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: AppTheme.onSurfaceMuted),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted)),
                Text(fmt.format(dt), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
