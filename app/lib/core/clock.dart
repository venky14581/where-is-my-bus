import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The phone's current time. Overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
