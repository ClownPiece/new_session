import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:session_free_chrome/util/chrome_driver_helper.dart';

class NewSession extends StatefulWidget {
  const NewSession({super.key});

  @override
  State<NewSession> createState() => _NewSessionState();
}

class _NewSessionState extends State<NewSession> {
  String stateMsg = "새 세션";
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Material(
      color: const Color(0xff000000),
      child: InkWell(
        hoverColor: Color(Colors.amber.shade800.value),
        onTap: () async {
          try {
            final ChromeWindow chromeWindow =
                await ChromeDriverHelper.runNewSession();

            final driver = chromeWindow.driver;
            driver.get("https://google.com");
          } catch (e) {
            if (kDebugMode) {
              print(e);
            }
            setState(() {
              stateMsg = e.toString();
            });
          }
        },
        child: Center(
          child: Text(
            stateMsg,
            style: const TextStyle(fontSize: 20, color: Color(0xffffffff)),
          ),
        ),
      ),
    ));
  }
}
