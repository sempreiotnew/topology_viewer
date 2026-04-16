import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import '../models/topology_data.dart';
import '../models/data_pulse.dart';
import '../widgets/node_widget.dart';
import '../widgets/grid_painter.dart';
import '../widgets/edge_painter.dart';
import '../widgets/topology_header.dart';
import '../widgets/topology_status_bar.dart';
import '../widgets/topology_footer.dart';
import '../widgets/zoom_button.dart';
import '../widgets/topology_empty_state.dart';

class TopologyScreen extends StatefulWidget {
  const TopologyScreen({super.key});

  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen>
    with TickerProviderStateMixin {
  // Serial
  UsbPort? _port;
  StreamSubscription<UsbEvent>? _usbEventSub;
  StreamSubscription<Uint8List>? _dataSub;
  String _buffer = '';
  bool _connected = false;
  String _statusMsg = 'No device connected';

  // Watchdog — if connected but no data arrives within this window, reconnect
  static const Duration _watchdogTimeout = Duration(seconds: 8);
  Timer? _watchdogTimer;
  DateTime? _lastDataAt;

  // Topology
  TopologyData? _topology;
  int _messageCount = 0;

  // Pulse animations — kept alive until each one finishes
  final List<DataPulse> _pulses = [];
  final List<Timer> _pulseTimers = [];
  // Notifier used to repaint the edge painter without rebuilding the whole tree
  final ValueNotifier<int> _pulseRepaint = ValueNotifier(0);

  // Alarming MACs (persist until app restart)
  final Set<String> _alarmingMacs = {};

  // Node positions — recomputed whenever topology changes
  final Map<String, Offset> _nodePositions = {};

  // Zoom / pan
  final TransformationController _transformCtrl = TransformationController();
  static const double _minScale = 0.15;
  static const double _maxScale = 4.0;
  // Large fixed canvas so all nodes have room regardless of depth
  static const double _canvasW = 1600.0;
  static const double _canvasH = 700.0;

  // Fit-on-first-load
  BoxConstraints? _lastConstraints;
  bool _pendingFit = false;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initUsb();
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _usbEventSub?.cancel();
    _dataSub?.cancel();
    _port?.close();
    _transformCtrl.dispose();
    for (final t in _pulseTimers) t.cancel();
    _pulseTimers.clear();
    for (final p in _pulses) p.controller.dispose();
    _pulseRepaint.dispose();
    super.dispose();
  }

  // ── USB / Serial ────────────────────────────────────────────────────────────

  Future<void> _initUsb() async {
    _usbEventSub = UsbSerial.usbEventStream?.listen(_onUsbEvent);
    await _scanDevices();
  }

  void _onUsbEvent(UsbEvent event) {
    debugPrint('USB event: ${event.event}');
    if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
      _closePort(); // ensure clean slate before reconnecting
      if (!mounted) return;
      setState(() => _statusMsg = 'Device attached — connecting…');
      _scanDevices();
    } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
      _closePort();
      if (!mounted) return;
      setState(() {
        _connected = false;
        _statusMsg = 'Device disconnected';
      });
    }
  }

  Future<void> _scanDevices() async {
    final devices = await UsbSerial.listDevices();
    if (devices.isNotEmpty) {
      await _connectDevice(devices.first);
    }
  }

  Future<void> _connectDevice(UsbDevice device) async {
    try {
      final port = await device.create();
      if (port == null) {
        if (!mounted) return;
        setState(() => _statusMsg = 'Failed to create port');
        return;
      }

      // Assign early so _closePort() can clean it up if DETACHED fires mid-await
      _port = port;

      final opened = await port.open();
      if (!opened) {
        if (!mounted) return;
        _closePort();
        setState(() => _statusMsg = 'Failed to open port');
        return;
      }
      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // If port was closed by a DETACHED event during the awaits above, bail out
      if (_port == null || !mounted) return;

      _dataSub = port.inputStream?.listen(
        _onData,
        onError: _onSerialError,
        onDone: _onSerialDone,
      );

      _startWatchdog();

      setState(() {
        _connected = true;
        _statusMsg =
            'Connected: ${device.productName ?? device.deviceName ?? "Unknown"}';
      });
    } catch (e) {
      if (!mounted) return;
      _closePort();
      setState(() => _statusMsg = 'Error: $e');
    }
  }

  void _closePort() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _dataSub?.cancel();
    _dataSub = null;
    _port?.close();
    _port = null;
    _buffer = '';
  }

  // ── Watchdog ────────────────────────────────────────────────────────────────

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastDataAt = DateTime.now();
    _watchdogTimer = Timer.periodic(_watchdogTimeout, (_) {
      if (!mounted) return;
      final last = _lastDataAt;
      if (last == null) return;
      if (DateTime.now().difference(last) >= _watchdogTimeout) {
        debugPrint('Watchdog: no data for ${_watchdogTimeout.inSeconds}s — reconnecting');
        _closePort();
        if (!mounted) return;
        setState(() {
          _connected = false;
          _statusMsg = 'No data — reconnecting…';
        });
        _scanDevices();
      }
    });
  }

  // ── Serial data parsing ─────────────────────────────────────────────────────

  void _onData(Uint8List data) {
    _lastDataAt = DateTime.now(); // reset watchdog on every incoming byte
    _buffer += utf8.decode(data, allowMalformed: true);
    _extractJsonObjects();
  }

  // Scan the buffer for complete JSON objects by tracking brace depth.
  // This handles multiple objects on the same line (no newline between them).
  void _extractJsonObjects() {
    while (true) {
      final start = _buffer.indexOf('{');
      if (start == -1) { _buffer = ''; break; }

      int depth = 0;
      int? end;
      bool inString = false;
      bool escaped = false;

      for (int i = start; i < _buffer.length; i++) {
        final ch = _buffer[i];
        if (escaped) { escaped = false; continue; }
        if (inString) {
          if (ch == '\\') escaped = true;
          else if (ch == '"') inString = false;
          continue;
        }
        if (ch == '"') { inString = true; }
        else if (ch == '{') { depth++; }
        else if (ch == '}') {
          depth--;
          if (depth == 0) { end = i; break; }
        }
      }

      if (end == null) {
        // Incomplete object — keep from the `{` onward and wait for more data
        if (start > 0) _buffer = _buffer.substring(start);
        break;
      }

      final json = _buffer.substring(start, end + 1);
      _buffer = _buffer.substring(end + 1);
      _tryParseLine(json);
    }
  }

  void _onSerialError(Object error) {
    debugPrint('Serial error: $error');
    _closePort();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _statusMsg = 'Serial error — reconnecting…';
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_connected) _scanDevices();
    });
  }

  void _onSerialDone() {
    debugPrint('Serial stream closed');
    _closePort();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _statusMsg = 'Stream closed — reconnecting…';
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_connected) _scanDevices();
    });
  }

  void _tryParseLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return;
      // Handle ALARM messages
      if (decoded['type'] == 'ALARM') {
        final mac = (decoded['mac'] as String?)?.toLowerCase();
        final isAlarm = decoded['is_alarm'] == true;
        if (mac != null && mounted) {
          setState(() => isAlarm ? _alarmingMacs.add(mac) : _alarmingMacs.remove(mac));
        }
        return;
      }
      if (!decoded.containsKey('root') || !decoded.containsKey('nodes')) return;
      final topo = TopologyData.fromJson(decoded);
      if (!mounted) return;
      final isFirst = _topology == null;
      setState(() {
        _topology = topo;
        _messageCount++;
        _nodePositions.clear();
        if (isFirst) _pendingFit = true;
      });
      _triggerPulseAnimation(topo);
    } catch (e, st) {
      debugPrint('_tryParseLine error: $e\n$st');
    }
  }

  // ── Pulse animations ────────────────────────────────────────────────────────

  void _triggerPulseAnimation(TopologyData topo) {
    // Cancel any pending start timers before touching controllers
    for (final t in _pulseTimers) t.cancel();
    _pulseTimers.clear();

    // Dispose controllers that are currently running
    for (final p in _pulses) p.controller.dispose();
    _pulses.clear();

    final sorted = [...topo.nodes.where((n) => !n.missing)]
      ..sort((a, b) => b.layer.compareTo(a.layer));

    for (int i = 0; i < sorted.length; i++) {
      final node = sorted[i];
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      final progress = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
      final pulse = DataPulse(
        fromMac: node.mac,
        toMac: node.parent,
        controller: ctrl,
        progress: progress,
      );
      _pulses.add(pulse);

      // Notify only the EdgePainter to repaint — no full widget-tree rebuild
      ctrl.addListener(() => _pulseRepaint.value++);

      _pulseTimers.add(Timer(Duration(milliseconds: i * 120), () {
        // If this pulse was cancelled by a newer topology, skip it
        if (!mounted || !_pulses.contains(pulse)) return;
        ctrl.forward().then((_) {
          if (!mounted) return;
          _pulses.remove(pulse);
          ctrl.dispose();
          // Let the painter know the pulse is gone
          if (mounted) _pulseRepaint.value++;
        });
      }));
    }
  }

  // ── Demo data ───────────────────────────────────────────────────────────────

  void _loadDemoData() {
    const demo =
        '{"seq":333,"root":"d4:e9:f4:f2:68:04","delivered":true,"acked":7,'
        '"total":7,"retries":19,"nodes":['
        '{"mac":"e0:5a:1b:50:22:68","layer":3,"parent":"d4:e9:f4:bc:a2:c8","rssi":-71,"acked":true,"missing":false},'
        '{"mac":"b4:e6:2d:96:a2:85","layer":3,"parent":"d4:e9:f4:bc:a2:c8","rssi":-75,"acked":true,"missing":false},'
        '{"mac":"40:22:d8:7b:84:80","layer":4,"parent":"b4:e6:2d:96:a2:85","rssi":-85,"acked":true,"missing":false},'
        '{"mac":"40:22:d8:7b:98:04","layer":4,"parent":"e0:5a:1b:50:22:68","rssi":-67,"acked":true,"missing":false},'
        '{"mac":"00:4b:12:2d:f7:8c","layer":3,"parent":"d4:e9:f4:bc:a2:c8","rssi":-51,"acked":true,"missing":false},'
        '{"mac":"38:18:2b:8c:13:d0","layer":4,"parent":"e0:5a:1b:50:22:68","rssi":-58,"acked":true,"missing":false},'
        '{"mac":"d4:e9:f4:bc:a2:c8","layer":2,"parent":"d4:e9:f4:f2:68:04","rssi":-68,"acked":true,"missing":false}'
        ']}';
    _tryParseLine(demo);
  }

  // ── Tree layout ─────────────────────────────────────────────────────────────

  void _computePositions(TopologyData topo) {
    if (_nodePositions.isNotEmpty) return;

    // Build parent→children map
    final Map<String, List<String>> children = {topo.root: []};
    for (final node in topo.nodes) {
      children[node.mac] = [];
    }
    for (final node in topo.nodes) {
      final list = children[node.parent];
      if (list != null) {
        list.add(node.mac);
      } else {
        children[node.parent] = [node.mac];
      }
    }

    // Count leaf nodes under every mac
    final Map<String, int> leafCount = {};
    _countLeaves(topo.root, children, leafCount);

    final int totalLeaves = leafCount[topo.root] ?? 1;
    final int maxLayer = topo.nodes.isEmpty
        ? 1
        : topo.nodes.map((n) => n.layer).reduce(max);

    const double hPad = 50.0;
    const double topPad = 80.0;
    final double usableW = _canvasW - hPad * 2;
    // Compact vertical spacing per layer
    const double layerH = 110.0;

    _assignPositions(
      mac: topo.root,
      xStart: 0,
      xEnd: usableW,
      layer: 1,
      children: children,
      leafCount: leafCount,
      totalLeaves: totalLeaves,
      usableW: usableW,
      hPad: hPad,
      topPad: topPad,
      layerH: layerH,
    );
  }

  int _countLeaves(
    String mac,
    Map<String, List<String>> children,
    Map<String, int> leafCount,
  ) {
    final ch = children[mac] ?? [];
    if (ch.isEmpty) {
      leafCount[mac] = 1;
      return 1;
    }
    int total = 0;
    for (final c in ch) {
      total += _countLeaves(c, children, leafCount);
    }
    leafCount[mac] = total;
    return total;
  }

  void _assignPositions({
    required String mac,
    required double xStart,
    required double xEnd,
    required int layer,
    required Map<String, List<String>> children,
    required Map<String, int> leafCount,
    required int totalLeaves,
    required double usableW,
    required double hPad,
    required double topPad,
    required double layerH,
  }) {
    final double cx = (xStart + xEnd) / 2 + hPad;
    final double cy = topPad + (layer - 1) * layerH + layerH * 0.35;
    _nodePositions[mac] = Offset(cx, cy);

    final ch = children[mac] ?? [];
    if (ch.isEmpty) return;

    double cursor = xStart;
    for (final child in ch) {
      final int slots = leafCount[child] ?? 1;
      final double fraction = slots / totalLeaves;
      final double childEnd = cursor + fraction * usableW;
      _assignPositions(
        mac: child,
        xStart: cursor,
        xEnd: childEnd,
        layer: layer + 1,
        children: children,
        leafCount: leafCount,
        totalLeaves: totalLeaves,
        usableW: usableW,
        hPad: hPad,
        topPad: topPad,
        layerH: layerH,
      );
      cursor = childEnd;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Column(
        children: [
          TopologyHeader(
            messageCount: _messageCount,
            onLoadDemo: _loadDemoData,
          ),
          TopologyStatusBar(
            connected: _connected,
            statusMsg: _statusMsg,
            topology: _topology,
          ),
          Expanded(child: _buildTopologyView()),
          const TopologyFooter(),
        ],
      ),
    );
  }

  // ── Zoom helpers ────────────────────────────────────────────────────────────

  void _fitToScreen(BoxConstraints constraints) {
    double minX, minY, maxX, maxY;
    if (_nodePositions.isEmpty) {
      minX = 0; minY = 0; maxX = _canvasW; maxY = _canvasH;
    } else {
      minX = _nodePositions.values.map((p) => p.dx).reduce(min) - 70;
      minY = _nodePositions.values.map((p) => p.dy).reduce(min) - 70;
      maxX = _nodePositions.values.map((p) => p.dx).reduce(max) + 70;
      maxY = _nodePositions.values.map((p) => p.dy).reduce(max) + 70;
    }
    final double contentW = maxX - minX;
    final double contentH = maxY - minY;
    final double scale = (min(
      constraints.maxWidth / contentW,
      constraints.maxHeight / contentH,
    ) * 0.88).clamp(_minScale, _maxScale);
    final double tx = constraints.maxWidth / 2 - (minX + contentW / 2) * scale;
    final double ty = constraints.maxHeight / 2 - (minY + contentH / 2) * scale;
    _transformCtrl.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _zoom(double factor) {
    final Matrix4 current = _transformCtrl.value.clone();
    final double currentScale = current.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final double ratio = newScale / currentScale;
    current.scale(ratio);
    _transformCtrl.value = current;
  }

  // ── Topology canvas ─────────────────────────────────────────────────────────

  Widget _buildTopologyView() {
    if (_topology == null) return TopologyEmptyState(connected: _connected);

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastConstraints = constraints;
        _computePositions(_topology!);

        if (_pendingFit && _nodePositions.isNotEmpty) {
          _pendingFit = false;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (mounted) _fitToScreen(constraints); },
          );
        }

        return Stack(
          children: [
            // ── Pannable / zoomable canvas ───────────────────────────────────
            InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: _minScale,
              maxScale: _maxScale,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(200),
              child: SizedBox(
                width: _canvasW,
                height: _canvasH,
                child: Stack(
                  children: [
                    // Grid
                    CustomPaint(
                      painter: GridPainter(),
                      size: const Size(_canvasW, _canvasH),
                    ),
                    // Edges + pulse dots
                    CustomPaint(
                      painter: EdgePainter(
                        topology: _topology!,
                        nodePositions: _nodePositions,
                        pulses: _pulses,
                        repaint: _pulseRepaint,
                      ),
                      size: const Size(_canvasW, _canvasH),
                    ),
                    // Node widgets
                    ..._buildNodeWidgets(),
                  ],
                ),
              ),
            ),

            // ── Zoom control buttons (bottom-right) ──────────────────────────
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZoomButton(
                    icon: Icons.add,
                    onTap: () => _zoom(1.25),
                    tooltip: 'Zoom in',
                  ),
                  const SizedBox(height: 6),
                  ZoomButton(
                    icon: Icons.remove,
                    onTap: () => _zoom(0.8),
                    tooltip: 'Zoom out',
                  ),
                  const SizedBox(height: 6),
                  ZoomButton(
                    icon: Icons.fit_screen_rounded,
                    onTap: () => _fitToScreen(constraints),
                    tooltip: 'Fit all',
                  ),
                ],
              ),
            ),

            // ── Hint label ───────────────────────────────────────────────────
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(
                'Pinch or scroll to zoom  •  Drag to pan',
                style: TextStyle(
                  color: Colors.white.withAlpha(40),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildNodeWidgets() {
    final topo = _topology;
    if (topo == null) return [];
    final widgets = <Widget>[];

    final rootPos = _nodePositions[topo.root];
    if (rootPos != null) {
      widgets.add(_positionedNode(
        offset: rootPos,
        mac: topo.root,
        isRoot: true,
        layer: 1,
        rssi: null,
        acked: true,
        missing: false,
        isAlarming: _alarmingMacs.contains(topo.root),
      ));
    }

    for (final node in topo.nodes) {
      final pos = _nodePositions[node.mac];
      if (pos != null) {
        widgets.add(_positionedNode(
          offset: pos,
          mac: node.mac,
          isRoot: false,
          layer: node.layer,
          rssi: node.rssi,
          acked: node.acked,
          missing: node.missing,
          isAlarming: _alarmingMacs.contains(node.mac),
        ));
      }
    }

    return widgets;
  }

  Widget _positionedNode({
    required Offset offset,
    required String mac,
    required bool isRoot,
    required int layer,
    required int? rssi,
    required bool acked,
    required bool missing,
    required bool isAlarming,
  }) {
    return Positioned(
      left: offset.dx - 40,
      top: offset.dy - 40,
      child: NodeWidget(
        mac: mac,
        isRoot: isRoot,
        layer: layer,
        rssi: rssi,
        acked: acked,
        missing: missing,
        isAlarming: isAlarming,
      ),
    );
  }
}
