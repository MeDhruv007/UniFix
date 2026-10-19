import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/utils/photo_picker.dart';
import 'features/admin/presentation/bloc/admin_dashboard_cubit.dart';
import 'features/admin/presentation/bloc/admin_issue_cubit.dart';
import 'features/auth/data/datasources/auth_api_data_source.dart';
import 'features/auth/data/repositories/auth_api_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/feedback/data/feedback_repository_impl.dart';
import 'features/feedback/domain/repositories/feedback_repository.dart';
import 'features/feedback/presentation/bloc/feedback_cubit.dart';
import 'features/profile/data/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/presentation/bloc/profile_cubit.dart';
import 'features/reports/data/datasources/issue_api_data_source.dart';
import 'features/reports/data/repositories/issue_repository_impl.dart';
import 'features/reports/domain/repositories/issue_repository.dart';
import 'features/reports/presentation/bloc/issue_details_cubit.dart';
import 'features/reports/presentation/bloc/issue_form_cubit.dart';
import 'features/reports/presentation/bloc/issue_list_bloc.dart';
import 'features/student_dashboard/presentation/bloc/student_stats_cubit.dart';

final GetIt getIt = GetIt.instance;

/// Composition root.
void configureDependencies() {
  // 1. Networking and platform services.
  getIt
    ..registerLazySingleton<TokenStore>(TokenStore.new)
    ..registerLazySingleton<ApiClient>(
      () => ApiClient(tokens: getIt<TokenStore>()),
    )
    ..registerLazySingleton<Dio>(() => getIt<ApiClient>().dio)
    ..registerLazySingleton<PhotoPicker>(PhotoPicker.new);

  // 2. Data sources.
  getIt
    ..registerLazySingleton<AuthApiDataSource>(
      () => AuthApiDataSource(dio: getIt<Dio>()),
    )
    ..registerLazySingleton<IssueApiDataSource>(
      () => IssueApiDataSource(dio: getIt<Dio>()),
    );

  // 3. Repositories.
  getIt
    ..registerLazySingleton<AuthApiRepository>(
      () => AuthApiRepository(
        api: getIt<AuthApiDataSource>(),
        tokens: getIt<TokenStore>(),
        client: getIt<ApiClient>(),
      ),
    )
    ..registerLazySingleton<AuthRepository>(() => getIt<AuthApiRepository>())
    ..registerLazySingleton<IssueRepository>(
      () => IssueRepositoryImpl(
        api: getIt<IssueApiDataSource>(),
        client: getIt<ApiClient>(),
      ),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(
        api: getIt<AuthApiDataSource>(),
        session: getIt<AuthApiRepository>(),
      ),
    )
    ..registerLazySingleton<FeedbackRepository>(
      () => FeedbackRepositoryImpl(dio: getIt<Dio>()),
    );

  // 4. BLoCs. AuthBloc is app-scoped (the router depends on it); screen
  // BLoCs are factories so each route owns its lifecycle.
  getIt
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(repository: getIt<AuthRepository>()),
    )
    ..registerFactory<IssueListBloc>(
      () => IssueListBloc(repository: getIt<IssueRepository>()),
    )
    ..registerFactory<IssueFormCubit>(
      () => IssueFormCubit(
        repository: getIt<IssueRepository>(),
        photoPicker: getIt<PhotoPicker>(),
      ),
    )
    ..registerFactoryParam<IssueDetailsCubit, String, void>(
      (issueId, _) => IssueDetailsCubit(
        repository: getIt<IssueRepository>(),
        issueId: issueId,
      ),
    )
    ..registerFactory<AdminDashboardCubit>(
      () => AdminDashboardCubit(repository: getIt<IssueRepository>()),
    )
    ..registerFactory<AdminIssueCubit>(
      () => AdminIssueCubit(
        repository: getIt<IssueRepository>(),
        photoPicker: getIt<PhotoPicker>(),
      ),
    )
    ..registerFactory<StudentStatsCubit>(
      () => StudentStatsCubit(repository: getIt<IssueRepository>()),
    )
    ..registerFactory<ProfileCubit>(
      () => ProfileCubit(repository: getIt<ProfileRepository>()),
    )
    ..registerFactoryParam<FeedbackCubit, String, void>(
      (issueId, _) => FeedbackCubit(
        repository: getIt<FeedbackRepository>(),
        issueId: issueId,
      ),
    );
}
