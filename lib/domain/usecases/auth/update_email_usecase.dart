import '../../entities/user_entity.dart';
import '../../repositories/auth_repository.dart';

class UpdateEmailUsecase {
  final AuthRepository _repository;
  UpdateEmailUsecase(this._repository);

  Future<UserEntity> call(String newEmail, String code) => _repository.updateEmail(newEmail, code);
}
