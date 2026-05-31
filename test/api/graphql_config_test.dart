import 'package:flutter_test/flutter_test.dart';

import 'package:ncti_schedule_client/api/graphql_config.dart';

void main() {
  group('resolveGraphqlUrl', () {
    test('returns native URL when API_HOST is provided (non-web)', () {
      expect(
        resolveGraphqlUrl(
          apiHostOverride: 'thehexus.ru',
          debugModeOverride: false,
          isWebOverride: false,
        ),
        'http://thehexus.ru:9997/graphql',
      );
    });

    test('returns HTTPS URL via reverse proxy when web', () {
      expect(
        resolveGraphqlUrl(
          apiHostOverride: 'thehexus.ru',
          debugModeOverride: false,
          isWebOverride: true,
        ),
        'https://thehexus.ru/graphql',
      );
    });

    test('API_URL override wins over host+platform logic', () {
      expect(
        resolveGraphqlUrl(
          apiUrlOverride: 'https://foo.example/graphql',
          apiHostOverride: 'thehexus.ru',
          debugModeOverride: false,
          isWebOverride: true,
        ),
        'https://foo.example/graphql',
      );
    });

    test('release mobile with no defines falls back to VPS GraphQL URL', () {
      expect(
        resolveGraphqlUrl(
          apiHostOverride: '',
          apiUrlOverride: '',
          debugModeOverride: false,
          isWebOverride: false,
        ),
        'https://schedule-ncti.thehexus.ru/graphql',
      );
    });

    test('allows localhost fallback in debug mode when API_HOST is empty', () {
      expect(
        () => resolveGraphqlUrl(
          apiHostOverride: '',
          debugModeOverride: true,
          isWebOverride: false,
        ),
        returnsNormally,
      );
    });

    test('returns non-empty URL in debug mode with empty API_HOST', () {
      final url = resolveGraphqlUrl(
        apiHostOverride: '',
        debugModeOverride: true,
        isWebOverride: false,
      );
      expect(url, contains(':9997/graphql'));
    });

    test('web falls back to same-origin /graphql when nothing is configured', () {
      expect(
        resolveGraphqlUrl(
          apiHostOverride: '',
          apiUrlOverride: '',
          debugModeOverride: false,
          isWebOverride: true,
          webOriginOverride: 'https://schedule-ncti.thehexus.ru',
        ),
        'https://schedule-ncti.thehexus.ru/graphql',
      );
    });

    test('web honors explicit API_URL over same-origin fallback', () {
      expect(
        resolveGraphqlUrl(
          apiUrlOverride: 'https://custom.example/graphql',
          apiHostOverride: '',
          debugModeOverride: false,
          isWebOverride: true,
          webOriginOverride: 'https://schedule-ncti.thehexus.ru',
        ),
        'https://custom.example/graphql',
      );
    });
  });

  group('resolveBackendOrigin', () {
    test('web uses https + host without port', () {
      expect(
        resolveBackendOrigin(apiHostOverride: 'thehexus.ru', isWebOverride: true),
        'https://thehexus.ru',
      );
    });

    test('native uses http + host:9997', () {
      expect(
        resolveBackendOrigin(apiHostOverride: 'thehexus.ru', isWebOverride: false),
        'http://thehexus.ru:9997',
      );
    });

    test('web falls back to page origin when nothing is configured', () {
      expect(
        resolveBackendOrigin(
          apiHostOverride: '',
          apiUrlOverride: '',
          isWebOverride: true,
          webOriginOverride: 'https://schedule-ncti.thehexus.ru',
        ),
        'https://schedule-ncti.thehexus.ru',
      );
    });
  });
}
