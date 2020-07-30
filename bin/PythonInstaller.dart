import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart';

void main(List<String> arguments) async {
  print('Python Installer including pip for users without admin rights.');
  print('Please specify the desired install location (must not be a folder with privileged access rights):'); // todo: does not check for required admin privileges, might fail therefor
  Directory installDirectory = Directory(
      stdin.readLineSync(encoding: Encoding.getByName('utf-8'))
  )..createSync(recursive: true);
  File pythonZipFile = await downloadPython(installDirectory.path);
  unzipFile(pythonZipFile, installDirectory.path);
  pythonZipFile.deleteSync();
  editPthFile(installDirectory);
  File pipInstallerFile = await downloadLatestPip(installDirectory.path);
  setEnvVariables(installDirectory);
  runPipInstaller(pipInstallerFile);
}

void runPipInstaller(File pipInstallerFile) {
  Process.runSync('${pipInstallerFile.parent.absolute.path}\\python', [pipInstallerFile.absolute.path], runInShell: true);
}

void setEnvVariables(Directory installDirectory) {
  String absolutePath = installDirectory.absolute.path;
  String tempBatPath = '$absolutePath\\temp.bat';
  String append = '$absolutePath;$absolutePath\\Scripts;';
  File tempBatFile = File(tempBatPath)..createSync()..writeAsStringSync(
      '@echo off\r\n'
      'SETX PATH "%PATH%;$append"'
  );
  Process.runSync('call', [tempBatPath], runInShell: true); // a temp bat file is necessary cause otherwise the PATH variable gets double quotes
  tempBatFile.deleteSync();
}

void editPthFile(Directory installFolderPath) {
  List<FileSystemEntity> installFolderContent = installFolderPath.listSync();
  RegExp format = RegExp('python[0-9]{2}._pth');
  String importStatement = 'import site';
  for (FileSystemEntity entity in installFolderContent) {
    File pthFile = File(entity.path);
    if (pthFile.existsSync() && format.hasMatch(entity.path.substring(
      entity.path.lastIndexOf('\\') + 1
    ))) {
      String content = pthFile.readAsStringSync();
      content = content.replaceAll('#$importStatement', importStatement);
      pthFile.writeAsStringSync(content);
      break;
    }
  }
}

void unzipFile(File src, String dest) {
  final Archive archive = ZipDecoder().decodeBytes(src.readAsBytesSync());
  for (final ArchiveFile file in archive) {
    final String filename = file.name;
    if (file.isFile) {
      final List<int> data = file.content as List<int>;
      File('$dest/$filename')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      Directory('$dest/$filename')
        ..create(recursive: true);
    }
  }
}

Future<File> downloadPython(String targetFolderPath) async {
  String versionExp = '3.\\d.\\d';
  String downloadUrl = RegExp(
      'https://www.python.org/ftp/python/$versionExp/python-$versionExp-embed-amd64.zip'
  ).firstMatch(
      (await get('https://www.python.org/downloads/windows/')).body
  ).group(0);
  return download(
      File('$targetFolderPath\\python.zip'),
      downloadUrl
  );
}

Future<File> downloadLatestPip(String targetFolderPath) async {
  return download(
    File('$targetFolderPath\\get-pip.py'),
    'https://bootstrap.pypa.io/get-pip.py'
  );
}

Future<File> download(File target, String url) async {
  return target..writeAsBytesSync(
      (await get(url)).bodyBytes
  );
}
