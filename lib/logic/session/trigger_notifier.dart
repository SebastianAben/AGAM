/// Notifikasi dan getar saat trigger POI (PB06, UI03).
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../contracts/contracts.dart';

/// Pilihan pengguna pada notifikasi trigger (PRD §9.2 butir 7).
enum TriggerAction { listen, view, skip }

@immutable
class TriggerActionEvent {
  const TriggerActionEvent({required this.poiId, required this.action});

  final String poiId;
  final TriggerAction action;
}

abstract interface class TriggerNotifier {
  /// Explore/Trail: notifikasi prioritas tinggi dengan getar dan tombol
  /// Dengarkan/Lihat/Lewati.
  Future<void> showFull(Poi poi);

  /// Navigasi: notifikasi ringkas tanpa suara dan getar.
  Future<void> showBrief(Poi poi);

  Future<void> dismiss(String poiId);

  /// Menghapus seluruh notifikasi trigger yang masih tampil, mis. saat sesi
  /// berakhir. Notifikasi lain milik aplikasi (sesi aktif, audio) tidak
  /// tersentuh.
  Future<void> dismissAll();

  /// Tombol yang ditekan pengguna, termasuk dari lock screen.
  Stream<TriggerActionEvent> get actions;
}

/// Nama port untuk meneruskan tombol notifikasi dari isolate latar belakang
/// plugin ke isolate utama aplikasi.
const _actionPortName = 'site.agam/trigger-actions';

/// Tombol notifikasi tanpa membuka aplikasi (Dengarkan, Lewati) diproses
/// plugin di isolate terpisah. Handler ini meneruskannya ke isolate utama
/// yang sedang menjalankan sesi. Jika aplikasi tidak berjalan, tombol
/// diabaikan karena tidak ada sesi.
@pragma('vm:entry-point')
void agamNotificationBackgroundHandler(NotificationResponse response) {
  IsolateNameServer.lookupPortByName(_actionPortName)
      ?.send(<String?>[response.actionId, response.payload]);
}

class LocalTriggerNotifier implements TriggerNotifier {
  LocalTriggerNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const fullChannelId = 'site.agam.poi_trigger';
  static const briefChannelId = 'site.agam.poi_brief';
  static const listenActionId = 'listen';
  static const viewActionId = 'view';
  static const skipActionId = 'skip';

  final FlutterLocalNotificationsPlugin _plugin;
  final _actions = StreamController<TriggerActionEvent>.broadcast();
  ReceivePort? _port;

  @override
  Stream<TriggerActionEvent> get actions => _actions.stream;

  /// Inisialisasi plugin. Wajib dipanggil sekali sebelum notifikasi lain.
  Future<void> init() async {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_actionPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _actionPortName);
    _port = port;
    port.listen((message) {
      if (message is List && message.length == 2) {
        _handle(message[0] as String?, message[1] as String?);
      }
    });

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => _handle(r.actionId, r.payload),
      onDidReceiveBackgroundNotificationResponse:
          agamNotificationBackgroundHandler,
    );
  }

  /// ID POI yang notifikasinya mungkin masih tampil.
  final _shown = <String>{};

  @override
  Future<void> showFull(Poi poi) {
    _shown.add(poi.id);
    return _plugin.show(
      id: notificationIdFor(poi.id),
      title: 'Anda mendekati ${poi.name}',
      body: 'Apakah Anda ingin mendengarkan ceritanya?',
      payload: poi.id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          fullChannelId,
          'Gedung di sekitar',
          channelDescription: 'Pemberitahuan saat Anda mendekati gedung.',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.recommendation,
          visibility: NotificationVisibility.public,
          actions: [
            AndroidNotificationAction(listenActionId, 'Dengarkan'),
            AndroidNotificationAction(
              viewActionId,
              'Lihat',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(skipActionId, 'Lewati'),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> showBrief(Poi poi) {
    _shown.add(poi.id);
    return _plugin.show(
      id: notificationIdFor(poi.id),
      title: poi.name,
      body: 'Anda melewati ${poi.name}.',
      payload: poi.id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          briefChannelId,
          'Gedung yang dilewati',
          channelDescription:
              'Pemberitahuan ringkas tanpa suara selama navigasi.',
          importance: Importance.low,
          priority: Priority.low,
          enableVibration: false,
          playSound: false,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  @override
  Future<void> dismiss(String poiId) {
    _shown.remove(poiId);
    return _plugin.cancel(id: notificationIdFor(poiId));
  }

  @override
  Future<void> dismissAll() async {
    final ids = _shown.toList();
    _shown.clear();
    for (final id in ids) {
      await _plugin.cancel(id: notificationIdFor(id));
    }
  }

  Future<void> dispose() async {
    IsolateNameServer.removePortNameMapping(_actionPortName);
    _port?.close();
    await _actions.close();
  }

  void _handle(String? actionId, String? poiId) {
    if (poiId == null || poiId.isEmpty) return;
    final action = actionFor(actionId);
    if (action != null) {
      _actions.add(TriggerActionEvent(poiId: poiId, action: action));
    }
  }

  /// Mengetuk badan notifikasi (tanpa tombol) sama dengan "Lihat".
  @visibleForTesting
  static TriggerAction? actionFor(String? actionId) => switch (actionId) {
    null || '' || viewActionId => TriggerAction.view,
    listenActionId => TriggerAction.listen,
    skipActionId => TriggerAction.skip,
    _ => null,
  };

  /// ID notifikasi stabil per POI: notifikasi baru untuk POI yang sama
  /// menggantikan yang lama.
  @visibleForTesting
  static int notificationIdFor(String poiId) {
    var hash = 17;
    for (final unit in poiId.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return 1000 + hash % 1000000;
  }
}
