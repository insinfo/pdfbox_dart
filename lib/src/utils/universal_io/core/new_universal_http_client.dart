
import '../io.dart';

import '_helpers.dart' as helpers;

/// Constructs a new [HttpClient] that will be [BrowserHttpClient] in browsers
/// and the normal _dart:io_ HTTP client everywhere else.
HttpClient newUniversalHttpClient() => helpers.newHttpClient();
