/// Result of validating connect form input.
sealed class ConnectValidationResult {
  const ConnectValidationResult();
}

class ConnectValidationOk extends ConnectValidationResult {
  const ConnectValidationOk();
}

class ConnectValidationError extends ConnectValidationResult {
  const ConnectValidationError(this.message);
  final String message;
}

/// Returns an error if [address] is empty after trim.
ConnectValidationResult validateConnectAddress(String address) {
  if (address.trim().isEmpty) {
    return const ConnectValidationError('Enter the PC address.');
  }
  return const ConnectValidationOk();
}

/// Returns an error if [code] is not exactly six digits.
ConnectValidationResult validatePairingCode(String code) {
  final trimmed = code.trim();
  if (trimmed.length != 6) {
    return const ConnectValidationError('Enter the 6-digit pairing code from the PC.');
  }
  if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
    return const ConnectValidationError('The pairing code must be six digits.');
  }
  return const ConnectValidationOk();
}
