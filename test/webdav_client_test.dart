import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() {
  late HttpServer server;
  late webdav.Client client;
  late List<String> requests;
  late List<int> uploaded;
  const content = [0, 1, 127, 128, 255];

  setUp(() async {
    requests = [];
    uploaded = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}';
    client = webdav.newClient(base, user: 'user', password: 'pwd');
    client.setConnectTimeout(3000);
    client.setSendTimeout(3000);
    client.setReceiveTimeout(3000);
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      final response = request.response;
      final path = request.uri.path;
      if (path == '/auth' &&
          request.headers.value(HttpHeaders.authorizationHeader) !=
              'Basic ${base64Encode(utf8.encode('user:pwd'))}') {
        response.statusCode = HttpStatus.unauthorized;
        response.headers
            .set(HttpHeaders.wwwAuthenticateHeader, 'Basic realm="test"');
      } else if (path == '/redirect301' || path == '/redirect302') {
        response.statusCode = path.endsWith('301') ? 301 : 302;
        response.headers.set(HttpHeaders.locationHeader, '$base/file');
      } else if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.ok;
      } else if (request.method == 'MKCOL') {
        // Some WebDAV services reject MKCOL even when the parent exists.
        response.statusCode = HttpStatus.forbidden;
      } else if (request.method == 'PUT') {
        uploaded = await request
            .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
        response.statusCode = HttpStatus.created;
      } else if (path == '/missing') {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.statusCode = HttpStatus.ok;
        if (request.method == 'GET') response.add(content);
      }
      await response.close();
    });
  });

  tearDown(() async {
    client.c.close(force: true);
    await server.close(force: true);
  });

  test('ping uses OPTIONS', () async {
    await client.ping();
    expect(requests, ['OPTIONS /']);
  });

  test('HEAD distinguishes existing and missing files', () async {
    expect(await client.isExists('/file'), isTrue);
    expect(await client.isExists('/missing'), isFalse);
    expect(requests, ['HEAD /file', 'HEAD /missing']);
  });

  test('existence check accepts a full URL', () async {
    expect(
        await client.isExists('http://127.0.0.1:${server.port}/file'), isTrue);
    expect(requests, ['HEAD /file']);
  });

  test('HEAD retries with Basic authentication', () async {
    expect(await client.isExists('/auth'), isTrue);
    expect(requests, ['HEAD /auth', 'HEAD /auth']);
  });

  for (final status in [301, 302]) {
    test('HEAD follows $status redirect', () async {
      expect(await client.isExists('/redirect$status'), isTrue);
      expect(requests, ['HEAD /redirect$status', 'HEAD /file']);
    });

    test('byte download follows $status redirect', () async {
      expect(await client.read('/redirect$status'), content);
      expect(
          requests, containsAllInOrder(['GET /redirect$status', 'GET /file']));
    });
  }

  test('stream download follows 301 redirect', () async {
    final directory = await Directory.systemTemp.createTemp('webdav-test-');
    try {
      final output = File('${directory.path}/download.bin');
      await client.read2File('/redirect301', output.path);
      expect(await output.readAsBytes(), content);
      expect(requests, containsAllInOrder(['GET /redirect301', 'GET /file']));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('byte upload continues after rejected parent creation', () async {
    await client.write('/parent/file', Uint8List.fromList(content));
    expect(uploaded, content);
    expect(requests,
        ['OPTIONS /parent/file', 'MKCOL /parent/', 'PUT /parent/file']);
  });

  test('cancelled request reports cancellation', () async {
    final token = CancelToken()..cancel('test cancellation');
    await expectLater(
        client.isExists('/file', cancelToken: token),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)));
  });
}
