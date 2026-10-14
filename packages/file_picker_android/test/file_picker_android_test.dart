import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FilePickerAndroid', () {
    test('registers instance', () {
      FilePickerAndroid.registerWith();
      expect(FilePickerPlatform.instance, isA<FilePickerAndroid>());
    });

    test('AndroidSAFOptions toMap contains expected keys', () {
      const safOptions = AndroidSAFOptions(
        grant: AndroidSAFGrant.lifetime,
        accessMode: AndroidSAFAccessMode.readWrite,
        persistGrant: true,
      );
      const options = FilePickerAndroidOptions(safOptions: safOptions);
      final map = options.safOptions.toMap();
      expect(map['grant'], equals('lifetime'));
      expect(map['access'], equals('readWrite'));
      expect(map['autoPersist'], isTrue);
    });

    test('AndroidSAFHandle parses map correctly', () {
      final handle = AndroidSAFHandle.fromMap({
        'uri': 'content://media/external/images/media/1',
        'access': 'readWrite',
      });
      expect(
        handle.uri,
        equals(Uri.parse('content://media/external/images/media/1')),
      );
      expect(handle.accessMode, equals(AndroidSAFAccessMode.readWrite));
    });

    test('AndroidPlatformFile derives name from path if name is empty', () {
      final file = AndroidPlatformFile.fromMap({'path': '/tmp/test_file.txt'});
      expect(file.name, equals('test_file.txt'));
      expect(file.path, equals('/tmp/test_file.txt'));
    });

    test('AndroidPlatformFile.lengthSync() reflects the reported size', () {
      final withSize = AndroidPlatformFile.fromMap({
        'path': '/tmp/test_file.txt',
        'size': 2048,
      });
      expect(withSize.lengthSync(), equals(2048));

      final withoutSize = AndroidPlatformFile.fromMap({
        'path': '/tmp/test_file.txt',
      });
      expect(withoutSize.lengthSync(), isNull);
    });

    test('FilePickerAndroidOptions toMap leaves the size limit unset', () {
      final map = const FilePickerAndroidOptions().toMap();
      expect(map, containsPair('maxCachedFileSize', isNull));
      expect(map['safOptions'], isA<Map<String, Object?>>());
    });

    test('FilePickerAndroidOptions toMap contains maxCachedFileSize', () {
      const options = FilePickerAndroidOptions(maxCachedFileSize: 50 * 1024);
      expect(options.toMap(), containsPair('maxCachedFileSize', 51200));
      expect(options.toMap()['safOptions'], options.safOptions.toMap());
    });

    test('FilePickerAndroidOptions rejects a negative maxCachedFileSize', () {
      expect(
        () => FilePickerAndroidOptions(maxCachedFileSize: -1),
        throwsAssertionError,
      );
      expect(const FilePickerAndroidOptions(maxCachedFileSize: 0), isNotNull);
    });

    test('AndroidPlatformFile.fromMap uses the uri when there is no path', () {
      final file = AndroidPlatformFile.fromMap({
        'path': null,
        'name': 'video.mp4',
        'size': 629145600,
        'uri':
            'content://com.android.providers.media.documents/document/video%3A42',
      });
      expect(
        file.uri,
        Uri.parse(
          'content://com.android.providers.media.documents/document/video%3A42',
        ),
      );
      expect(file.name, 'video.mp4');
      expect(file.path, isNull);
      expect(file.lengthSync(), 629145600);
    });

    test('AndroidPlatformFile.fromMap prefers the path over the uri', () {
      final file = AndroidPlatformFile.fromMap({
        'path': '/tmp/test_file.txt',
        'uri': 'content://media/external/file/1',
      });
      expect(file.uri, Uri.file('/tmp/test_file.txt'));
      expect(file.path, '/tmp/test_file.txt');
    });

    test(
      'pickFile sends maxCachedFileSize and returns a file that was not copied',
      () async {
        final picker = FilePickerAndroid();
        Map<Object?, Object?>? sentOptions;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              sentOptions =
                  (call.arguments as Map<Object?, Object?>)['androidSafOptions']
                      as Map<Object?, Object?>?;
              return [
                {
                  'path': null,
                  'name': 'video.mp4',
                  'size': 629145600,
                  'uri': 'content://media/external/video/media/42',
                },
              ];
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null),
        );

        final file = await picker.pickFile(
          androidOptions: const FilePickerAndroidOptions(
            maxCachedFileSize: 50 * 1024 * 1024,
          ),
        );

        expect(sentOptions?['maxCachedFileSize'], 50 * 1024 * 1024);
        expect(file?.name, 'video.mp4');
        expect(file?.path, isNull);
        expect(file?.uri, Uri.parse('content://media/external/video/media/42'));
        expect(file?.lengthSync(), 629145600);
      },
    );

    test(
      'pickFileAndDirectoryPaths returns decoded paths that match the cached files',
      () async {
        final picker = FilePickerAndroid();
        const cachedPath =
            '/data/user/0/app/cache/file_picker/1/AdSenseReport (3) #1 ñ%.PDF';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              return [
                {'path': cachedPath, 'name': 'AdSenseReport (3) #1 ñ%.PDF'},
              ];
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(picker.methodChannel, null),
        );

        expect(await picker.pickFileAndDirectoryPaths(), [cachedPath]);
      },
    );

    group('retrieveLostData', () {
      late FilePickerAndroid picker;

      void respondWith(Object? response) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, (call) async {
              expect(call.method, 'retrieveLostData');
              return response;
            });
      }

      setUp(() => picker = FilePickerAndroid());
      tearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(picker.methodChannel, null),
      );

      test('returns null when nothing was lost', () async {
        respondWith(null);
        expect(await picker.retrieveLostData(), isNull);
      });

      test('returns the lost files', () async {
        respondWith({
          'files': [
            {'path': '/cache/a.pdf', 'name': 'a.pdf', 'size': 3},
            {'path': '/cache/b.png', 'name': 'b.png', 'size': 5},
          ],
        });

        final lost = await picker.retrieveLostData();

        expect(lost?.exception, isNull);
        expect(lost?.files.map((f) => f.path), [
          '/cache/a.pdf',
          '/cache/b.png',
        ]);
        expect(lost?.files.first.lengthSync(), 3);
      });

      test('returns the error raised while processing', () async {
        respondWith({
          'errorCode': 'out_of_memory',
          'errorMessage': 'Selected files are too large to process.',
        });

        final lost = await picker.retrieveLostData();

        expect(lost?.files, isEmpty);
        expect(lost?.exception?.code, 'out_of_memory');
        expect(
          lost?.exception?.message,
          'Selected files are too large to process.',
        );
      });
    });

    test('AndroidPlatformFile throws ArgumentError on empty path and uri', () {
      expect(() => AndroidPlatformFile.fromMap({}), throwsArgumentError);
    });

    test('AndroidPlatformFile equality and hashCode work correctly', () {
      final file1 = AndroidPlatformFile(
        name: 'test.txt',
        uri: Uri.file('/tmp/test.txt'),
      );
      final file2 = AndroidPlatformFile(
        name: 'test.txt',
        uri: Uri.file('/tmp/test.txt'),
      );
      expect(file1, equals(file2));
      expect(file1.hashCode, equals(file2.hashCode));
    });
  });
}
