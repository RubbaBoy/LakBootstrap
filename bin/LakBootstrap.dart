import 'package:LakBootstrap/LakBootstrap.dart';
import 'package:args/args.dart';

final DOCKER_REGEX = RegExp(r'\s{2,}');

Future<void> main(List<String> arguments) async {
  var parser = ArgParser()
    ..addFlag('disable-update',
        help: 'Disables auto-update if a docker image is already present')
    ..addOption('version',
        help: 'The specific docker tag to use, e.g. master-abc123');

  var parsed = parser.parse(arguments);

  var version = parsed['version'];
  await LakBootstrap().start(parsed['disable-update'], version);
}
