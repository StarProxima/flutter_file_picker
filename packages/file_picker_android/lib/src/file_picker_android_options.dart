import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

/// The access mode that is coupled to an [AndroidSAFGrant].
enum AndroidSAFAccessMode {
  /// Only allow read permission for a URI.
  readOnly,

  /// Allow both read and write permissions for a URI.
  readWrite,
}

/// The grant type for an Android Storage Access Framework grant.
enum AndroidSAFGrant {
  /// Grant permission to the requested URI for the current request only.
  transient,

  /// Grant permission to the requested URI, until permission is explicitly revoked.
  lifetime,
}

/// Configuration options for working with Android Storage Access Framework (SAF).
final class AndroidSAFOptions {
  const AndroidSAFOptions({
    this.grant = AndroidSAFGrant.transient,
    this.accessMode = AndroidSAFAccessMode.readOnly,
    this.persistGrant = true,
  });

  /// The grant to use with the Android Storage Access Framework.
  ///
  /// Defaults to [AndroidSAFGrant.transient].
  final AndroidSAFGrant grant;

  /// The access mode to use with the Android Storage Access Framework.
  ///
  /// Defaults to [AndroidSAFAccessMode.readOnly].
  final AndroidSAFAccessMode accessMode;

  /// Whether to persist the [grant], so that it is preserved across device reboots.
  ///
  /// Defaults to `true`.
  final bool persistGrant;

  Map<String, Object?> toMap() {
    return {
      'grant': grant.name,
      'access': accessMode.name,
      'autoPersist': persistGrant,
    };
  }
}

/// Configuration options specific to the Android platform.
final class FilePickerAndroidOptions extends AndroidOptions {
  const FilePickerAndroidOptions({
    this.safOptions = const AndroidSAFOptions(),
    this.maxCachedFileSize,
  }) : assert(
         maxCachedFileSize == null || maxCachedFileSize >= 0,
         'maxCachedFileSize cannot be negative',
       );

  /// Options for working with the Android Storage Access Framework.
  final AndroidSAFOptions safOptions;

  /// The largest size, in bytes, of a picked file that is copied to the app's
  /// cache.
  ///
  /// Files larger than this are not copied, which avoids spending the time and
  /// storage to copy a large file just to find out it is too big. The returned
  /// file then has no local path: its `uri` is the content URI of the file and
  /// its `lengthSync()` is the size reported by the document provider. Its
  /// content cannot be read through the returned file, read it from the content
  /// URI instead.
  ///
  /// Files that are not larger than this, files whose size the document
  /// provider does not report, and images re-encoded by `compressionQuality`
  /// are copied as usual. When `null`, which is the default, every file is
  /// copied.
  final int? maxCachedFileSize;

  Map<String, Object?> toMap() {
    return {
      'safOptions': safOptions.toMap(),
      'maxCachedFileSize': maxCachedFileSize,
    };
  }
}
