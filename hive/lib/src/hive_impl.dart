import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/backend/storage_backend_memory.dart';
import 'package:hive_ce/src/box/box_base_impl.dart';
import 'package:hive_ce/src/box/box_impl.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/box/lazy_box_impl.dart';
import 'package:hive_ce/src/connect/hive_connect.dart';
import 'package:hive_ce/src/isolate/isolate_debug_name/isolate_debug_name.dart';
import 'package:hive_ce/src/isolate/isolated_hive_impl/hive_isolate_name.dart';
import 'package:hive_ce/src/registry/type_registry_impl.dart';
import 'package:hive_ce/src/util/extensions.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:hive_ce/src/util/type_utils.dart';
import 'package:meta/meta.dart';

import 'package:hive_ce/src/backend/storage_backend.dart';

/// Not part of public API
class HiveImpl extends TypeRegistryImpl implements HiveInterface {
  static final BackendManagerInterface _defaultBackendManager =
      BackendManager.select();

  final _boxes = HashMap<String, BoxBaseImpl>();
  final _openingBoxes = HashMap<String, Future>();
  BackendManagerInterface? _managerOverride;
  final _secureRandom = Random.secure();

  /// Whether this Hive instance is isolated
  var _isolated = false;

  /// Set [_isolated] to true
  void setIsolated() => _isolated = true;

  /// Not part of public API
  @visibleForTesting
  String? homePath;

  /// either returns the preferred [BackendManagerInterface] or the
  /// platform default fallback
  BackendManagerInterface get _manager =>
      _managerOverride ?? _defaultBackendManager;

  @override
  void init(
    String? path, {
    HiveStorageBackendPreference backendPreference =
        HiveStorageBackendPreference.native,
  }) {
    if (Logger.unsafeIsolateWarning &&
        !{'main', hiveIsolateName}.contains(isolateDebugName) &&
        // Do not print this warning if this code is running in a test
        !isolateDebugName.startsWith('test_suite')) {
      Logger.w(HiveWarning.unsafeIsolate);
    }
    homePath = path;
    _managerOverride = BackendManager.select(backendPreference);
  }

  /// Generate a unique box key from name and extension
  String _boxKey(String name, {String? extension}) {
    final lowerName = name.toLowerCase();
    if (extension != null) {
      return '$lowerName|e:$extension';
    }
    return lowerName;
  }

  Future<BoxBase<E>> _openBox<E>(
    String name,
    bool lazy,
    HiveCipher? cipher,
    int? keyCrc,
    KeyComparator comparator,
    CompactionStrategy compaction,
    bool recovery,
    String? path,
    Uint8List? bytes,
    String? collection,
    String? extension,
  ) async {
    assert(path == null || bytes == null);
    assert(
      name.length <= 255 && name.isAscii,
      'Box names need to be ASCII Strings with a max length of 255.',
    );
    typedMapOrIterableCheck<E>();

    name = name.toLowerCase();
    final boxKey = _boxKey(name, extension: extension);
    if (isBoxOpen(name, extension: extension)) {
      if (lazy) {
        return lazyBox(name, extension: extension);
      } else {
        return box(name, extension: extension);
      }
    } else {
      if (_openingBoxes.containsKey(boxKey)) {
        await _openingBoxes[boxKey];
        if (lazy) {
          return lazyBox(name, extension: extension);
        } else {
          return box(name, extension: extension);
        }
      }

      final completer = Completer();
      _openingBoxes[boxKey] = completer.future;

      BoxBaseImpl<E>? newBox;
      try {
        StorageBackend backend;
        if (bytes != null) {
          backend = StorageBackendMemory(bytes, cipher, keyCrc);
        } else {
          backend = await _manager.open(
            name,
            path ?? homePath,
            recovery,
            cipher,
            keyCrc,
            collection,
            extension,
          );
        }

        if (lazy) {
          newBox = LazyBoxImpl<E>(
            this,
            name,
            comparator,
            compaction,
            backend,
            isolated: _isolated,
            extension: extension,
          );
        } else {
          newBox = BoxImpl<E>(
            this,
            name,
            comparator,
            compaction,
            backend,
            isolated: _isolated,
            extension: extension,
          );
        }

        await newBox.initialize();
        _boxes[boxKey] = newBox;

        completer.complete();

        if (!_isolated) HiveConnect.registerBox(newBox);

        return newBox;
      } catch (error, stackTrace) {
        newBox?.close().ignore();
        completer.completeError(error, stackTrace);
        rethrow;
      } finally {
        _openingBoxes.remove(boxKey)?.ignore();
      }
    }
  }

  @override
  Future<Box<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    int? keyCrc,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
    String? extension,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    return await _openBox<E>(
      name,
      false,
      encryptionCipher,
      keyCrc,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      bytes,
      collection,
      extension,
    ) as Box<E>;
  }

  @override
  Future<LazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    int? keyCrc,
    KeyComparator keyComparator = defaultKeyComparator,
    CompactionStrategy compactionStrategy = defaultCompactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    String? extension,
    @Deprecated('Use encryptionCipher instead') List<int>? encryptionKey,
  }) async {
    if (encryptionKey != null) {
      encryptionCipher = HiveAesCipher(encryptionKey);
    }
    return await _openBox<E>(
      name,
      true,
      encryptionCipher,
      keyCrc,
      keyComparator,
      compactionStrategy,
      crashRecovery,
      path,
      null,
      collection,
      extension,
    ) as LazyBox<E>;
  }

  BoxBase<E> _getBoxInternal<E>(String name, {bool? lazy, String? extension}) {
    final boxKey = _boxKey(name, extension: extension);
    final box = _boxes[boxKey];
    if (box != null) {
      if ((lazy == null || box.lazy == lazy) && box.valueType == E) {
        return box as BoxBase<E>;
      } else {
        final typeName = box is LazyBox
            ? 'LazyBox<${box.valueType}>'
            : 'Box<${box.valueType}>';
        throw HiveError('The box "$boxKey" is already open '
            'and of type $typeName.');
      }
    } else {
      throw HiveError('Box not found. Did you forget to call Hive.openBox()?');
    }
  }

  /// Not part of public API
  BoxBase? getBoxWithoutCheckInternal(String name, {String? extension}) {
    final boxKey = _boxKey(name, extension: extension);
    return _boxes[boxKey];
  }

  @override
  Box<E> box<E>(String name, {String? extension}) =>
      _getBoxInternal<E>(name, lazy: false, extension: extension) as Box<E>;

  @override
  LazyBox<E> lazyBox<E>(String name, {String? extension}) =>
      _getBoxInternal<E>(name, lazy: true, extension: extension) as LazyBox<E>;

  @override
  bool isBoxOpen(String name, {String? extension}) {
    return _boxes.containsKey(_boxKey(name, extension: extension));
  }

  @override
  Future<void> close() {
    final closeFutures = _boxes.values.map((box) {
      return box.close();
    });

    return Future.wait(closeFutures);
  }

  /// Not part of public API
  void unregisterBox(String name, {String? extension}) {
    final boxKey = _boxKey(name, extension: extension);
    _openingBoxes.remove(boxKey);
    _boxes.remove(boxKey);
  }

  @override
  Future<void> deleteBoxFromDisk(
    String name, {
    String? path,
    String? collection,
    String? extension,
  }) async {
    final boxKey = _boxKey(name, extension: extension);
    final box = _boxes[boxKey];
    if (box != null) {
      await box.deleteFromDisk();
    } else {
      await _manager.deleteBox(
        name.toLowerCase(),
        path ?? homePath,
        collection,
        extension,
      );
    }
  }

  @override
  Future<void> deleteFromDisk() {
    final deleteFutures = _boxes.values.toList().map((box) {
      return box.deleteFromDisk();
    });

    return Future.wait(deleteFutures);
  }

  @override
  List<int> generateSecureKey() {
    return _secureRandom.nextBytes(32);
  }

  @override
  Future<bool> boxExists(
    String name, {
    String? path,
    String? collection,
  }) async {
    final lowerCaseName = name.toLowerCase();
    return await _manager.boxExists(
      lowerCaseName,
      path ?? homePath,
      collection,
    );
  }
}
