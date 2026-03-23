import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/preferences_cache.dart';
import '../data/repositories/profile_repository.dart';

/// Holds the currently selected child profile (for kid mode).
class CurrentChildNotifier extends StateNotifier<ChildProfile?> {
  CurrentChildNotifier() : super(null);

  void setChild(ChildProfile child) {
    state = child;
    PreferencesCache.setLastChildId(child.id);
  }

  void clear() {
    state = null;
  }
}

final currentChildProvider =
    StateNotifierProvider<CurrentChildNotifier, ChildProfile?>((ref) {
  return CurrentChildNotifier();
});
