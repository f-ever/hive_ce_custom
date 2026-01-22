import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce/src/box/default_compaction_strategy.dart';
import 'package:hive_ce/src/box/default_key_comparator.dart';
import 'package:hive_ce/src/hive_impl.dart';
import 'package:hive_ce/src/isolate/handler/isolated_box_handler.dart';
import 'package:hive_ce/src/util/logger.dart';
import 'package:isolate_channel/isolate_channel.dart';

/// Generate a unique box key from name and extension
String _boxKey(String name, {String? extension}) {
  final lowerName = name.toLowerCase();
  if (extension != null) {
    return '$lowerName|e:$extension';
  }
  return lowerName;
}

/// Method call handler for Hive methods
Future<dynamic> handleHiveMethodCall(
  IsolateMethodCall call,
  IsolateConnection connection,
  Map<String, IsolatedBoxHandler> boxHandlers,
) async {
  switch (call.method) {
    case 'init':
      Hive.init(call.arguments['path']);
      (Hive as HiveImpl).setIsolated();
      final loggerLevel = call.arguments['logger_level'];
      Logger.level = LoggerLevel.values.byName(loggerLevel);
    case 'openBox':
      final name = call.arguments['name'];
      final lazy = call.arguments['lazy'];
      final extension = call.arguments['extension'] as String?;
      final boxKey = _boxKey(name, extension: extension);

      if (boxHandlers.containsKey(boxKey)) {
        // Ensure this is a valid `openBox` call
        if (lazy) {
          Hive.lazyBox(name, extension: extension);
        } else {
          Hive.box(name, extension: extension);
        }
        return;
      }

      final keyCrc = call.arguments['keyCrc'];
      final keyComparator =
          call.arguments['keyComparator'] ?? defaultKeyComparator;
      final compactionStrategy =
          call.arguments['compactionStrategy'] ?? defaultCompactionStrategy;
      final crashRecovery = call.arguments['crashRecovery'];
      final path = call.arguments['path'];
      final bytes = call.arguments['bytes'];
      final collection = call.arguments['collection'];

      final BoxBase box;
      if (lazy) {
        box = await (Hive as HiveImpl).openLazyBox(
          name,
          keyCrc: keyCrc,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          collection: collection,
          extension: extension,
        );
      } else {
        box = await (Hive as HiveImpl).openBox(
          name,
          keyCrc: keyCrc,
          keyComparator: keyComparator,
          compactionStrategy: compactionStrategy,
          crashRecovery: crashRecovery,
          path: path,
          bytes: bytes,
          collection: collection,
          extension: extension,
        );
      }

      boxHandlers[boxKey] = IsolatedBoxHandler(box, connection);
    case 'deleteBoxFromDisk':
      await Hive.deleteBoxFromDisk(
        call.arguments['name'],
        path: call.arguments['path'],
        extension: call.arguments['extension'],
      );
    case 'boxExists':
      return Hive.boxExists(
        call.arguments['name'],
        path: call.arguments['path'],
      );
    case 'unregisterBox':
      final name = call.arguments['name'];
      final extension = call.arguments['extension'] as String?;
      final boxKey = _boxKey(name, extension: extension);
      boxHandlers.remove(boxKey);
      (Hive as HiveImpl).unregisterBox(name, extension: extension);
    default:
      return call.notImplemented();
  }
}
