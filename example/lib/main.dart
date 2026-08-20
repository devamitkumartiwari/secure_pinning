import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:secure_pinning/secure_pinning.dart';
import 'package:secure_pinning_dio/secure_pinning_dio.dart';
import 'package:secure_pinning_http/secure_pinning_http.dart';

void main() => runApp(const SecurePinningExampleApp());

/// The three [PinningMode] values, in the order shown by the demo's mode
/// selector.
enum _PinningModeOption {
  spki('SPKI', 'Public-key hash — survives certificate renewal. Default.'),
  legacyLeafHash(
    'Legacy leaf hash',
    'Whole-certificate hash — breaks on any renewal, even a same-key one.',
  ),
  legacyCaHash(
    'Legacy CA hash',
    'Pins a CA/root certificate. Not supported by the pure-Dart engine — '
        'only the native probe (check()) button below can validate it.',
  );

  const _PinningModeOption(this.label, this.description);

  final String label;
  final String description;
}

class SecurePinningExampleApp extends StatelessWidget {
  const SecurePinningExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'secure_pinning example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PinningDemoPage(),
    );
  }
}

class PinningDemoPage extends StatefulWidget {
  const PinningDemoPage({super.key});

  @override
  State<PinningDemoPage> createState() => _PinningDemoPageState();
}

class _PinningDemoPageState extends State<PinningDemoPage> {
  // These SPKI pins are placeholders (hex, not base64 — SecurePinningConfig
  // expects hex). Replace them with your own host's pins before running
  // against a real backend — compute them with:
  //
  //   openssl s_client -connect HOST:443 -servername HOST < /dev/null 2>/dev/null \
  //     | openssl x509 -pubkey -noout \
  //     | openssl pkey -pubin -outform der \
  //     | openssl dgst -sha256 -hex \
  //     | awk '{print $NF}'
  //
  // Always list a backup pin (e.g. a leaf-adjacent CA's SPKI) so a future
  // key rotation on the server doesn't brick the app.
  final _hostController = TextEditingController(text: 'example.com');
  final _pinsController = TextEditingController(
    text:
        '0000000000000000000000000000000000000000000000000000000000000000\n'
        '1111111111111111111111111111111111111111111111111111111111111111',
  );

  // Only read/used when _mode is legacyCaHash — SecurePinningConfig
  // requires a non-empty acknowledgedRisk for that mode. Pre-filled so the
  // demo works without forcing input; see PinningMode.legacyCaHash's doc
  // comment for why this friction is deliberate.
  final _acknowledgedRiskController = TextEditingController(
    text:
        'Example app — demonstrating the native probe API only, not '
        'production use.',
  );

  _PinningModeOption _mode = _PinningModeOption.spki;
  bool _busy = false;
  final _log = <_LogEntry>[];

  @override
  void dispose() {
    _hostController.dispose();
    _pinsController.dispose();
    _acknowledgedRiskController.dispose();
    super.dispose();
  }

  SecurePinningConfig get _config => SecurePinningConfig(
    host: _hostController.text.trim(),
    pins: _pinsController.text
        .split(RegExp(r'[\n,]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(),
    mode: switch (_mode) {
      _PinningModeOption.spki => const PinningMode.spki(),
      _PinningModeOption.legacyLeafHash => const PinningMode.legacyLeafHash(),
      _PinningModeOption.legacyCaHash => PinningMode.legacyCaHash(
        acknowledgedRisk: _acknowledgedRiskController.text.trim(),
      ),
    },
  );

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      _append(label, result, isError: false);
    } on SecurePinningException catch (error) {
      _append(label, error.toString(), isError: true);
    } catch (error) {
      _append(label, 'Unexpected error: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _append(String label, String message, {required bool isError}) {
    setState(() {
      _log.insert(
        0,
        _LogEntry(label: label, message: message, isError: isError),
      );
    });
  }

  Future<String> _runRawClient() async {
    final config = _config;
    final client = SecurePinning.createHttpClient(config);
    try {
      final request = await client.getUrl(Uri.https(config.host, '/'));
      final response = await SecurePinning.enforceReadTimeout(
        request.close(),
        config.readTimeout,
      );
      final body = await response.transform(utf8.decoder).join();
      return 'HTTP ${response.statusCode} — ${body.length} bytes';
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _runHttpClient() async {
    final client = SecurePinningHttpClient(_config);
    try {
      final response = await client.get(Uri.https(_config.host, '/'));
      return 'HTTP ${response.statusCode} — ${response.bodyBytes.length} bytes';
    } finally {
      client.close();
    }
  }

  Future<String> _runCheck() async {
    final config = _config;
    final result = await SecurePinning.check(
      url: 'https://${config.host}',
      config: config,
    );
    if (result.isTrusted) {
      return 'Trusted — matched pin ${result.matchedPinFingerprint}';
    }
    return 'Not trusted — ${result.errorCode}: ${result.errorDetail}';
  }

  Future<String> _runDio() async {
    final config = _config;
    final dio = Dio(BaseOptions(baseUrl: 'https://${config.host}'));
    dio.interceptors.add(SecurePinningInterceptor(dio, config));
    try {
      final response = await dio.get<String>('/');
      return 'HTTP ${response.statusCode} — ${(response.data ?? '').length} bytes';
    } on DioException catch (error) {
      if (error.error is SecurePinningException) {
        throw error.error! as SecurePinningException;
      }
      rethrow;
    } finally {
      dio.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('secure_pinning example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText:
                    'Pins (hex, one per line — placeholders, replace '
                    'with your host\'s real pins)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_PinningModeOption>(
                segments: [
                  for (final option in _PinningModeOption.values)
                    ButtonSegment(value: option, label: Text(option.label)),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() => _mode = selection.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _mode.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_mode == _PinningModeOption.legacyCaHash) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _acknowledgedRiskController,
                decoration: const InputDecoration(
                  labelText: 'Acknowledged risk (required for legacy CA hash)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run('Raw HttpClient', _runRawClient),
                  child: const Text('Raw HttpClient'),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run('package:http', _runHttpClient),
                  child: const Text('package:http'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run('Dio', _runDio),
                  child: const Text('Dio'),
                ),
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _run('Native probe (check())', _runCheck),
                  child: const Text('Native probe (check())'),
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            const Divider(height: 32),
            Expanded(
              child: _log.isEmpty
                  ? const Center(
                      child: Text('Run a request to see results here.'),
                    )
                  : ListView.separated(
                      itemCount: _log.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final entry = _log[index];
                        return ListTile(
                          leading: Icon(
                            entry.isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: entry.isError ? Colors.red : Colors.green,
                          ),
                          title: Text(entry.label),
                          subtitle: Text(entry.message),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntry {
  _LogEntry({
    required this.label,
    required this.message,
    required this.isError,
  });

  final String label;
  final String message;
  final bool isError;
}
