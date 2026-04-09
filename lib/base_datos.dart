import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BaseDatosLocal {
  // Patrón Singleton: Garantiza que solo haya una conexión abierta
  static final BaseDatosLocal instancia = BaseDatosLocal._init();
  static Database? _database;

  BaseDatosLocal._init();

  // Getter para obtener la base de datos, si no existe, la crea
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _iniciarDB('pulpos_offline.db');
    return _database!;
  }

  // Busca la ruta segura en Android/iOS y abre el archivo .db
  Future<Database> _iniciarDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _crearDB);
  }

  // Aquí es donde ocurre la magia de SQL que diseñamos
  Future _crearDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE viajes_offline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        distancia_km REAL,
        tiempo_detencion_min REAL,
        factor_altitud REAL,
        factor_superficie REAL,
        tarifa_total REAL,
        estado_sincronizacion INTEGER,
        fecha_hora TEXT
      )
    ''');
  } // <--- ¡AQUÍ SE CIERRA _crearDB!

  // Función para guardar un nuevo viaje en la "caja negra"
  Future<int> insertarViaje(Map<String, dynamic> viaje) async {
    // 1. Abrimos la conexión a la base de datos
    final db = await instancia.database;

    // 2. Le pedimos a sqflite que haga el INSERT de forma segura
    int idGenerado = await db.insert(
      'viajes_offline', // El nombre exacto de la tabla
      viaje, // El mapa con los datos (distancia, tarifa, fecha, etc.)
    );

    // Retorna el ID (el número de ticket) que SQLite le asignó a este viaje
    return idGenerado;
  }
}
