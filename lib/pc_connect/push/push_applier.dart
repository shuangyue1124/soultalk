import 'push_validator.dart';

class PushApplier {
  final PushValidator validator;

  const PushApplier({this.validator = const PushValidator()});

  Future<Map<String, dynamic>> validateOnly(
    Map<String, dynamic> proposal,
  ) async {
    final result = validator.validate(proposal);
    return {
      'accepted': result.allowed,
      if (!result.allowed) 'reason': result.reason,
    };
  }
}
