/// Unified response wrapper used throughout the app.
/// Backed by Firebase instead of HTTP — kept for interface compatibility.
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final int statusCode;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode = 200,
    this.errors,
  });

  factory ApiResponse.ok({dynamic data, String message = 'Success'}) {
    return ApiResponse(success: true, message: message, data: data);
  }

  factory ApiResponse.error(String message, {int statusCode = 500, Map<String, dynamic>? errors}) {
    return ApiResponse(
      success: false,
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }
}
