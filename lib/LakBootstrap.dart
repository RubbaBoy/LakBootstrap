import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class LakBootstrap {
  Future<void> start(bool disableUpdate, String version) async {
    var tag = await updateDocker(disableUpdate, version);

    print('Docker ready with rubbaboy/lak:$tag');

    await liveDocker(['run', '-p', '8080:8080', 'rubbaboy/lak:$tag']);
  }

  Future<String> updateDocker(bool disableUpdate, String version) async {
    var localImages = await getLocal();


    DockerImage local;
    if (version != null) {
      if (localImages.any((element) => element.tag == version)) {
        return version;
      }
    } else {
      print('Getting remotely available...');
      var latest = await getLatest();

      if (localImages.isNotEmpty) {
        local = localImages.first;

        if (disableUpdate) {
          return local.tag;
        }

        print('Local tag: ${local.tag} Remote tag: ${latest.tag}');
        version = latest.tag;
      }
    }

    if (local?.tag != version) {
      print('Latest local and remote tags don\'t match, pulling local...');
      await liveDocker(['pull', 'rubbaboy/lak:$version']);
    }

    return version;
  }

  Future<void> liveDocker(List<String> args) async {
     final completer = Completer();

     void printOut(Stream<List<int>> stream, [Function() onDone]) {
       stream.transform(utf8.decoder).listen((line) {
         line = line.trim();
         if (line.isNotEmpty) {
           print(line);
         }
       }, onDone: onDone);
     }

     await Process.start('docker', args).then((value) {
       printOut(value.stdout, () => completer.complete());
       printOut(value.stderr);
     });
    return completer.future;
  }

  Future<List<DockerImage>> getLocal() async {
    var resp = await Process.run('docker',
        ['images', 'rubbaboy/lak', '--format', '{{.Tag}},{{.CreatedAt}}']);
    var out = resp.stdout as String;
    var lines = out.split('\n').map((line) => line.split(',')).toList()
      ..removeLast();
    return lines.map((data) => DockerImage.fromCLI(data)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<DockerImage> getLatest() async {
    var resp = await http.get(
        'https://registry.hub.docker.com/v2/repositories/rubbaboy/lak/tags');
    var json = jsonDecode(resp.body);
    var results = json['results'] ?? [];
    if (results.isEmpty) {
      return null;
    }

    return DockerImage.fromJson(results[0]);
  }
}

class DockerImage {
  final String tag;
  final DateTime createdAt;

  DockerImage.fromJson(Map<String, dynamic> json)
      : tag = json['name'],
        createdAt = DateTime.parse(json['last_updated']);

  DockerImage.fromCLI(List<String> data)
      : tag = data[0],
        createdAt = parseCLI(data[1]);

  @override
  String toString() => '[$tag $createdAt]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DockerImage && runtimeType == other.runtimeType &&
              tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}

/// Removes the written timezone from a date, e.g. the EDT from
/// 2020-07-28 16:03:54 -0400 EDT
DateTime parseCLI(String input) =>
    DateTime.parse(input.substring(0, input.lastIndexOf(' ')));
