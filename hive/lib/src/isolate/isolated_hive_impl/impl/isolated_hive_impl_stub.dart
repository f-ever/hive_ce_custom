import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

/// Stub implementation of [IsolatedHiveInterface]
class IsolatedHiveImpl implements IsolatedHiveInterface {
  @override
  Future<void> init(
    String? path, {
    IsolateNameServer? isolateNameServer,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<IsolatedBox<E>> openBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    Uint8List? bytes,
    String? collection,
    String? extension,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<IsolatedLazyBox<E>> openLazyBox<E>(
    String name, {
    HiveCipher? encryptionCipher,
    KeyComparator? keyComparator,
    CompactionStrategy? compactionStrategy,
    bool crashRecovery = true,
    String? path,
    String? collection,
    String? extension,
  }) {
    throw UnimplementedError();
  }

  @override
  IsolatedBox<E> box<E>(String name, {String? extension}) {
    throw UnimplementedError();
  }

  @override
  IsolatedLazyBox<E> lazyBox<E>(String name, {String? extension}) {
    throw UnimplementedError();
  }

  @override
  bool isBoxOpen(String name, {String? extension}) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBoxFromDisk(String name, {String? path}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFromDisk() {
    throw UnimplementedError();
  }

  @override
  Future<bool> boxExists(String name, {String? path}) {
    throw UnimplementedError();
  }

  @override
  void registerAdapter<T>(
    TypeAdapter<T> adapter, {
    bool internal = false,
    bool override = false,
  }) {
    throw UnimplementedError();
  }

  @override
  bool isAdapterRegistered(int typeId) {
    throw UnimplementedError();
  }

  @override
  void resetAdapters() {
    throw UnimplementedError();
  }

  @override
  Future<void> ignoreTypeId<T>(int typeId) {
    throw UnimplementedError();
  }
}
