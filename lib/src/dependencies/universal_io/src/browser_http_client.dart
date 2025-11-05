

import 'dart:async';

import '../io.dart';

/// Implemented by [HttpClient] when the application runs in browser.
abstract class BrowserHttpClient implements HttpClient {
  /// HTTP request header "Accept" MIMEs that will cause XMLHttpRequest
  /// to use request type "text", which also makes it possible to read the
  /// HTTP response body progressively in chunks.
  static const Set<String> defaultTextMimes = {
    'application/grpc-web-text',
    'application/grpc-web-text+proto',
    'text/*',
  };

  /// Enables you to set [BrowserHttpClientRequest.browserRequestType] before
  /// any _XHR_ request is sent to the server.
  FutureOr<void> Function(BrowserHttpClientRequest request)?
      onBrowserHttpClientRequestClose;

  /// Enables [CORS "credentials mode"](https://developer.mozilla.org/en-US/docs/Web/API/Request/credentials)
  /// for all _XHR_ requests. Disabled by default.
  ///
  /// "Credentials mode" causes cookies and other credentials to be sent and
  /// received. It has complicated implications for CORS headers required from
  /// the server.
  ///
  /// # Example
  /// ```
  /// Future<void> main() async {
  ///   final client = HttpClient();
  ///   if (client is BrowserHttpClient) {
  ///     client.browserCredentialsMode = true;
  ///   }
  ///   // ...
  /// }
  ///  ```
  bool browserCredentialsMode = false;

  BrowserHttpClient.constructor();
}
