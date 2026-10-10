/// Seats nobody else has a claim on. The route's pass holders come first,
/// except those who said they are not riding, then riders from other routes
/// who missed their bus and guests who booked. Same sum as spareSeats in
/// functions/src/booking.ts.
int spareSeats({
  required int capacity,
  required int passHolders,
  int notRiding = 0,
  int altHeld = 0,
  int seatsBooked = 0,
}) {
  final keep = passHolders - notRiding < 0 ? 0 : passHolders - notRiding;
  final free = capacity - keep - altHeld - seatsBooked;
  return free < 0 ? 0 : free;
}

enum CrowdLevel { seatsAvailable, fewSeats, standingOnly }

/// How full the bus will be, counting every pass holder who has not said
/// they are not riding.
CrowdLevel crowdLevel({
  required int capacity,
  required int passHolders,
  int notRiding = 0,
  int altHeld = 0,
  int seatsBooked = 0,
}) {
  final keep = passHolders - notRiding < 0 ? 0 : passHolders - notRiding;
  final free = capacity - keep - altHeld - seatsBooked;
  if (free <= 0) return CrowdLevel.standingOnly;
  final few = capacity ~/ 10 < 3 ? 3 : capacity ~/ 10;
  return free <= few ? CrowdLevel.fewSeats : CrowdLevel.seatsAvailable;
}
