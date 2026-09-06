class AppException implements Exception {
  const AppException(this.message, {this.code = 'unknown', this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
