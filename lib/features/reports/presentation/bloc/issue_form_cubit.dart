import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/photo_picker.dart';
import '../../domain/entities/issue.dart';
import '../../domain/entities/issue_enums.dart';
import '../../domain/repositories/issue_repository.dart';

enum IssueFormStatus { editing, submitting, success, failure }

/// Why the last submit failed when it was a connectivity or upload problem,
/// so the form can show the offline banner and offer a retry on photos.
enum IssueSubmitProblem {
  /// A [NetworkFailure]: the device appears to be offline.
  offline,

  /// An [UploadFailure]: the photos could not be uploaded.
  upload,
}

final class IssueFormState extends Equatable {
  const IssueFormState({
    this.category,
    this.buildingId,
    this.photos = const [],
    this.status = IssueFormStatus.editing,
    this.message,
    this.created,
    this.submitProblem,
  });

  final IssueCategory? category;
  final String? buildingId;

  /// Local file paths of picked photos.
  final List<String> photos;
  final IssueFormStatus status;
  final String? message;
  final Issue? created;

  /// Set after a submit failed for connectivity/upload reasons; cleared
  /// when the next submit starts.
  final IssueSubmitProblem? submitProblem;

  bool get canAddPhoto => photos.length < AppConstants.maxPhotosPerIssue;
  bool get isSubmitting => status == IssueFormStatus.submitting;

  IssueFormState copyWith({
    IssueCategory? category,
    String? buildingId,
    List<String>? photos,
    IssueFormStatus? status,
    String? Function()? message,
    Issue? created,
    IssueSubmitProblem? Function()? submitProblem,
  }) => IssueFormState(
    category: category ?? this.category,
    buildingId: buildingId ?? this.buildingId,
    photos: photos ?? this.photos,
    status: status ?? this.status,
    message: message != null ? message() : this.message,
    created: created ?? this.created,
    submitProblem: submitProblem != null ? submitProblem() : this.submitProblem,
  );

  @override
  List<Object?> get props => [
    category,
    buildingId,
    photos,
    status,
    message,
    created,
    submitProblem,
  ];
}

/// Text fields live in the form's controllers; this cubit owns the
/// selections, photos and submission lifecycle.
class IssueFormCubit extends Cubit<IssueFormState> {
  IssueFormCubit({required this._repository, required this._photoPicker})
    : super(const IssueFormState());

  final IssueRepository _repository;
  final PhotoPicker _photoPicker;

  void categoryChanged(IssueCategory category) =>
      emit(state.copyWith(category: category));

  void buildingChanged(String buildingId) =>
      emit(state.copyWith(buildingId: buildingId));

  Future<void> addPhoto(PhotoSource source) async {
    if (!state.canAddPhoto || state.isSubmitting) return;
    try {
      final path = await _photoPicker.pick(source);
      // Re-check: the page may have closed, or a concurrent pick may have
      // filled the last slot (or submit started) while the picker was open.
      if (path == null ||
          isClosed ||
          !state.canAddPhoto ||
          state.isSubmitting) {
        return;
      }
      emit(
        state.copyWith(photos: [...state.photos, path], message: () => null),
      );
    } catch (e, st) {
      if (isClosed) return;
      emit(state.copyWith(message: () => mapException(e, st).message));
    }
  }

  void removePhoto(String path) => emit(
    state.copyWith(photos: state.photos.where((p) => p != path).toList()),
  );

  void messageShown() => emit(state.copyWith(message: () => null));

  Future<void> submit({
    required String title,
    required String description,
    required String locationDetail,
  }) async {
    if (state.isSubmitting) return;
    final category = state.category;
    final buildingId = state.buildingId;
    if (category == null || buildingId == null) {
      emit(
        state.copyWith(
          status: IssueFormStatus.failure,
          message: () => 'Choose a category and a building.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: IssueFormStatus.submitting,
        message: () => null,
        submitProblem: () => null,
      ),
    );
    try {
      final issue = await _repository.createIssue(
        NewIssueInput(
          title: title,
          description: description,
          category: category,
          buildingId: buildingId,
          locationDetail: locationDetail,
          localPhotoPaths: state.photos,
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(status: IssueFormStatus.success, created: issue));
    } catch (e, st) {
      if (isClosed) return;
      // Field values stay in the form so the user can retry.
      final failure = mapException(e, st);
      emit(
        state.copyWith(
          status: IssueFormStatus.failure,
          message: () => failure.message,
          submitProblem: () => switch (failure) {
            NetworkFailure() => IssueSubmitProblem.offline,
            UploadFailure() => IssueSubmitProblem.upload,
            _ => null,
          },
        ),
      );
    }
  }
}
