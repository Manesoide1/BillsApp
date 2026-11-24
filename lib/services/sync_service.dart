import 'dart:async';
import 'dart:convert';

import 'package:bills_app/services/geolocation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Database? _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final StreamController<int> _syncCompletedController =
      StreamController<int>.broadcast();
  bool _isSyncing = false;

  /// Stream emitido sempre que uma sincronização automática envia itens ao Firebase.
  Stream<int> get onSyncCompleted => _syncCompletedController.stream;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finance_offline.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            action TEXT NOT NULL,
            bill_id TEXT,
            payload TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// Verifica se há algum tipo de conexão ativa.
  Future<bool> hasConnection() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Garante que o listener global de conectividade esteja ativo (sem duplicar).
  void ensureAutoSyncStarted() {
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        final syncedCount = await syncPendingBills();
        if (syncedCount > 0 && !_syncCompletedController.isClosed) {
          _syncCompletedController.add(syncedCount);
        }
      }
    });
  }

  /// Salva ou atualiza uma conta: tenta online; se sem internet, grava no sqflite.
  Future<({bool savedOffline, String message})> saveOrUpdateBill({
    String? billId,
    required String name,
    required String description,
    required double value,
    required DateTime dueDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final isEditing = billId != null;
    final online = await hasConnection();
    final Position? position = await LocationService.getCurrentPositionSafe();

    final double? lat = position?.latitude;
    final double? lng = position?.longitude;

    if (online) {
      final billsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bills');

      final GeoPoint? geoPoint = (lat != null && lng != null)
          ? GeoPoint(lat, lng)
          : null;

      if (isEditing) {
        await billsCollection.doc(billId).update({
          'name': name,
          'description': description.isEmpty ? null : description,
          'value': value,
          'dueDate': Timestamp.fromDate(dueDate),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedLocation': geoPoint,
        });
        return (savedOffline: false, message: 'Conta atualizada com sucesso!');
      } else {
        await billsCollection.add({
          'name': name,
          'description': description.isEmpty ? null : description,
          'value': value,
          'dueDate': Timestamp.fromDate(dueDate),
          'isPaid': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdLocation': geoPoint,
          'updatedAt': null,
          'updatedLocation': null,
        });
        return (savedOffline: false, message: 'Conta salva com sucesso!');
      }
    }

    // Sem internet: salva na fila local do sqflite
    final db = await _database;
    final payload = jsonEncode({
      'name': name,
      'description': description.isEmpty ? null : description,
      'value': value,
      'dueDateMs': dueDate.millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
      'recordedAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    if (isEditing) {
      final existing = await db.query(
        'pending_bills',
        where: 'user_id = ? AND action = ? AND bill_id = ?',
        whereArgs: [user.uid, 'update', billId],
      );

      if (existing.isNotEmpty) {
        await db.update(
          'pending_bills',
          {
            'payload': payload,
            'created_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await db.insert('pending_bills', {
          'user_id': user.uid,
          'action': 'update',
          'bill_id': billId,
          'payload': payload,
          'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } else {
      await db.insert('pending_bills', {
        'user_id': user.uid,
        'action': 'create',
        'bill_id': null,
        'payload': payload,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return (
      savedOffline: true,
      message: isEditing
          ? 'Sem internet: alteração salva localmente e será enviada quando a conexão voltar.'
          : 'Sem internet: conta salva localmente e será enviada quando a conexão voltar.',
    );
  }

  /// Retorna tanto contas criadas offline quanto edições pendentes por billId.
  Future<
    ({
      List<Map<String, dynamic>> creates,
      Map<String, Map<String, dynamic>> updatesByBillId,
    })
  >
  getPendingChanges(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'pending_bills',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );

    final List<Map<String, dynamic>> creates = [];
    final Map<String, Map<String, dynamic>> updatesByBillId = {};

    for (final row in rows) {
      final String action = row['action'] as String;
      final String? billId = row['bill_id'] as String?;
      final data = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      if (action == 'create') {
        creates.add(<String, dynamic>{
          'localId': row['id'],
          'name': data['name'] ?? '',
          'description': data['description'],
          'value': (data['value'] ?? 0).toDouble(),
          'dueDate': DateTime.fromMillisecondsSinceEpoch(
            data['dueDateMs'] as int,
          ),
          'isPaid': false,
          'isOfflinePending': true,
          'hasPendingUpdate': false,
        });
      } else if (action == 'update' && billId != null) {
        updatesByBillId[billId] = <String, dynamic>{
          'name': data['name'] ?? '',
          'description': data['description'],
          'value': (data['value'] ?? 0).toDouble(),
          'dueDate': DateTime.fromMillisecondsSinceEpoch(
            data['dueDateMs'] as int,
          ),
        };
      }
    }

    return (creates: creates, updatesByBillId: updatesByBillId);
  }

  /// Envia todas as alterações pendentes para o Firestore e apaga do banco local.
  Future<int> syncPendingBills() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;

    try {
      final online = await hasConnection();
      if (!online) return 0;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final db = await _database;
      final rows = await db.query(
        'pending_bills',
        where: 'user_id = ?',
        whereArgs: [user.uid],
        orderBy: 'id ASC',
      );

      if (rows.isEmpty) return 0;

      final billsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bills');

      for (final row in rows) {
        final int localId = row['id'] as int;
        final String action = row['action'] as String;
        final String? billId = row['bill_id'] as String?;
        final Map<String, dynamic> data =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        final double? lat = (data['lat'] as num?)?.toDouble();
        final double? lng = (data['lng'] as num?)?.toDouble();
        final GeoPoint? geoPoint = (lat != null && lng != null)
            ? GeoPoint(lat, lng)
            : null;
        final DateTime dueDate = DateTime.fromMillisecondsSinceEpoch(
          data['dueDateMs'] as int,
        );

        if (action == 'create') {
          await billsCollection.add({
            'name': data['name'],
            'description': data['description'],
            'value': (data['value'] as num).toDouble(),
            'dueDate': Timestamp.fromDate(dueDate),
            'isPaid': false,
            'createdAt': FieldValue.serverTimestamp(),
            'createdLocation': geoPoint,
            'updatedAt': null,
            'updatedLocation': null,
          });
        } else if (action == 'update' && billId != null) {
          try {
            await billsCollection.doc(billId).update({
              'name': data['name'],
              'description': data['description'],
              'value': (data['value'] as num).toDouble(),
              'dueDate': Timestamp.fromDate(dueDate),
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedLocation': geoPoint,
            });
          } on FirebaseException catch (e) {
            // Se o documento não existe mais no servidor, descarta a fila órfã
            if (e.code != 'not-found') rethrow;
          }
        }

        await db.delete('pending_bills', where: 'id = ?', whereArgs: [localId]);
        syncedCount++;
      }
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}
