import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/repositories/profile_repository.dart';

enum ProfileStatus { idle, saving, success, failure }

final class ProfileState extends Equatable {
  const ProfileState({this.status = ProfileStatus.idle, this.message});

  final ProfileStatus status;

  /// User-safe error text when [status] is [ProfileStatus.failure].
  final String? message;

  bool get isSaving => status == ProfileStatus.saving;

  @override
  List<Object?> get props => [status, message];
}

/// Saves profile edits. The refreshed profile itself arrives through
/// `AuthBloc`'s live user stream, so this cubit only tracks the save.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this._repository}) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> updateProfile({
    required String displayName,
    String? department,
  }) async {
    if (state.isSaving) return;
    emit(const ProfileState(status: ProfileStatus.saving));
    try {
      await _repository.updateProfile(
        displayName: displayName,
        department: department,
      );
      emit(const ProfileState(status: ProfileStatus.success));
    } catch (e, st) {
      emit(
        ProfileState(
          status: ProfileStatus.failure,
          message: mapException(e, st).message,
        ),
      );
    }
  }

  /// Saves a preset avatar (null = default). The new avatar reaches the UI
  /// through the session user in AuthBloc.
  Future<void> setAvatar(String? avatarId) async {
    if (state.isSaving) return;
    emit(const ProfileState(status: ProfileStatus.saving));
    try {
      await _repository.setAvatar(avatarId);
      emit(const ProfileState(status: ProfileStatus.success));
    } catch (e, st) {
      emit(
        ProfileState(
          status: ProfileStatus.failure,
          message: mapException(e, st).message,
        ),
      );
    }
  }

  /// Returns to idle after the UI has shown the outcome.
  void acknowledge() {
    if (state.status != ProfileStatus.idle && !state.isSaving) {
      emit(const ProfileState());
    }
  }
}
