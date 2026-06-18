import '../../entities/user_entity.dart';
import '../../repositories/auth_repository.dart';

class UpdateProfileUsecase {
  final AuthRepository _repository;
  UpdateProfileUsecase(this._repository);

  Future<UserEntity> call(String name) => _repository.updateProfile(name);
}
