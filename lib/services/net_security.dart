/// Shared SSRF guard: rejects any URI that isn't HTTPS or whose host isn't
/// in [allowedHosts]. Used by every outbound network service in this app so
/// the allowlist check lives in exactly one place.
void assertAllowedHttpsHost(Uri uri, Set<String> allowedHosts) {
  if (uri.scheme != 'https') throw StateError('Non-HTTPS URL rejected.');
  if (!allowedHosts.contains(uri.host)) {
    throw StateError('Disallowed host: ${uri.host}');
  }
}
