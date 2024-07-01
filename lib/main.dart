import 'dart:async';

import 'package:flutter/material.dart';
import 'package:network_tools/network_tools.dart';
import 'package:session_free_chrome/component/new_session.dart';
import 'package:session_free_chrome/exception/chrome_version_exception.dart';
import 'package:session_free_chrome/util/chrome_driver_helper.dart';

import 'package:window_manager/window_manager.dart';

import 'util/app_directory_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(450, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  try {


    runApp(const MyApp());
  } catch (e) {
    runApp(MaterialApp(
      home: Material(
        child: Text(e.toString()),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'new_session',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyController(title: 'new_session'),
    );
  }
}

class MyController extends StatefulWidget {
  const MyController({super.key, required this.title});
  final String title;

  @override
  State<MyController> createState() => _MyControllerState();
}

class _MyControllerState extends State<MyController> with WindowListener {
  bool _init = false;
  String? _msg;
  @override
  void initState() {
    super.initState();
    chromeWindowsInit();
    windowsInit();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowFocus() {
    // Make sure to call once.
    setState(() {});
    // do something
  }

  @override
  void onWindowClose() {
    ChromeDriverHelper.dispose();
  }

  void chromeWindowsInit() {
    windowManager.addListener(this);
  }

  Future<void> windowsInit() async {
    try {
      final appDocDirectory = await AppDirectoryHelper.getAppDirectory();
      await configureNetworkTools(appDocDirectory.path, enableDebugging: true);
      setState(() {
        _msg = "networkTool 완료";
      });

      await ChromeDriverHelper.compareAndDownLoadChromeDriver();
      setState(() {
        _msg = null;
      });
      
    } on ChromeVersionException catch (e) {
      _msg = e.toString();
    } catch (e) {
      _msg = e.toString();
    }

    setState(() {
      _init = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: !_init
            ? const Material(
                child: Center(
                    child: Text(
                  "리소스 준비 중",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              )
            : _msg != null
                ? Material(
                    child: Center(
                    child: Text(_msg!),
                  ))
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      NewSession(),
                    ],
                  ));
  }
}
