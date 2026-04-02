import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventModel? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    final data = await context.read<ApiService>().get('/events/${widget.eventId}');
    setState(() {
      _event = EventModel.fromJson(data as Map<String, dynamic>);
      _loading = false;
    });
  }

  Future<void> _rsvp(String status) async {
    await context.read<ApiService>().patch('/events/${widget.eventId}/rsvp', data: {'status': status});
    await _loadEvent();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    if (_event == null) return const Scaffold(body: Center(child: Text('Event not found')));

    final event = _event!;
    final fmt = DateFormat('EEEE, MMMM d, y');
    final timeFmt = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  Text(event.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (event.description != null) ...[
                    const SizedBox(height: 8),
                    Text(event.description!, style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoRow(Icons.calendar_today_outlined, fmt.format(event.startTime)),
            const SizedBox(height: 12),
            _infoRow(Icons.access_time, '${timeFmt.format(event.startTime)} – ${timeFmt.format(event.endTime)}'),
            if (event.location != null) ...[
              const SizedBox(height: 12),
              _infoRow(Icons.location_on_outlined, event.location!),
            ],
            const SizedBox(height: 24),
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 16),
            Text('Attendees (${event.attendeeCount})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            ...event.attendees.map((a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceVariant,
                child: Text(a.user?.name.isNotEmpty == true ? a.user!.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(a.user?.name ?? a.userId, style: const TextStyle(fontSize: 14)),
              trailing: _statusChip(a.status),
            )),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rsvp('DECLINED'),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.error),
                    label: const Text('Decline', style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rsvp('ACCEPTED'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _statusChip(AttendeeStatus status) {
    Color color;
    String label;
    switch (status) {
      case AttendeeStatus.accepted: color = AppTheme.success; label = 'Going'; break;
      case AttendeeStatus.declined: color = AppTheme.error; label = 'Not Going'; break;
      default: color = AppTheme.warning; label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
