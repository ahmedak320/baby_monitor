import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/profile_repository.dart';

/// Tracks onboarding state across the multi-step flow.
class OnboardingState {
  // Child info (Step 9)
  final String childName;
  final DateTime? childDob;

  // Filter priorities (Step 10)
  final List<String> filterPriorities;
  final Map<String, double> filterSensitivity;

  // Approved channels (Step 11)
  final Set<String> approvedChannelIds;

  // Content preferences (Step 12)
  final Map<String, String> contentPreferences; // type -> preferred/allowed/blocked

  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.childName = '',
    this.childDob,
    this.filterPriorities = const [
      'overstimulation',
      'brainrot',
      'scariness',
      'language',
      'ads',
    ],
    this.filterSensitivity = const {
      'overstimulation': 5,
      'scariness': 3,
      'brainrot': 3,
      'language_strictness': 8,
      'educational_preference': 5,
    },
    this.approvedChannelIds = const {},
    this.contentPreferences = const {},
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    String? childName,
    DateTime? childDob,
    List<String>? filterPriorities,
    Map<String, double>? filterSensitivity,
    Set<String>? approvedChannelIds,
    Map<String, String>? contentPreferences,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      childName: childName ?? this.childName,
      childDob: childDob ?? this.childDob,
      filterPriorities: filterPriorities ?? this.filterPriorities,
      filterSensitivity: filterSensitivity ?? this.filterSensitivity,
      approvedChannelIds: approvedChannelIds ?? this.approvedChannelIds,
      contentPreferences: contentPreferences ?? this.contentPreferences,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final ProfileRepository _profileRepo;

  OnboardingNotifier(this._profileRepo) : super(const OnboardingState());

  void setChildName(String name) {
    state = state.copyWith(childName: name);
  }

  void setChildDob(DateTime dob) {
    state = state.copyWith(childDob: dob);
  }

  void setFilterPriorities(List<String> priorities) {
    state = state.copyWith(filterPriorities: priorities);
  }

  void setFilterSensitivity(String key, double value) {
    final updated = Map<String, double>.from(state.filterSensitivity);
    updated[key] = value;
    state = state.copyWith(filterSensitivity: updated);
  }

  void toggleChannel(String channelId) {
    final updated = Set<String>.from(state.approvedChannelIds);
    if (updated.contains(channelId)) {
      updated.remove(channelId);
    } else {
      updated.add(channelId);
    }
    state = state.copyWith(approvedChannelIds: updated);
  }

  void setContentPreference(String type, String preference) {
    final updated = Map<String, String>.from(state.contentPreferences);
    updated[type] = preference;
    state = state.copyWith(contentPreferences: updated);
  }

  /// Save all onboarding data to Supabase.
  Future<bool> completeOnboarding() async {
    if (state.childName.isEmpty || state.childDob == null) return false;

    state = state.copyWith(isLoading: true);
    try {
      // Create child profile
      await _profileRepo.createChild(
        name: state.childName,
        dateOfBirth: state.childDob!,
        filterSensitivity: {
          for (final entry in state.filterSensitivity.entries)
            entry.key: entry.value,
          'music_allowed': true,
          'max_video_duration_minutes': 30,
        },
      );

      // Mark parent setup as completed
      await _profileRepo.completeSetup();

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ProfileRepository());
});
