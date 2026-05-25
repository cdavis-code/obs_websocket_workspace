import 'package:args/command_runner.dart';

/// Display the package name and version
class ObsVersionCommand extends Command<void> {
  static const packageName = 'obs_cli';
  static const packageVersion = '5.7.0+2';

  @override
  String get description => 'Display the package name and version';

  @override
  String get name => 'version';

  @override
  void run() async {
    print('$packageName v$packageVersion');
  }
}
