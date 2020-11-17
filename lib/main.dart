import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';

import 'data/hive/hive_adapters.dart';
import 'data/list_manager.dart';
import 'data/random_id.dart';
import 'data/sync_manager.dart';
import 'ui/list_manager_page.dart';

void main() async {
  // Emulate platform
  // debugDefaultTargetPlatformOverride = TargetPlatform.android;
  // debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

  WidgetsFlutterBinding.ensureInitialized();

  final nodeId = generateRandomId(32);

  try {
    final dir = Platform.isAndroid || Platform.isIOS
        ? (await getApplicationDocumentsDirectory()).path
        : 'store';
    Hive.init(dir);
  } catch (_) {
    // Is web
    Hive.init('');
  }

  // Adapters
  Hive.registerAdapter(RecordAdapter(0));
  Hive.registerAdapter(ModRecordAdapter(1));
  Hive.registerAdapter(HlcAdapter(2, nodeId));
  Hive.registerAdapter(ToDoAdapter(3));
  Hive.registerAdapter(ColorAdapter(4));

  final listManager = await ListManager.open(nodeId);

  // TODO Remove this
  // listManager.import('test');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: listManager),
        ChangeNotifierProxyProvider<ListManager, SyncManager>(
          create: (_) => SyncManager(),
          update: (_, listManager, syncManager) =>
              syncManager..listManager = listManager,
        )
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() => isAppInForeground = state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    // TODO Improve this crap
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        getInitialUri().then((uri) {
          if (uri != null) {
            print('URI: $uri');
            final id = uri.pathSegments[0];
            Provider.of<ListManager>(context, listen: false).import(id);
          }
        });
        getUriLinksStream().listen((uri) {
          print('URI: $uri');
          final id = uri.pathSegments[0];
          Provider.of<ListManager>(context, listen: false).import(id);
        }).onError((e) => print(e));
      }
    } catch (_) {}

    _manageConnection(context);

    return Consumer<SyncManager>(builder: (_, syncManager, __) {
      return Column(
        children: [
          Expanded(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              // themeMode: ThemeMode.dark,
              title: 'tudo',
              theme: ThemeData(
                primarySwatch: Colors.blue,
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
              ),
              home: ListManagerPage(),
            ),
          ),
          Container(
            color: syncManager.connected ? Colors.green : Colors.red,
            height: 2,
          ),
        ],
      );
    });
  }

  void _manageConnection(BuildContext context) {
    final syncManager = Provider.of<SyncManager>(context, listen: false);
    if (isAppInForeground) {
      syncManager.connect();
    } else {
      syncManager.disconnect();
    }
  }
}
