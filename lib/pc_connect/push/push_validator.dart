class PushValidationResult {
  final bool allowed;
  final String? reason;

  const PushValidationResult.allowed() : allowed = true, reason = null;
  const PushValidationResult.rejected(this.reason) : allowed = false;
}

class PushValidator {
  const PushValidator();

  static const _allowedTables = {'messages'};
  static const _allowedOperations = {'insert'};
  static const _secretFields = {
    'api_key',
    'password',
    'secret',
    'access_key',
    'secret_key',
    'token',
  };

  PushValidationResult validate(Map<String, dynamic> proposal) {
    final table = proposal['table'] as String?;
    final operation = proposal['operation'] as String?;
    final row = proposal['row'];
    if (table == null || !_allowedTables.contains(table)) {
      return PushValidationResult.rejected('table_not_allowed');
    }
    if (operation == null || !_allowedOperations.contains(operation)) {
      return PushValidationResult.rejected('operation_not_allowed');
    }
    if (row is! Map<String, dynamic>) {
      return PushValidationResult.rejected('invalid_row');
    }
    if (_containsSecretField(row)) {
      return PushValidationResult.rejected('secret_field_not_allowed');
    }
    if (table == 'messages' && row['content'] is! String) {
      return PushValidationResult.rejected('message_content_required');
    }
    return const PushValidationResult.allowed();
  }

  bool _containsSecretField(Map<String, dynamic> row) {
    for (final key in row.keys) {
      final normalized = key.toLowerCase();
      if (_secretFields.any(normalized.contains)) return true;
    }
    return false;
  }
}
