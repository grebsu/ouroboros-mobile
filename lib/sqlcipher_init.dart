import 'dart:ffi';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:path/path.dart';

void initSqlCipher() {
  if (Platform.isLinux || Platform.isWindows) {
    print('🔧 Ouroboros: Configurando SQLCipher para Desktop...');
    
    String libName = Platform.isLinux ? 'libsqlite3.so' : 'sqlite3.dll';
    
    // Caminho do executável para encontrar bibliotecas adjacentes (Modo Produção)
    String executableDir = File(Platform.resolvedExecutable).parent.path;
    
    final List<String> pathsToTry = [
      join(executableDir, 'lib', libName), // Estrutura Flutter Linux
      join(executableDir, libName),        // Mesma pasta (Windows ou Flatpak)
      libName,                            // Fallback para PATH do sistema
      'lib/$libName',                     // Pasta lib local (Desenvolvimento)
    ];

    bool loaded = false;
    for (var path in pathsToTry) {
      if (File(path).existsSync() || _isSystemLib(path)) {
        try {
          if (Platform.isLinux) {
            open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open(path));
          } else if (Platform.isWindows) {
            open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(path));
          }

          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          print('✅ SQLCipher: Biblioteca carregada em: $path');
          loaded = true;
          break;
        } catch (e) {
          print('❌ SQLCipher: Falha ao carregar em $path: $e');
        }
      }
    }

    if (!loaded) {
      print('⚠️ SQLCipher: Nenhuma biblioteca customizada ativa. Usando SQLite padrão.');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } else {
    print('📱 Ouroboros: Mobile detectado, usando SQLCipher nativo via sqflite_sqlcipher.');
  }
}

bool _isSystemLib(String path) => !path.contains('/') && !path.contains('\\');
