import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/splitter_trip.dart';
import '../models/splitter_participant.dart';
import 'trip_detail_screen.dart';

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
    final addCtrl = TextEditingController();
    final participantNames = <String>[];
    String? namesError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          void tryAdd() {
            final n = addCtrl.text.trim();
            if (n.isEmpty) return;
            if (!participantNames.contains(n)) {
              setDialogState(() {
                participantNames.add(n);
                namesError = null;
              });
            }
            addCtrl.clear();
          }

          return AlertDialog(
            title: const Text('New Trip'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Trip name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Add participant',
                              hintText: 'e.g. Alice',
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => tryAdd(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add_outlined),
                          onPressed: tryAdd,
                          tooltip: 'Add',
                        ),
                      ],
                    ),
                    if (participantNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: participantNames
                            .map(
                              (n) => Chip(
                                label: Text(n),
                                deleteIcon:
                                    const Icon(Icons.close, size: 16),
                                onDeleted: () => setDialogState(
                                    () => participantNames.remove(n)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (namesError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        namesError!,
                        style: TextStyle(
                          color: Theme.of(ctx2).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  if (participantNames.length < 2) {
                    setDialogState(
                        () => namesError = 'Add at least 2 participants');
                    return;
                  }
                  Navigator.pop(ctx2, true);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final tripId = await db.insertSplitterTrip(
      SplitterTrip(name: nameCtrl.text.trim(), createdAt: DateTime.now()),
    );
    for (final name in participantNames) {
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
          child:
              Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TripDetailScreen(
                trip: trip,
                participants: participants,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
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
                      if (participants.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          participants.map((p) => p.name).join(' · '),
                          style: TextStyle(color: cs.outline, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM yyyy').format(trip.createdAt),
                        style: TextStyle(
                          color: cs.outlineVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currency ${money.format(total)}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${participants.length} '
                      '${participants.length == 1 ? 'person' : 'people'}',
                      style: TextStyle(color: cs.outline, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
