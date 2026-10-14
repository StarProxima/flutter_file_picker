import 'dart:io';

import 'package:file_picker/src/file_picker.dart';
import 'package:file_picker/src/file_picker_io.dart';
import 'package:file_picker/src/platform_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const contentUri =
      'content://com.android.providers.media.documents/document/video%3A42';

  // The same channel and codec that FilePickerIO uses on this host.
  final channel = MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
    Platform.isLinux || Platform.isWindows || Platform.isMacOS
        ? const JSONMethodCodec()
        : const StandardMethodCodec(),
  );

  group('PlatformFile.fromMap()', () {
    test('should keep a file that was not copied, without a path', () {
      final file = PlatformFile.fromMap({
        'path': null,
        'name': 'video.mp4',
        'size': 629145600,
        'bytes': null,
        'identifier': contentUri,
      });

      expect(file.path, isNull);
      expect(file.name, equals('video.mp4'));
      expect(file.size, equals(629145600));
      expect(file.bytes, isNull);
      expect(file.identifier, equals(contentUri));
    });
  });

  group('FilePickerIO.pickFiles()', () {
    late Map<Object?, Object?>? sentArguments;
    late Object? response;

    setUp(() {
      sentArguments = null;
      response = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        sentArguments = call.arguments as Map<Object?, Object?>?;
        return response;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should send maxCachedFileSize to the platform', () async {
      await FilePickerIO().pickFiles(maxCachedFileSize: 50 * 1024 * 1024);

      expect(sentArguments?['maxCachedFileSize'], equals(50 * 1024 * 1024));
    });

    test('should not send a size limit by default', () async {
      await FilePickerIO().pickFiles();

      expect(sentArguments, containsPair('maxCachedFileSize', isNull));
    });

    test('should return a file that was not copied without a path', () async {
      response = [
        {
          'path': null,
          'name': 'video.mp4',
          'size': 629145600,
          'bytes': null,
          'identifier': contentUri,
        },
      ];

      final result = await FilePickerIO().pickFiles(
        type: FileType.video,
        maxCachedFileSize: 50 * 1024 * 1024,
      );

      final file = result!.files.single;
      expect(file.path, isNull);
      expect(file.name, equals('video.mp4'));
      expect(file.size, equals(629145600));
      expect(file.identifier, equals(contentUri));
    });

    test('should only open a read stream for files that have a path', () async {
      response = [
        {
          'path': '/data/user/0/app/cache/file_picker/1/small.jpg',
          'name': 'small.jpg',
          'size': 1024,
          'bytes': null,
          'identifier': 'content://media/external/images/media/1',
        },
        {
          'path': null,
          'name': 'video.mp4',
          'size': 629145600,
          'bytes': null,
          'identifier': contentUri,
        },
      ];

      final result = await FilePickerIO().pickFiles(
        allowMultiple: true,
        withReadStream: true,
        maxCachedFileSize: 50 * 1024 * 1024,
      );

      expect(result!.files[0].readStream, isNotNull);
      expect(result.files[1].readStream, isNull);
    });
  });
}
