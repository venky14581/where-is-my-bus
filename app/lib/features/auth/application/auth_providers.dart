import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);

final sessionProvider = StreamProvider<Session>(
  (ref) => ref.watch(authRepositoryProvider).sessions(),
);
