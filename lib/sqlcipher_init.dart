import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'dart:ffi';

void initSqlCipher() {
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    print('🔧 Ouroboros: Configurando SQLCipher para Desktop...');
    
    String libName = Platform.isLinux ? 'libsqlite3.so' : 'sqlite3.dll';
    String executableDir = File(Platform.resolvedExecutable).parent.path;
    
    // Lista de caminhos para tentar encontrar a biblioteca SQLCipher
    final List<String> pathsToTry = [
      join(executableDir, 'lib', libName), // Caminho padrão do bundle Flutter
      join(executableDir, libName),
      join(Directory.current.path, 'linux', 'libs', libName), // Desenvolvimento (CWD)
      '/usr/local/lib/$libName',
      libName, // Fallback sistema
    ];

    bool loaded = false;
    for (var path in pathsToTry) {
      if (File(path).existsSync()) {
        try {
          open.overrideFor(
            Platform.isLinux ? OperatingSystem.linux : OperatingSystem.windows,
            () => DynamicLibrary.open(path),
          );
          print('✅ SQLCipher: Biblioteca carregada em: $path');
          loaded = true;
          break;
        } catch (e) {
          print('❌ SQLCipher: Erro ao carregar em $path: $e');
        }
      }
    }

    if (!loaded) print('⚠️ SQLCipher: Nenhuma lib customizada encontrada. Usando SQLite padrão.');

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    print('📱 Ouroboros: Mobile detectado, usando SQLCipher nativo via sqflite_sqlcipher.');
  }
}
