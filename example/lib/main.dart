import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_speed_meter/network_speed_meter.dart';

void main() {
  runApp(const NetworkSpeedMeterDemoApp());
}

class NetworkSpeedMeterDemoApp extends StatefulWidget {
  const NetworkSpeedMeterDemoApp({super.key});

  @override
  State<NetworkSpeedMeterDemoApp> createState() =>
      _NetworkSpeedMeterDemoAppState();
}

class _NetworkSpeedMeterDemoAppState extends State<NetworkSpeedMeterDemoApp> {
  final _log = <String>[];
  late final TextEditingController _intervalController;
  StreamSubscription<NetworkSpeedSnapshot>? _subscription;
  NetworkSpeedSnapshot? _latest;
  bool _foreground = false;
  bool _isMonitoring = false;
  int _intervalMs = 1000;

  @override
  void dispose() {
    _subscription?.cancel();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(text: _intervalMs.toString());
  }

  Future<void> _start() async {
    final config = NetworkSpeedConfig(
      interval: Duration(milliseconds: _intervalMs),
      enableForegroundService: _foreground,
      showNotification: true,
      notificationTitle: 'Network speed monitor',
      notificationContent: 'Monitoring traffic...',
    );
    await networkSpeedMeter.startMonitoring(config: config);
    _subscription?.cancel();
    _subscription = networkSpeedMeter.speedStream.listen((snapshot) {
      setState(() {
        _latest = snapshot;
        _log.insert(
          0,
          '${snapshot.timestamp.toIso8601String()} '
          'D:${snapshot.formattedDownload} U:${snapshot.formattedUpload}',
        );
      });
    });
    setState(() => _isMonitoring = true);
  }

  Future<void> _stop() async {
    await networkSpeedMeter.stopMonitoring();
    await _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isMonitoring = false;
    });
  }

  Widget _buildSpeedCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Network Speed Meter'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildSpeedCard(
                    'Download',
                    latest?.formattedDownload ?? '--',
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildSpeedCard(
                    'Upload',
                    latest?.formattedUpload ?? '--',
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSpeedCard(
                'Total',
                latest?.formattedTotal ?? '--',
                Colors.orange,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Interval (ms)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: _intervalController,
                      onChanged: (value) {
                        final parsed = int.tryParse(value) ?? _intervalMs;
                        setState(() => _intervalMs = parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Use foreground service'),
                      Switch(
                        value: _foreground,
                        onChanged: (value) => setState(() {
                          _foreground = value;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Android 13+: Request POST_NOTIFICATIONS permission to show the notification. '
                'Android 14+: Foreground service type dataSync is declared.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isMonitoring ? null : _start,
                    child: const Text('Start monitoring'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isMonitoring ? _stop : null,
                    child: const Text('Stop'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Update log'),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(_log[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
