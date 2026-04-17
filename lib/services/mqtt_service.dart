import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static const String _host =
      'a2jyn1r3dl73o8-ats.iot.us-east-1.amazonaws.com';
  static const int _port = 8883;
  static const String _clientId = '69e00354868c951534c347a6';
  static const String _topic = 'user/69dfd12afec9271b27e01630/#';
  static const Duration _reconnectDelay = Duration(seconds: 5);

  MqttServerClient? _client;
  StreamSubscription? _updatesSub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final _messageController = StreamController<String>.broadcast();

  Stream<String> get messages => _messageController.stream;
  final ValueNotifier<bool> connected = ValueNotifier(false);

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    debugPrint('[MQTT] ── connect() ──────────────────────────────────');
    debugPrint('[MQTT] host     : $_host:$_port');
    debugPrint('[MQTT] clientId : $_clientId');
    debugPrint('[MQTT] topic    : $_topic');

    try {
      // ── Load certs ─────────────────────────────────────────────────────────
      debugPrint('[MQTT] loading certs from assets…');
      final caBytes =
          (await rootBundle.load('certs/AmazonRootCa1.pem')).buffer.asUint8List();
      final certBytes =
          (await rootBundle.load('certs/device.cert.pem')).buffer.asUint8List();
      final keyBytes =
          (await rootBundle.load('certs/device.private.key')).buffer.asUint8List();
      debugPrint('[MQTT] certs loaded — CA:${caBytes.length}B  cert:${certBytes.length}B  key:${keyBytes.length}B');

      final ctx = SecurityContext(withTrustedRoots: false);
      ctx.setTrustedCertificatesBytes(caBytes);
      ctx.useCertificateChainBytes(certBytes);
      ctx.usePrivateKeyBytes(keyBytes);
      debugPrint('[MQTT] SecurityContext built');

      // ── Build client ────────────────────────────────────────────────────────
      _client = MqttServerClient.withPort(_host, _clientId, _port);
      _client!.secure = true;
      _client!.securityContext = ctx;
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = false;
      _client!.logging(on: true); // let mqtt_client print its own protocol logs

      // Register callbacks BEFORE connect() so they fire reliably
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = (topic) =>
          debugPrint('[MQTT] ✓ subscribed: $topic');
      _client!.onSubscribeFail = (topic) =>
          debugPrint('[MQTT] ✗ subscribe FAILED: $topic');
      _client!.onUnsubscribed = (topic) =>
          debugPrint('[MQTT] unsubscribed: $topic');
      _client!.pongCallback = () => debugPrint('[MQTT] pong received');

      _client!.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean();

      // ── Connect ─────────────────────────────────────────────────────────────
      debugPrint('[MQTT] calling client.connect()…');
      final status = await _client!.connect();
      debugPrint('[MQTT] connect() returned — state:${status?.state}  returnCode:${status?.returnCode}');

      // The onConnected callback handles everything from here.
      // If the state is NOT connected, log it and schedule retry.
      if (status?.state != MqttConnectionState.connected) {
        debugPrint('[MQTT] ✗ not connected after connect() — returnCode:${status?.returnCode}');
        connected.value = false;
        _scheduleReconnect();
      }
    } catch (e, st) {
      debugPrint('[MQTT] ✗ exception in connect(): $e');
      debugPrint('[MQTT] stacktrace: $st');
      connected.value = false;
      _scheduleReconnect();
    }
  }

  void disconnect() {
    debugPrint('[MQTT] disconnect() called');
    _disposed = true;
    _reconnectTimer?.cancel();
    _updatesSub?.cancel();
    _client?.disconnect();
    _messageController.close();
    connected.dispose();
  }

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void _onConnected() {
    debugPrint('[MQTT] ✓ onConnected callback fired');
    connected.value = true;

    debugPrint('[MQTT] subscribing to "$_topic" QoS=1…');
    _client!.subscribe(_topic, MqttQos.atLeastOnce);

    _updatesSub?.cancel();
    _updatesSub = _client!.updates?.listen(
      _onMessages,
      onError: (e) => debugPrint('[MQTT] updates stream error: $e'),
      onDone: () => debugPrint('[MQTT] updates stream closed'),
    );
    debugPrint('[MQTT] updates stream listener attached');
  }

  void _onDisconnected() {
    debugPrint('[MQTT] onDisconnected callback fired — state:${_client?.connectionStatus?.state}');
    connected.value = false;
    if (!_disposed) _scheduleReconnect();
  }

  void _onMessages(List<MqttReceivedMessage<MqttMessage?>> messages) {
    debugPrint('[MQTT] _onMessages fired — ${messages.length} message(s)');
    for (final msg in messages) {
      final publish = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message,
      );
      debugPrint('[MQTT] ← topic:"${msg.topic}" payload(${payload.length}B): '
          '${payload.length > 120 ? '${payload.substring(0, 120)}…' : payload}');
      if (!_messageController.isClosed) {
        _messageController.add(payload);
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    debugPrint('[MQTT] scheduling reconnect in ${_reconnectDelay.inSeconds}s…');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_disposed && !connected.value) connect();
    });
  }
}
