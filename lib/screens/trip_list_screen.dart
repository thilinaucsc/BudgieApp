import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/splitter_trip.dart';
import '../models/splitter_participant.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final db = DatabaseHelper.instance;
  final money = NumberFormat('#,##0.00');

  List<SplitterTrip> _trips = [];
  Map<int, List<SplitterParticipant>> _participants = {};
  Map<int, double> _totals = {};
  bool _loading = true;
  String _currency = 'Rs.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await db.getAllSplitterTrips();
    final currency = await db.getSetting('currency', 'Rs.');
    final Map<int, List<SplitterParticipant>> participants = {};
    final Map<int, double> totals = {};
    for (final trip in trips) {
      final id = trip.id!;
      participants[id] = await db.participantsForTrip(id);
      totals[id] = await db.splitterTripTotal(id);
    }
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _participants = participants;
      _totals = totals;
      _currency = currency;
      _loading = false;
    });
  }

  Future<void> _createTrip() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final participantsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Trip'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Trip name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: participantsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Participants',
                  hintText: 'Alice, Bob, Charlie',
                ),
                validator: (v) {
                  if (v == null) return 'At least 2 participants required';
                  final names = v
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  if (names.length < 2) {
                    return 'At least 2 participants required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = await db.insertSplitterTrip(
      SplitterTrip(
        name: nameCtrl.text.trim(),
        createdAt: DateTime.now(),
      ),
    );

    final names = participantsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final name in names) {
      await db.insertSplitterParticipant(
        SplitterParticipant(tripId: tripId, name: name),
      );
    }

    _load();
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this trip?'),
          content: const Text(
              'All expenses and participant data will be permanently removed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trips',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTrip,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _emptyState()
              : _tripList(),
    );
  }

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          const Text(
            'No trips yet',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start a trip',
            style: TextStyle(color: cs.outline, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _tripList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _trips.length,
      itemBuilder: (_, i) => _tripTile(_trips[i]),
    );
  }

  Widget _tripTile(SplitterTrip trip) {
    final cs = Theme.of(context).colorScheme;
    final id = trip.id!;
    final participants = _participants[id] ?? [];
    final total = _totals[id] ?? 0.0;
    final participantLabel = participants.isEmpty
        ? ''
        : participants.map((p) => p.name).join(' · ');

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Container(
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) async {
        await db.deleteSplitterTrip(id);
        _load();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: InkWell(
          onTap: () {
            // TODO: navigate to TripDetailScreen(trip: trip, participants: participants)
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (participantLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    participantLabel,
                    style: TextStyle(color: cs.outline, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: $_currency ${money.format(total)}',
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
