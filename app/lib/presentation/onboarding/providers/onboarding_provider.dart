import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/local/preferences_cache.dart';
import '../../../data/datasources/remote/supabase_client.dart';
import '../../../data/repositories/channel_repository.dart';
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

  // Channel name mapping (for ensureChannelExists FK dependency)
  final Map<String, String> approvedChannelNames; // channelId -> name

  // Content preferences (Step 12)
  final Map<String, String> contentPreferences;

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
    this.approvedChannelNames = const {},
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
    Map<String, String>? approvedChannelNames,
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
      approvedChannelNames: approvedChannelNames ?? this.approvedChannelNames,
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

  void toggleChannel(String channelId, {String? name}) {
    final updatedIds = Set<String>.from(state.approvedChannelIds);
    final updatedNames = Map<String, String>.from(state.approvedChannelNames);
    if (updatedIds.contains(channelId)) {
      updatedIds.remove(channelId);
      updatedNames.remove(channelId);
    } else {
      updatedIds.add(channelId);
      if (name != null) updatedNames[channelId] = name;
    }
    state = state.copyWith(
      approvedChannelIds: updatedIds,
      approvedChannelNames: updatedNames,
    );
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
      // Idempotency: reuse existing child with same name if a previous
      // attempt partially succeeded (avoids duplicate children on retry).
      final existingChildren = await _profileRepo.getChildren();
      ChildProfile? child;
      for (final c in existingChildren) {
        if (c.name == state.childName) {
          child = c;
          break;
        }
      }

      child ??= await _profileRepo.createChild(
        name: state.childName,
        dateOfBirth: state.childDob!,
        filterSensitivity: {
          for (final entry in state.filterSensitivity.entries)
            entry.key: entry.value,
          'music_allowed': true,
          'max_video_duration_minutes': 30,
        },
      );

      // Persist child ID locally (required by setup guard)
      await PreferencesCache.setLastChildId(child.id);

      // Persist approved channels from onboarding
      if (state.approvedChannelIds.isNotEmpty) {
        final userId = SupabaseClientWrapper.currentUserId;
        if (userId != null) {
          final channelRepo = ChannelRepository();
          // Ensure channels exist in yt_channels (FK dependency)
          for (final channelId in state.approvedChannelIds) {
            final name =
                state.approvedChannelNames[channelId] ?? 'Unknown Channel';
            await channelRepo.ensureChannelExists(channelId, name);
          }
          for (final channelId in state.approvedChannelIds) {
            await channelRepo.setChannelPref(
              parentId: userId,
              channelId: channelId,
              status: 'approved',
            );
          }
        }
      }

      // Persist content preferences
      if (state.contentPreferences.isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        for (final entry in state.contentPreferences.entries) {
          rows.add({
            'child_id': child.id,
            'content_type': entry.key,
            'preference': entry.value,
          });
        }
        await SupabaseClientWrapper.client
            .from('content_preferences')
            .upsert(rows, onConflict: 'child_id,content_type');
      }

      // Mark parent setup as completed
      await _profileRepo.completeSetup();

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, st) {
      debugPrint('completeOnboarding failed: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier(ProfileRepository());
    });
