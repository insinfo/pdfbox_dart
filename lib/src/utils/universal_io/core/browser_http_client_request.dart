
import '../io.dart';

/// Implemented by [HttpClientRequest] when the application runs in browser.
mixin BrowserHttpClientRequest on HttpClientRequest {
  /// Sets _responseType_ in XMLHttpRequest for this _XHR_ request.
  ///
  /// # Possible values
  ///   * "arraybuffer" or `null` (default)
  ///   * "json"
  ///   * "text" (makes streaming possible)
  ///
  String? get browserResponseType;

  set browserResponseType(String? value);

  /// Enables ["credentials mode"](https://developer.mozilla.org/en-US/docs/Web/API/Request/credentials)
  /// for this _XHR_ request. Disabled by default.
  ///
  /// "Credentials mode" causes cookies and other credentials to be sent and
  /// received. It has complicated implications for CORS headers required from
  /// the server.
  ///
  /// # Example
  /// ```
  /// Future<void> main() async {
  ///   final client = HttpClient();
  ///   final request = client.getUrl(Url.parse('http://host/path'));
  ///   if (request is BrowserHttpClientRequest) {
  ///     request.browserCredentialsMode = true;
  ///   }
  ///   final response = await request.close();
  ///   // ...
  /// }
  ///  ```
  bool browserCredentialsMode = false;
}
