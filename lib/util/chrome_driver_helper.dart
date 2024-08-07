import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:session_free_chrome/exception/chrome_version_exception.dart';
import 'package:session_free_chrome/util/app_directory_helper.dart';
import 'package:session_free_chrome/util/local_port_helper.dart';
import 'package:webdriver/sync_io.dart';

class ChromeDriverHelper {
  ChromeDriverHelper._internal();
  static final Map<String, ChromeWindow> _chromeWindows = {};

  /// 크롬 버전과 드라이버 버전이 불일치하면 다운로드
  static Future<void> compareAndDownLoadChromeDriver() async {
    final String chromeVersion = await _getChromeVersion();
    final String chromeDriverVersion = await _getChromeDriverVersion();

    if (chromeVersion != chromeDriverVersion) {
      await downloadDriver(chromeVersion);
    }
  }

  static Future<void> downloadDriver(String chromeVersion) async {
    const driverInfoUrl =
        "https://googlechromelabs.github.io/chrome-for-testing/latest-versions-per-milestone-with-downloads.json";

    final destinationDirectory = await AppDirectoryHelper.getAppDirectory();
    try {
      // 최신 크롬드라이버 버전 다운로드 URL GET
      final res = await http.get(Uri.parse(driverInfoUrl));
      final driverInfo = jsonDecode(res.body);
      final List drivers =
          driverInfo["milestones"][chromeVersion]["downloads"]["chromedriver"];
      final platform = await _getPlatform();
      final url = drivers.firstWhere((e) => e["platform"] == platform)["url"];

      // 크롬 드라이버 zip 파일 다운로드
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('파일 다운로드 실패: ${response.statusCode}');
      }

      // zip 파일 압축 해제
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);

      for (final file in archive) {
        final filename = file.name;
        if (filename.contains("LICENSE")) continue;

        final filePath =
            path.join(destinationDirectory.path, "chromedriver").trim();

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);

          if (Platform.isMacOS) {
            await Process.run('chmod', ['+x', filePath]);
            await _signAndRemoveQuarantine(filePath);
          }
        }
      }

      if (kDebugMode) {
        print('파일이 성공적으로 압축 해제되었습니다.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('에러 발생: $e');
      }
      rethrow;
    }
  }

  static Future<void> _signAndRemoveQuarantine(String filePath) async {
    try {
      // 코드 서명
      final ProcessResult signResult =
          await Process.run('codesign', ['--force', '--sign', '-', filePath]);
      if (signResult.stderr.isNotEmpty) {
        if (kDebugMode) {
          print("Codesign error: ${signResult.stderr}");
        }
      }

      // quarantine 제거
      final ProcessResult quarantineResult =
          await Process.run('xattr', ['-dr', 'com.apple.quarantine', filePath]);
      if (quarantineResult.stderr.isNotEmpty) {
        if (kDebugMode) {
          print("Quarantine removal error: ${quarantineResult.stderr}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('코드 서명 및 quarantine 제거 에러: $e');
      }
    }
  }

  /// 사용자 PC에 설치되어 있는 크롬 버전 가져오기
  static Future<String> _getChromeVersion() async {
    String chromeVersion = "";
    final chromeExecutable = _getChromeExecutable();

    ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run(
        'powershell',
        ['-command', "(Get-Command '$chromeExecutable').Version.ToString()"],
      );
    } else if (Platform.isMacOS) {
      result = await Process.run(
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        ['--version'],
      );
    } else if (Platform.isLinux) {
      result = await Process.run(
        'google-chrome',
        ['--version'],
      );
    } else {
      throw Exception('지원하지 않는 플랫폼입니다.');
    }

    if (result.exitCode == 0) {
      final versionString = result.stdout.toString().trim();
      if (Platform.isWindows) {
        chromeVersion = versionString.substring(0, versionString.indexOf("."));
      } else {
        chromeVersion = versionString.split(" ")[2].split('.')[0];
      }
    } else {
      throw ChromeVersionException(
          '설치된 크롬 버전을 가져오는 데 실패했습니다: ${result.stderr}');
    }

    return chromeVersion.trim();
  }

  /// assets에 포함된 크롬 드라이버 버전 가져오기
  static Future<String> _getChromeDriverVersion() async {
    try {
      String chromeDriverVersion = "";

      final appDirectory = await AppDirectoryHelper.getAppDirectory();
      final driverCheck =
          await Process.start('${appDirectory.path}/chromedriver', ["-v"]);

      await driverCheck.stdout.transform(utf8.decoder).forEach(
        (element) {
          chromeDriverVersion += element;
        },
      );

      chromeDriverVersion =
          chromeDriverVersion.replaceFirst("ChromeDriver", "");
      chromeDriverVersion =
          chromeDriverVersion.substring(0, chromeDriverVersion.indexOf("("));
      return chromeDriverVersion
          .substring(0, chromeDriverVersion.indexOf("."))
          .trim();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return "";
    }
  }

  static Future<String> getMacArchitecture() async {
    if (!Platform.isMacOS) {
      throw Exception('이 함수는 macOS에서만 작동합니다.');
    }

    final result = await Process.run('uname', ['-m']);
    if (result.exitCode != 0) {
      throw Exception('아키텍처를 가져오는 데 실패했습니다: ${result.stderr}');
    }

    final arch = result.stdout.toString().trim();
    if (arch == 'arm64') {
      return 'mac-arm64';
    } else if (arch == 'x86_64') {
      return 'mac-x64';
    } else {
      throw Exception('알 수 없는 아키텍처: $arch');
    }
  }

  static Future<ChromeWindow> runNewSession() async {
    final int port = await LocalPortHelper.emptyPortScan();
    final ChromeWindow chromeWindow = await ChromeWindow.create(port);
    _chromeWindows["$port"] = chromeWindow;
    return chromeWindow;
  }

  static void dispose() {
    _chromeWindows.forEach((key, value) {
      value.driver.quit();
      value.process.kill();
    });
  }

  static Future<String> _getPlatform() async {
    if (Platform.isWindows) {
      return "win64";
    } else if (Platform.isMacOS) {
      return await getMacArchitecture();
    } else if (Platform.isLinux) {
      return "linux64";
    } else {
      throw Exception('지원하지 않는 플랫폼입니다.');
    }
  }

  static String _getChromeExecutable() {
    if (Platform.isWindows) {
      return 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
    } else if (Platform.isMacOS) {
      return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    } else if (Platform.isLinux) {
      return '/usr/bin/google-chrome';
    } else {
      throw Exception('지원하지 않는 플랫폼입니다.');
    }
  }
}

class ChromeWindow {
  late Process process;
  late WebDriver driver;

  ChromeWindow._create(int port) {}

  static Future<ChromeWindow> create(int port) async {
    final window = ChromeWindow._create(port);
    final appDirectory = await AppDirectoryHelper.getAppDirectory();
    final chromedriverPath = '${appDirectory.path}/chromedriver';

    window.process = await Process.start(
      chromedriverPath,
      ['--port=$port', '--url-base=wd/hub'],
    );

    await for (String browserOut in const LineSplitter()
        .bind(const Utf8Decoder().bind(window.process.stdout))) {
      if (browserOut.contains('Starting ChromeDriver')) {
        break;
      }
    }

    window.driver = createDriver(
        uri: Uri.parse('http://localhost:$port/wd/hub/'),
        desired: Capabilities.chrome);

    return window;
  }
}
