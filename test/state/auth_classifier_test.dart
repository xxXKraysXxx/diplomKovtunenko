import 'package:flutter_test/flutter_test.dart';
import 'package:ncti_schedule_client/state/auth.dart';

void main() {
  group('classifyBackendError', () {
    test('SocketException → offline', () {
      expect(
        classifyBackendError(
            'SocketException: Failed host lookup: schedule-ncti.thehexus.ru'),
        BackendErrorKind.offline,
      );
    });

    test('Failed host lookup (without exception name) → offline', () {
      expect(
        classifyBackendError(
            "ClientException with SocketException: Failed host lookup: 'schedule-ncti.thehexus.ru', uri=https://schedule-ncti.thehexus.ru/graphql"),
        BackendErrorKind.offline,
      );
    });

    test('Connection refused → offline', () {
      expect(
        classifyBackendError('SocketException: Connection refused'),
        BackendErrorKind.offline,
      );
    });

    test('TLS handshake failure → offline', () {
      expect(
        classifyBackendError(
            'HandshakeException: Connection terminated during handshake'),
        BackendErrorKind.offline,
      );
    });

    test('TimeoutException → timeout', () {
      expect(
        classifyBackendError('TimeoutException after 0:00:08.000000'),
        BackendErrorKind.timeout,
      );
    });

    test('"timed out" phrase → timeout', () {
      expect(
        classifyBackendError('The connection has timed out'),
        BackendErrorKind.timeout,
      );
    });

    test('503 Service Unavailable → server', () {
      expect(
        classifyBackendError(
            'ServerException(originalException: HttpException, parsedResponse: null, statusCode: 503)'),
        BackendErrorKind.server,
      );
    });

    test('502 bare prefix → server', () {
      expect(
        classifyBackendError('502 Bad Gateway'),
        BackendErrorKind.server,
      );
    });

    test('XMLHttpRequest error (web) → offline', () {
      expect(
        classifyBackendError('XMLHttpRequest error.'),
        BackendErrorKind.offline,
      );
    });

    test('Anything else → unknown', () {
      expect(
        classifyBackendError(
            'Some weird thing the server emitted that we have not seen'),
        BackendErrorKind.unknown,
      );
    });

    test('Empty string → unknown', () {
      expect(classifyBackendError(''), BackendErrorKind.unknown);
    });
  });
}
