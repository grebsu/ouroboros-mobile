import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

void configureSqliteDynamicLibrary() {
  if (!Platform.isLinux) return;

  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open(_linuxSqliteLibraryPath()),
  );
}

String _linuxSqliteLibraryPath() {
  const paths = [
    '/lib64/libsqlite3.so.0',
    '/usr/lib64/libsqlite3.so.0',
    '/lib/x86_64-linux-gnu/libsqlite3.so.0',
    '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
  ];

  for (final path in paths) {
    if (File(path).existsSync()) return path;
  }

  return 'libsqlite3.so.0';
}
