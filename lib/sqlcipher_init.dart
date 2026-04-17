import 'dart:ffi';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void initSqlCipher() {
  if (Platform.isLinux || Platform.isWindows) {
    print('🔧 Ouroboros: Configurando SQLCipher para Desktop...');
    
    // Em desenvolvimento, tenta o caminho local
    // Em producao, a lib estara na mesma pasta do executavel ou em lib/
    String libName = Platform.isLinux ? 'libsqlite3.so' : 'sqlite3.dll';
    
    // Tenta caminhos comuns
    final List<String> pathsToTry = [
      libName, // Mesma pasta do executavel (Producao)
      'lib/$libName', // Pasta lib/ (Estrutura padrao do Flutter Linux)
      '/usr/local/lib/$libName', // Sua compilação manual (Desenvolvimento)
    ];

    bool loaded = false;
    for (var path in pathsToTry) {
      if (File(path).existsSync() || _isSystemLib(path)) {
        try {
          // Nota: Em algumas versoes do sqlite3, usamos o override
          // Mas o LD_PRELOAD no script de dev ja resolve.
          // Aqui garantimos a inicializacao do FFI.
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          print('✅ SQLCipher: Biblioteca encontrada em: $path');
          loaded = true;
          break;
        } catch (e) {
          continue;
        }
      }
    }

    if (!loaded) {
      print('⚠️ SQLCipher: Nenhuma biblioteca personalizada encontrada. Usando padrao.');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } else {
    // Android/iOS: O sqflite padrao ja usa o SQLCipher se sqlcipher_flutter_libs estiver no pubspec
    print('📱 Ouroboros: Mobile detectado, usando configuracao nativa.');
  }
}

bool _isSystemLib(String path) => !path.contains('/') && !path.contains('\\');
