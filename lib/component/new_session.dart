import 'package:flutter/material.dart';
import 'package:session_free_chrome/util/chrome_driver_helper.dart';

class NewSession extends StatelessWidget {
  const NewSession({super.key});

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
          } catch (e) {}
        },
        child: const Center(
          child: Text(
            "새 세션",
            style: TextStyle(fontSize: 20, color: Color(0xffffffff)),
          ),
        ),
      ),
    ));
  }
}
