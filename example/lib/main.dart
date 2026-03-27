import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:network_speed_meter/network_speed_meter.dart';

void main() {
  runApp(const NetworkSpeedMeterDemoApp());
}

class SpeedSample {
  SpeedSample({
    required this.timestamp,
    required this.downloadBps,
    required this.uploadBps,
  });

  final DateTime timestamp;
  final int downloadBps;
  final int uploadBps;
}

class SessionSummary {
  SessionSummary({
    required this.startedAt,
    required this.endedAt,
    required this.downloadBytes,
    required this.uploadBytes,
    required this.peakDownloadBps,
    required this.peakUploadBps,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int downloadBytes;
  final int uploadBytes;
  final int peakDownloadBps;
  final int peakUploadBps;

  Duration get duration => endedAt.difference(startedAt);

  double get averageDownloadBps =>
      duration.inSeconds == 0 ? 0 : downloadBytes / duration.inSeconds;

  double get averageUploadBps =>
      duration.inSeconds == 0 ? 0 : uploadBytes / duration.inSeconds;
}

class UsageTotals {
  UsageTotals({
    this.downloadBytes = 0,
    this.uploadBytes = 0,
  });

  int downloadBytes;
  int uploadBytes;

  int get totalBytes => downloadBytes + uploadBytes;
}

class NetworkSpeedMeterDemoApp extends StatefulWidget {
  const NetworkSpeedMeterDemoApp({super.key});

  @override
  State<NetworkSpeedMeterDemoApp> createState() =>
      _NetworkSpeedMeterDemoAppState();
}

class _NetworkSpeedMeterDemoAppState extends State<NetworkSpeedMeterDemoApp> {
  static const _startupCheckDelay = Duration(milliseconds: 250);

  final _eventLog = <String>[];
  final _chartSamples = <SpeedSample>[];
  final _history = <SessionSummary>[];
  final _dailyUsage = <DateTime, UsageTotals>{};
  late final TextEditingController _intervalController;

  StreamSubscription<NetworkSpeedSnapshot>? _subscription;
  NetworkSpeedSnapshot? _latest;
  DateTime? _sessionStartedAt;
  DateTime? _lastSampleAt;

  bool _foreground = true;
  bool _showNotification = true;
  bool _autoStart = false;
  bool _isMonitoring = false;
  int _intervalMs = 1000;
  int _currentTab = 0;
  int _sessionDownloadBytes = 0;
  int _sessionUploadBytes = 0;
  int _peakDownloadBps = 0;
  int _peakUploadBps = 0;
  int _chartVersion = 0;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(text: _intervalMs.toString());
    if (_autoStart) {
      _startMonitoring();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _intervalController.dispose();
    super.dispose();
  }

  double get _sessionDurationSeconds {
    final start = _sessionStartedAt;
    if (start == null) return 0;
    final end = _isMonitoring ? DateTime.now() : (_lastSampleAt ?? DateTime.now());
    final duration = end.difference(start);
    return max(duration.inMilliseconds / 1000, 0.0);
  }

  UsageTotals get _todayUsage {
    final now = DateTime.now();
    final key = DateTime(now.year, now.month, now.day);
    return _dailyUsage[key] ?? UsageTotals();
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }

  String _formatDuration(Duration duration) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final hours = two(duration.inHours);
    final minutes = two(duration.inMinutes.remainder(60));
    final seconds = two(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _log(String message) {
    if (!mounted) return;
    setState(() {
      _eventLog.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $message',
      );
      if (_eventLog.length > 80) {
        _eventLog.removeLast();
      }
    });
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    Future<bool> _startWithConfig(bool useForegroundService) async {
      final config = NetworkSpeedConfig(
        interval: Duration(milliseconds: _intervalMs),
        enableForegroundService: useForegroundService,
        showNotification: _showNotification,
        notificationTitle: 'Network speed meter',
        notificationContent: useForegroundService
            ? 'Foreground service active'
            : 'Monitoring while app is open',
      );
      await networkSpeedMeter.startMonitoring(config: config);
      await Future<void>.delayed(_startupCheckDelay);
      return networkSpeedMeter.isMonitoring;
    }

    await _subscription?.cancel();
    _subscription = networkSpeedMeter.speedStream.listen(
      _handleSnapshot,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isMonitoring = false;
        });
        _log('Monitoring error: $error');
      },
    );

    try {
      var startedWithForeground = _foreground;
      var started = await _startWithConfig(startedWithForeground);

      if (!started && startedWithForeground) {
        _log('Foreground mode unavailable, retrying in-app monitoring');
        startedWithForeground = false;
        started = await _startWithConfig(false);
      }

      if (!started) {
        throw StateError(
          'Monitoring failed to start after validation. '
          'Check notification/service permissions and try again.',
        );
      }

      if (!mounted) return;
      setState(() {
        _isMonitoring = true;
        _sessionStartedAt = DateTime.now();
      });
      _log('Monitoring started (interval ${_intervalMs}ms)');
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      if (!mounted) return;
      setState(() {
        _isMonitoring = false;
      });
      _log('Failed to start monitoring: $error');
    }
  }

  Future<void> _stopMonitoring() async {
    await networkSpeedMeter.stopMonitoring();
    await _subscription?.cancel();
    _subscription = null;
    if (_sessionStartedAt != null) {
      _history.insert(
        0,
        SessionSummary(
          startedAt: _sessionStartedAt!,
          endedAt: DateTime.now(),
          downloadBytes: _sessionDownloadBytes,
          uploadBytes: _sessionUploadBytes,
          peakDownloadBps: _peakDownloadBps,
          peakUploadBps: _peakUploadBps,
        ),
      );
    }
    setState(() {
      _isMonitoring = false;
      _sessionStartedAt = null;
      _sessionDownloadBytes = 0;
      _sessionUploadBytes = 0;
      _peakDownloadBps = 0;
      _peakUploadBps = 0;
      _latest = null;
      _chartSamples.clear();
      _chartVersion = 0;
      _lastSampleAt = null;
    });
    _log('Monitoring stopped');
  }

  void _resetSessionCounters() {
    setState(() {
      _sessionDownloadBytes = 0;
      _sessionUploadBytes = 0;
      _peakDownloadBps = 0;
      _peakUploadBps = 0;
      _chartSamples.clear();
      _chartVersion = 0;
      _latest = null;
      _eventLog.clear();
      _lastSampleAt = null;
      _sessionStartedAt = _isMonitoring ? DateTime.now() : null;
    });
    _log('Session counters reset');
  }

  void _handleSnapshot(NetworkSpeedSnapshot snapshot) {
    final now = snapshot.timestamp;
    final previous = _lastSampleAt;
    final deltaMs = previous == null
        ? _intervalMs
        : max(now.millisecondsSinceEpoch - previous.millisecondsSinceEpoch, 0);
    final seconds = deltaMs / 1000;
    _lastSampleAt = now;

    final addedDownload = (snapshot.downloadBytesPerSecond * seconds).round();
    final addedUpload = (snapshot.uploadBytesPerSecond * seconds).round();
    _sessionDownloadBytes += addedDownload;
    _sessionUploadBytes += addedUpload;

    final dateKey = DateTime(now.year, now.month, now.day);
    final totals = _dailyUsage.putIfAbsent(dateKey, () => UsageTotals());
    totals.downloadBytes += addedDownload;
    totals.uploadBytes += addedUpload;

    _peakDownloadBps = max(_peakDownloadBps, snapshot.downloadBytesPerSecond);
    _peakUploadBps = max(_peakUploadBps, snapshot.uploadBytesPerSecond);

    _chartSamples.add(
      SpeedSample(
        timestamp: now,
        downloadBps: snapshot.downloadBytesPerSecond,
        uploadBps: snapshot.uploadBytesPerSecond,
      ),
    );
    if (_chartSamples.length > 120) {
      _chartSamples.removeAt(0);
    }

    setState(() {
      _latest = snapshot;
      _chartVersion++;
    });

    _log(
      'D:${snapshot.formattedDownload} '
      'U:${snapshot.formattedUpload} '
      'T:${snapshot.formattedTotal}',
    );
  }

  Widget _buildSpeedCard({
    required String label,
    required String value,
    required Color color,
    String? subtitle,
    bool expanded = false,
  }) {
    final card = Card(
      color: color.withOpacity(0.08),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return expanded ? Expanded(child: card) : card;
  }

  Widget _buildDashboard() {
    final latest = _latest;
    final sessionDuration = _sessionDurationSeconds;
    final avgDownload =
        sessionDuration == 0 ? 0 : _sessionDownloadBytes / sessionDuration;
    final avgUpload =
        sessionDuration == 0 ? 0 : _sessionUploadBytes / sessionDuration;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _buildSpeedCard(
              label: 'Download',
              value: latest?.formattedDownload ?? '--',
              subtitle: 'Peak ${speedFormatter.format(_peakDownloadBps)}',
              color: Colors.blue,
              expanded: true,
            ),
            const SizedBox(width: 12),
            _buildSpeedCard(
              label: 'Upload',
              value: latest?.formattedUpload ?? '--',
              subtitle: 'Peak ${speedFormatter.format(_peakUploadBps)}',
              color: Colors.green,
              expanded: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSpeedCard(
          label: 'Total',
          value: latest?.formattedTotal ?? '--',
          subtitle: 'Average ${speedFormatter.format((avgDownload + avgUpload).round())}',
          color: Colors.orange,
          expanded: false,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live chart (last ~2 minutes)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: SpeedChart(
                    samples: _chartSamples,
                    version: _chartVersion,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Session duration'),
                        subtitle: Text(_formatDuration(
                          Duration(
                            seconds: sessionDuration.round(),
                          ),
                        )),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Session usage'),
                        subtitle: Text(
                          '${_formatBytes(_sessionDownloadBytes)} ↓  ·  '
                          '${_formatBytes(_sessionUploadBytes)} ↑',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Average'),
                        subtitle: Text(
                          'D ${speedFormatter.format(avgDownload.round())} · '
                          'U ${speedFormatter.format(avgUpload.round())}',
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Total data'),
                        subtitle: Text(
                          _formatBytes(_sessionDownloadBytes + _sessionUploadBytes),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isMonitoring ? null : _startMonitoring,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isMonitoring ? _stopMonitoring : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetSessionCounters,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset counters'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Foreground service'),
                        value: _foreground,
                        onChanged: (value) {
                          setState(() => _foreground = value);
                        },
                        subtitle: const Text(
                          'Keeps monitoring in background with notification',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Live log',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _eventLog.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(_eventLog[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsagePage() {
    final today = _todayUsage;
    final combined = today.totalBytes;
    final sessionDuration = _sessionDurationSeconds;
    final avgDown =
        sessionDuration == 0 ? 0 : _sessionDownloadBytes / sessionDuration;
    final avgUp =
        sessionDuration == 0 ? 0 : _sessionUploadBytes / sessionDuration;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _buildSpeedCard(
              label: 'Today',
              value: _formatBytes(combined),
              subtitle: 'Download ${_formatBytes(today.downloadBytes)} · Upload ${_formatBytes(today.uploadBytes)}',
              color: Colors.indigo,
              expanded: true,
            ),
            const SizedBox(width: 12),
            _buildSpeedCard(
              label: 'Current session',
              value: _formatBytes(_sessionDownloadBytes + _sessionUploadBytes),
              subtitle: _formatDuration(Duration(
                seconds: sessionDuration.round(),
              )),
              color: Colors.deepOrange,
              expanded: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                title: const Text('Average throughput'),
                subtitle: Text(
                  'Download ${speedFormatter.format(avgDown.round())} · '
                  'Upload ${speedFormatter.format(avgUp.round())}',
                ),
              ),
              ListTile(
                title: const Text('Peaks observed'),
                subtitle: Text(
                  'Download ${speedFormatter.format(_peakDownloadBps)} · '
                  'Upload ${speedFormatter.format(_peakUploadBps)}',
                ),
              ),
              ListTile(
                title: const Text('Foreground notification'),
                subtitle: Text(
                  _showNotification
                      ? 'Enabled for live speed banner'
                      : 'Disabled (Android 13+ may hide updates)',
                ),
                trailing: Switch(
                  value: _showNotification,
                  onChanged: (value) => setState(() => _showNotification = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status bar & notification preview',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.network_check, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        latestNotificationText(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Toggle the foreground switch to mirror the Play Store app\'s persistent banner.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String latestNotificationText() {
    final latest = _latest;
    if (!_isMonitoring) {
      return 'Waiting to start monitoring';
    }
    if (latest == null) {
      return 'Monitoring... waiting for first sample';
    }
    return 'D ${latest.formattedDownload}  ·  U ${latest.formattedUpload}';
  }

  Widget _buildHistoryPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_history.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Start monitoring to build a session timeline like the Play Store reference app. '
                'Each run is saved with duration, totals, and peaks.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ),
        ..._history.map(
          (session) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                '${_formatDuration(session.duration)}  ·  '
                '${_formatBytes(session.downloadBytes + session.uploadBytes)}',
              ),
              subtitle: Text(
                '${session.startedAt} -> ${session.endedAt}\n'
                'Peak ${speedFormatter.format(session.peakDownloadBps)} down, '
                '${speedFormatter.format(session.peakUploadBps)} up',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Avg D ${speedFormatter.format(session.averageDownloadBps.round())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Avg U ${speedFormatter.format(session.averageUploadBps.round())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Interval (ms)',
            helperText: 'Sampling frequency for monitoring',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          controller: _intervalController,
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed == null || parsed <= 0) return;
            setState(() => _intervalMs = parsed);
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Auto-start on launch'),
          subtitle: const Text('Match reference app behavior of always-on meter'),
          value: _autoStart,
          onChanged: (value) => setState(() => _autoStart = value),
        ),
        SwitchListTile(
          title: const Text('Foreground service'),
          subtitle: const Text('Keeps speeds visible in notification shade'),
          value: _foreground,
          onChanged: (value) => setState(() => _foreground = value),
        ),
        SwitchListTile(
          title: const Text('Show notification'),
          subtitle: const Text('Display live download/upload in status bar'),
          value: _showNotification,
          onChanged: (value) => setState(() => _showNotification = value),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What this demo includes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  '- Live dashboard with chart\n'
                  '- Daily usage counters\n'
                  '- Session history\n'
                  '- Status bar style preview\n'
                  'These mirror the pages and toggles from the Play Store app.',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _resetSessionCounters,
                  child: const Text('Reset all demo data'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Speed Meter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Network Speed Meter'),
        ),
        body: IndexedStack(
          index: _currentTab,
          children: [
            _buildDashboard(),
            _buildUsagePage(),
            _buildHistoryPage(),
            _buildSettingsPage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.blueGrey.shade900,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.blueGrey.shade200,
          showUnselectedLabels: true,
          onTap: (index) => setState(() => _currentTab = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.speed),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart_outlined),
              label: 'Usage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class SpeedChart extends StatelessWidget {
  const SpeedChart({
    super.key,
    required this.samples,
    required this.version,
  });

  final List<SpeedSample> samples;
  final int version;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _SpeedChartPainter(samples, version),
      ),
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  _SpeedChartPainter(this.samples, this.version);

  final List<SpeedSample> samples;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final maxValue = samples
        .map((s) => max(s.downloadBps, s.uploadBps))
        .fold<int>(1, max);

    final pathDownload = Path();
    final pathUpload = Path();
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final dx = size.width * (i / max(samples.length - 1, 1));
      final downloadY =
          size.height - (samples[i].downloadBps / maxValue) * size.height;
      final uploadY =
          size.height - (samples[i].uploadBps / maxValue) * size.height;
      if (i == 0) {
        pathDownload.moveTo(dx, downloadY);
        pathUpload.moveTo(dx, uploadY);
      } else {
        pathDownload.lineTo(dx, downloadY);
        pathUpload.lineTo(dx, uploadY);
      }
    }

    final downloadPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final uploadPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(pathDownload, downloadPaint);
    canvas.drawPath(pathUpload, uploadPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) {
    return oldDelegate.version != version;
  }
}
