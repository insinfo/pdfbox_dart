
import '../io.dart';

/// Implemented by [HttpClientResponse] when the application runs in browser.
mixin BrowserHttpClientResponse on HttpClientResponse {
  /// Response object of _XHR_ request.
  ///
  /// You need to finish reading this [HttpClientResponse] to get the final
  /// value.
  dynamic get browserResponse;

  set browserResponse(dynamic value);
}
