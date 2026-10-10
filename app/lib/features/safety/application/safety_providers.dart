import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_bootstrap.dart';
import '../data/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => FirebaseSafetyRepository(FirebaseFunctions.instanceFor(region: functionsRegion)),
);
