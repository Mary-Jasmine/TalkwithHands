import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as mp_hand;

/// Runs hand_landmarker's synchronous `detect()` on a persistent background
/// isolate so the UI isolate never blocks (the cause of the lag).
///
/// Differences from the first version:
///  * The plugin is created BEFORE the isolate says "ready"; if that fails
///    (e.g. no GPU/JNI in the isolate) [start] throws, and the screen falls
///    back to detecting on the main isolate.
///  * Only plain doubles cross the isolate boundary (flat x,y,z per hand),
///    never plugin objects.
///  * Every detect() has a timeout, and an isolate crash completes pending
///    calls with an error — so the screen can never wait forever.
class HandLandmarkWorker {
  final ReceivePort _receivePort = ReceivePort();
  final ReceivePort _errorPort = ReceivePort();
  final ReceivePort _exitPort = ReceivePort();
  StreamSubscription? _subscription;
  StreamSubscription? _errorSub;
  StreamSubscription? _exitSub;
  Isolate? _isolate;
  SendPort? _commandPort;
  Completer<void>? _readyCompleter;
  final Map<int, Completer<List<Float64List>>> _pending = {};
  int _nextId = 0;
  bool _busy = false;
  bool _dead = false;

  bool get isReady => _commandPort != null && !_dead;
  bool get isBusy => _busy;

  Future<void> start({
    required int numHands,
    required double minHandDetectionConfidence,
    required mp_hand.HandLandmarkerDelegate delegate,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final ready = Completer<void>();
    _readyCompleter = ready;

    _subscription = _receivePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!ready.isCompleted) ready.complete();
      } else if (message is _InitError) {
        if (!ready.isCompleted) ready.completeError(message.message);
      } else if (message is _DetectResponse) {
        final completer = _pending.remove(message.id);
        _busy = false;
        if (completer == null) return;
        if (message.error != null) {
          completer.completeError(message.error!);
        } else {
          completer.complete(message.hands);
        }
      }
    });
    _errorSub = _errorPort.listen((e) => _fail('isolate error: $e'));
    _exitSub = _exitPort.listen((_) => _fail('isolate exited'));

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _InitMessage(
        _receivePort.sendPort,
        numHands,
        minHandDetectionConfidence,
        delegate,
      ),
      onError: _errorPort.sendPort,
      onExit: _exitPort.sendPort,
    );

    try {
      await ready.future.timeout(timeout);
    } catch (e) {
      dispose();
      rethrow;
    }
  }

  void _fail(String reason) {
    if (_dead) return;
    _dead = true;
    debugPrint('HandLandmarkWorker: $reason');
    final readyCompleter = _readyCompleter;
    if (readyCompleter != null && !readyCompleter.isCompleted) {
      readyCompleter.completeError(reason);
    }
    _busy = false;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(reason);
    }
    _pending.clear();
  }

  /// Each hand = flat [x0,y0,z0, x1,y1,z1, ...] (21 landmarks → 63 values).
  /// Returns an empty list if busy (skip the frame). Throws if the worker
  /// is dead or the frame takes longer than [timeout].
  Future<List<Float64List>> detect(
    CameraImage image,
    int sensorOrientation, {
    Duration timeout = const Duration(seconds: 2),
  }) {
    if (_dead) return Future.error(StateError('hand worker is dead'));
    final commandPort = _commandPort;
    if (commandPort == null || _busy) {
      return Future.value(const <Float64List>[]);
    }
    final id = _nextId++;
    final completer = Completer<List<Float64List>>();
    _pending[id] = completer;
    _busy = true;
    try {
      commandPort.send(_DetectRequest(id, image, sensorOrientation));
    } catch (e) {
      _pending.remove(id);
      _busy = false;
      return Future.error(e);
    }
    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      _busy = false;
      throw TimeoutException('hand detect timed out', timeout);
    });
  }

  void dispose() {
    _dead = true;
    _subscription?.cancel();
    _errorSub?.cancel();
    _exitSub?.cancel();
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(const <Float64List>[]);
    }
    _pending.clear();
  }

  static void _isolateEntry(_InitMessage init) {
    final commandPort = ReceivePort();
    final mp_hand.HandLandmarkerPlugin plugin;
    try {
      plugin = mp_hand.HandLandmarkerPlugin.create(
        numHands: init.numHands,
        minHandDetectionConfidence: init.minHandDetectionConfidence,
        delegate: init.delegate,
      );
    } catch (e) {
      init.mainSendPort.send(_InitError('plugin create failed: $e'));
      return;
    }
    init.mainSendPort.send(commandPort.sendPort);

    commandPort.listen((message) {
      if (message is _DetectRequest) {
        try {
          final hands =
              plugin.detect(message.image, message.sensorOrientation);
          final out = <Float64List>[];
          for (final hand in hands) {
            final lms = hand.landmarks;
            final flat = Float64List(lms.length * 3);
            for (var i = 0; i < lms.length; i++) {
              flat[i * 3] = lms[i].x;
              flat[i * 3 + 1] = lms[i].y;
              flat[i * 3 + 2] = lms[i].z;
            }
            out.add(flat);
          }
          init.mainSendPort.send(_DetectResponse(message.id, out));
        } catch (e) {
          init.mainSendPort
              .send(_DetectResponse(message.id, const <Float64List>[], '$e'));
        }
      }
    });
  }
}

class _InitMessage {
  final SendPort mainSendPort;
  final int numHands;
  final double minHandDetectionConfidence;
  final mp_hand.HandLandmarkerDelegate delegate;
  _InitMessage(
    this.mainSendPort,
    this.numHands,
    this.minHandDetectionConfidence,
    this.delegate,
  );
}

class _InitError {
  final String message;
  _InitError(this.message);
}

class _DetectRequest {
  final int id;
  final CameraImage image;
  final int sensorOrientation;
  _DetectRequest(this.id, this.image, this.sensorOrientation);
}

class _DetectResponse {
  final int id;
  final List<Float64List> hands;
  final String? error;
  _DetectResponse(this.id, this.hands, [this.error]);
}