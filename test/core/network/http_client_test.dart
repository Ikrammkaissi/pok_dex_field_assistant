import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';

void main() {
  group('PokeApiHttpClient', () {
    test('returns decoded map on 200 response', () async {
      final raw = MockClient((request) async {
        return http.Response('{"name":"bulbasaur","id":1}', 200);
      });
      final client = PokeApiHttpClient(raw);

      final result = await client.get('/pokemon/1');

      expect(result['name'], 'bulbasaur');
      expect(result['id'], 1);
    });

    test('throws ServerException on non-2xx response', () async {
      final raw = MockClient((request) async => http.Response('Not found', 404));
      final client = PokeApiHttpClient(raw);

      await expectLater(
        () => client.get('/pokemon/missing'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('throws NetworkException on SocketException', () async {
      final raw = MockClient((request) async {
        throw const SocketException('no route to host');
      });
      final client = PokeApiHttpClient(raw);

      await expectLater(
        () => client.get('/pokemon/1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException with timeout message on TimeoutException',
        () async {
      final raw = MockClient((request) async {
        throw TimeoutException('slow connection');
      });
      final client = PokeApiHttpClient(raw);

      await expectLater(
        () => client.get('/pokemon/1'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            'Request timed out.',
          ),
        ),
      );
    });

    test('throws ParseException on malformed JSON body', () async {
      final raw = MockClient((request) async => http.Response('{bad json', 200));
      final client = PokeApiHttpClient(raw);

      await expectLater(
        () => client.get('/pokemon/1'),
        throwsA(isA<ParseException>()),
      );
    });
  });
}
