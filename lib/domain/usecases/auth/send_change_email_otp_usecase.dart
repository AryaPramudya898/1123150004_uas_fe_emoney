import '../../repositories/auth_repository.dart';

class SendChangeEmailOtpUsecase {
  final AuthRepository _repository;
  SendChangeEmailOtpUsecase(this._repository);

  Future<void> call(String newEmail) => _repository.sendChangeEmailOtp(newEmail);
}
