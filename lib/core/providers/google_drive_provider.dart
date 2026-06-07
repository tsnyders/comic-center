import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/google_drive_service.dart';

class GoogleDriveNotifier extends StateNotifier<GoogleSignInAccount?> {
  GoogleDriveNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    state = await GoogleDriveService.signInSilently();
  }

  Future<bool> signIn() async {
    final account = await GoogleDriveService.signIn();
    state = account;
    return account != null;
  }

  Future<void> signOut() async {
    await GoogleDriveService.signOut();
    state = null;
  }
}

final googleDriveProvider =
    StateNotifierProvider<GoogleDriveNotifier, GoogleSignInAccount?>(
  (_) => GoogleDriveNotifier(),
);
