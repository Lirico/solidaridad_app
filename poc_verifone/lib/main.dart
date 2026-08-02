import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:poc_verifone/psdk/psdk_bridge.dart';
import 'package:poc_verifone/psdk/psdk_msr_mock.dart';
import 'package:poc_verifone/receipt/receipt_data.dart';
import 'package:poc_verifone/receipt/receipt_formatter.dart';
import 'package:poc_verifone/receipt/sale_response_mock.dart';

void main() {
  runApp(const PocVerifoneApp());
}

class PocVerifoneApp extends StatelessWidget {
  const PocVerifoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POC Verifone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PsdkBridge _psdk = PsdkBridge();
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  int _counter = 0;
  bool _useMock = true;
  ReceiptData? _lastReceipt;
  Map<String, dynamic>? _lastSaleJson;
  String _log =
      'Solo se mockea Leer banda (whitelist). '
      'Init PSDK → sdiReady → Venta mock → Imprimir ticket (térmica real).';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusSub = _psdk.statusEvents.listen((event) {
      _appendLog('event: ${const JsonEncoder.withIndent('  ').convert(event)}');
    });
  }

  /// Only MSR is mockable (VCL/whitelist). Everything else hits native PSDK.
  Future<Map<String, dynamic>> _readMsr() async {
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return PsdkMsrMock.readMsrSuccess(timeoutSec: 30);
    }
    return _psdk.readMsr(timeoutSec: 30);
  }

  Future<Map<String, dynamic>> _mockSale() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final json = SaleResponseMock.approvedGarrafa10();
    final receipt = SaleResponseMock.toReceipt(json);
    setState(() {
      _lastSaleJson = json;
      _lastReceipt = receipt;
    });
    return {
      'ok': true,
      'mocked': true,
      'sale': json,
      'receiptReady': true,
      'hint': 'Usá Ver ticket / Imprimir ticket',
    };
  }

  Future<Map<String, dynamic>> _previewTicket() async {
    final receipt = _lastReceipt;
    if (receipt == null) {
      return {
        'ok': false,
        'message': 'No hay venta. Tocá Venta mock primero.',
      };
    }
    final plain = ReceiptFormatter.toPlainText(receipt);
    final html = ReceiptFormatter.toHtml(receipt);
    _appendLog('ticket plain:\n$plain');
    return {
      'ok': true,
      'plain': plain,
      'htmlLength': html.length,
      'sale': _lastSaleJson,
    };
  }

  /// Always native thermal (`SdiPrinter.printHTML`). Requires Init + sdiReady.
  Future<Map<String, dynamic>> _printTicket() async {
    final receipt = _lastReceipt;
    if (receipt == null) {
      return {
        'ok': false,
        'message': 'No hay venta. Tocá Venta mock primero.',
      };
    }
    final html = ReceiptFormatter.toHtml(receipt);
    final native = await _psdk.printHtml(html);
    return {
      ...native,
      'plainPreview': ReceiptFormatter.toPlainText(receipt),
    };
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  void _appendLog(String line) {
    setState(() {
      _log = '${DateTime.now().toIso8601String().substring(11, 19)}  $line\n$_log';
    });
  }

  Future<void> _run(String label, Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      final pretty = const JsonEncoder.withIndent('  ').convert(result);
      _appendLog('$label → $pretty');
      // ignore: avoid_print
      print('===== $label =====\n$pretty');
    } catch (e) {
      _appendLog('$label ERROR: $e');
      // ignore: avoid_print
      print('$label ERROR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReceipt = _lastReceipt != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('POC Verifone V660P'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contador: $_counter',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mock solo lectura de banda'),
              subtitle: Text(
                _useMock
                    ? 'Leer banda → fixture ${PsdkMsrMock.panDisplay}. '
                        'Init/print siguen nativos.'
                    : 'Leer banda → MSR real (hace falta whitelist)',
              ),
              value: _useMock,
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                        _useMock = v;
                        _appendLog(
                          v
                              ? 'Mock MSR ON (solo readMsr)'
                              : 'Mock MSR OFF → swipe real',
                        );
                      }),
            ),
            if (hasReceipt)
              Text(
                'Última venta: ${_lastReceipt!.transactionNumber} · '
                '${_lastReceipt!.statusLabel} · ${_lastReceipt!.amount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => setState(() => _counter++),
                  child: const Text('Sumar'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _run('initialize', _psdk.initialize),
                  child: const Text('Init PSDK'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _run('getStatus', _psdk.getStatus),
                  child: const Text('Status'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _run('getDeviceInfo', _psdk.getDeviceInfo),
                  child: const Text('Device info'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run('readMsr', _readMsr),
                  child: Text(_useMock ? 'Leer banda (mock)' : 'Leer banda'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run('ventaMock', _mockSale),
                  child: const Text('Venta mock'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || !hasReceipt
                      ? null
                      : () => _run('verTicket', _previewTicket),
                  child: const Text('Ver ticket'),
                ),
                FilledButton(
                  onPressed: _busy || !hasReceipt
                      ? null
                      : () => _run('imprimirTicket', _printTicket),
                  child: const Text('Imprimir ticket'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run('tearDown', _psdk.tearDown),
                  child: const Text('Tear down'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Log', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
