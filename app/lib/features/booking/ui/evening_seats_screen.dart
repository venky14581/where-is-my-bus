import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/clock.dart';
import '../../../core/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/session.dart';
import '../../eta/ui/arrival_panel.dart';
import '../../live/ui/live_status.dart';
import '../../pass/ui/pass_screen.dart';
import '../../routes/application/route_providers.dart';
import '../../routes/domain/bus_route.dart';
import '../../trip/domain/trip_plan.dart';
import '../application/booking_providers.dart';
import '../domain/booking.dart';

/// Spare seats on evening buses for students without a pass for that route:
/// hostellers, students with their own transport, or a day scholar going
/// somewhere else. Tickets they have bought show here too.
class EveningSeatsScreen extends ConsumerWidget {
  const EveningSeatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final user = session is SignedIn ? session.profile : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.eveningSeatsTitle)),
      body: user == null ? const SizedBox.shrink() : ServerClock(builder: (context, now) => _Body(user: user, now: now)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user, required this.now});

  final AppUser user;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final local = ref.watch(clockProvider)();
    final today = tripDate(local);
    final tomorrow = tripDate(local.add(const Duration(days: 1)));
    final trips = ref.watch(eveningTripsProvider('$today,$tomorrow'));
    final bookings = ref.watch(myBookingsProvider(user.uid)).value ?? const <Booking>[];
    final routes = {for (final r in ref.watch(routesProvider).value ?? const <BusRoute>[]) r.id: r};
    final buses = {for (final b in ref.watch(busesProvider).value ?? const <Bus>[]) b.id: b};

    if (trips.isLoading) return const Center(child: CircularProgressIndicator());

    // Tickets still to use, and ones used today so the student sees it worked.
    final tickets = [
      for (final b in bookings)
        if ((b.status == BookingStatus.pendingPayment || b.status == BookingStatus.confirmed) &&
                b.departsAt.isAfter(now.subtract(const Duration(hours: 3))) ||
            (b.status == BookingStatus.used && b.date == today))
          b,
    ];
    final bookable = [
      for (final t in trips.value ?? const <EveningTrip>[])
        if (t.guestFare != null && t.status != 'ended' && t.departsAt.isAfter(now) && routes.containsKey(t.routeId)) t,
    ]..sort((a, b) => a.departsAt == b.departsAt
        ? routes[a.routeId]!.name.compareTo(routes[b.routeId]!.name)
        : a.departsAt.compareTo(b.departsAt));
    final passRoute = passStatusOf(user, local) == PassStatus.valid ? user.routeId : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (tickets.isNotEmpty) ...[
          Text(l10n.ticketsTitle, style: text.titleLarge),
          const SizedBox(height: 8),
          for (final booking in tickets)
            _TicketCard(booking: booking, route: routes[booking.routeId], bus: buses[booking.busId], now: now),
          const SizedBox(height: 16),
        ],
        Text(l10n.eveningIntro, style: text.bodyLarge),
        const SizedBox(height: 16),
        if (bookable.isEmpty) Text(l10n.eveningNone, style: text.titleMedium),
        for (final (index, trip) in bookable.indexed) ...[
          if (index == 0 || bookable[index - 1].date != trip.date)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(trip.date == today ? l10n.eveningToday : l10n.eveningTomorrow, style: text.titleMedium),
            ),
          _TripCard(
            trip: trip,
            route: routes[trip.routeId]!,
            bus: buses[trip.busId],
            now: now,
            passCovers: trip.routeId == passRoute,
            booked: bookings.any((b) =>
                b.tripId == trip.id &&
                (b.status == BookingStatus.pendingPayment ||
                    b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.used)),
            email: user.email,
          ),
        ],
      ],
    );
  }
}

/// Runs a payment and reports what went wrong, if anything. Shared by a new
/// booking and an unpaid one the student comes back to.
Future<String?> payForBooking(
  BuildContext context,
  WidgetRef ref, {
  required String bookingId,
  required PaymentInfo info,
  required num fare,
  required String description,
  String? email,
}) async {
  final l10n = context.l10n;
  final repository = ref.read(bookingRepositoryProvider);
  final proof = await ref
      .read(paymentGatewayProvider)
      .pay(context, info: info, fare: fare, description: description, email: email);
  if (proof == null) {
    // Backed out: give the seat straight back rather than wait for expiry.
    try {
      await repository.cancel(bookingId);
    } catch (_) {}
    return l10n.paymentCancelled;
  }
  return switch (await repository.pay(bookingId: bookingId, proof: proof)) {
    PayResult.confirmed => null,
    PayResult.expired => l10n.paymentExpired,
    PayResult.invalidPayment || PayResult.notPending => l10n.paymentInvalid,
    PayResult.offline => l10n.bookOffline,
  };
}

class _TripCard extends ConsumerStatefulWidget {
  const _TripCard({
    required this.trip,
    required this.route,
    required this.bus,
    required this.now,
    required this.passCovers,
    required this.booked,
    required this.email,
  });

  final EveningTrip trip;
  final BusRoute route;
  final Bus? bus;
  final DateTime now;
  final bool passCovers;
  final bool booked;
  final String? email;

  @override
  ConsumerState<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends ConsumerState<_TripCard> {
  bool _busy = false;
  String? _message;

  Future<void> _book() async {
    final l10n = context.l10n;
    final trip = widget.trip;
    final stopId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DropStopSheet(route: widget.route, fare: trip.guestFare!),
    );
    if (stopId == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await ref.read(bookingRepositoryProvider).book(tripId: trip.id, stopId: stopId);
    String? message = switch (outcome.result) {
      BookResult.booked => null,
      BookResult.alreadyBooked => l10n.bookAlready,
      BookResult.full => l10n.bookFull,
      BookResult.notOpen => l10n.bookNotOpen,
      BookResult.closed => l10n.bookClosed,
      BookResult.passCovers => l10n.passCoversBus,
      BookResult.noGuestSeats => l10n.bookNoGuestSeats,
      BookResult.badStop => l10n.bookBadStop,
      BookResult.paymentsUnavailable => l10n.bookPaymentsUnavailable,
      BookResult.offline => l10n.bookOffline,
    };
    if (outcome.result == BookResult.booked && outcome.bookingId != null && mounted) {
      message = await payForBooking(
        context,
        ref,
        bookingId: outcome.bookingId!,
        info: outcome.payment ?? const PaymentInfo(mode: PaymentMode.demo),
        fare: trip.guestFare!,
        description: widget.route.name,
        email: widget.email,
      );
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final trip = widget.trip;
    final window = trip.windowAt(widget.now);
    final seats = trip.spareSeats;

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.route.name, style: text.titleLarge),
            if (widget.bus case final bus?) Text(l10n.busNumber(bus.number)),
            const SizedBox(height: 4),
            Text(l10n.eveningLeaves(formatClock(context, trip.departsAt)), style: text.titleMedium),
            Text('${l10n.fareRupees(trip.guestFare.toString())} · ${l10n.seatsLeft(seats)}'),
            const SizedBox(height: 8),
            if (widget.passCovers)
              Text(l10n.passCoversBus, style: TextStyle(color: Colors.green.shade800))
            else if (widget.booked)
              Text(l10n.bookedLabel, style: text.titleMedium?.copyWith(color: Colors.green.shade800))
            else
              switch (window) {
                BookingWindow.notYet => Text(l10n.bookingOpensAt(formatClock(context, trip.bookingOpensAt))),
                BookingWindow.closed => Text(l10n.bookClosed),
                BookingWindow.open => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.bookingUntil(formatClock(context, trip.bookingClosesAt))),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _busy || seats == 0 ? null : _book,
                        icon: const Icon(Icons.event_seat),
                        label: Text(l10n.bookSeatButton),
                      ),
                    ],
                  ),
              },
            if (_message case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Where the student gets off. Evening buses run from campus out along the
/// route, so stops are listed in that order, without the campus.
class _DropStopSheet extends StatefulWidget {
  const _DropStopSheet({required this.route, required this.fare});

  final BusRoute route;
  final num fare;

  @override
  State<_DropStopSheet> createState() => _DropStopSheetState();
}

class _DropStopSheetState extends State<_DropStopSheet> {
  String? _stopId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stops = stopsInTravelOrder(widget.route, TripDirection.fromCampus).skip(1).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(l10n.chooseDropTitle, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: RadioGroup<String>(
                groupValue: _stopId,
                onChanged: (id) => setState(() => _stopId = id),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final stop in stops) RadioListTile<String>(value: stop.id, title: Text(stop.name)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _stopId == null ? null : () => Navigator.pop(context, _stopId),
                child: Text(l10n.bookForButton(widget.fare.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  const _TicketCard({required this.booking, required this.route, required this.bus, required this.now});

  final Booking booking;
  final BusRoute? route;
  final Bus? bus;
  final DateTime now;

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  bool _busy = false;
  String? _message;

  Future<void> _pay() async {
    final booking = widget.booking;
    setState(() => _busy = true);
    final message = await payForBooking(
      context,
      ref,
      bookingId: booking.id,
      info: booking.payment,
      fare: booking.fare,
      description: widget.route?.name ?? '',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(bookingRepositoryProvider).cancel(widget.booking.id);
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.bookOffline);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final booking = widget.booking;
    final stop = widget.route?.stopById(booking.stopId)?.name ?? booking.stopId;
    final code = booking.ticketCode;

    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.route?.name ?? '', style: text.titleLarge),
            if (widget.bus case final bus?) Text(l10n.busNumber(bus.number)),
            Text(l10n.eveningLeaves(formatClock(context, booking.departsAt)), style: text.titleMedium),
            Text(l10n.ticketGetOff(stop)),
            const SizedBox(height: 12),
            switch (booking.status) {
              BookingStatus.confirmed when code != null => Center(
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: code,
                          size: 220,
                          backgroundColor: Colors.white,
                          semanticsLabel: l10n.ticketQrLabel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.ticketShow, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              BookingStatus.used => Text(l10n.ticketUsed, style: text.titleMedium),
              BookingStatus.pendingPayment => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.expiresAt case final until?) Text(l10n.pendingUntil(formatClock(context, until))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : _pay,
                          child: Text(l10n.payButton(booking.fare.toString())),
                        ),
                        TextButton(onPressed: _busy ? null : _cancel, child: Text(l10n.cancelBookingButton)),
                      ],
                    ),
                  ],
                ),
              _ => const SizedBox.shrink(),
            },
            if (_message case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
