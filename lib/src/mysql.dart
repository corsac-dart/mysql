part of corsac_mysql;

/// MySQL Client
class MySQL {
  final String host;
  final int port;
  final String username;
  final String password;
  final String db;

  ConnectionPool _connectionPool;

  static Map<String, MySQL> _instancesByHostAndDb = new Map();

  MySQL._(this.host, this.port, this.username, String password, this.db)
      : password = (password is String && password.isEmpty) ? null : password;

  factory MySQL(
      String host, port, String username, String password, String db) {
    var key = (db == null || db.isEmpty)
        ? '${host}:${port}'
        : '${host}:${port}/${db}';
    var portAsInt = (port is int) ? port : int.parse(port);

    if (!_instancesByHostAndDb.containsKey(key)) {
      _instancesByHostAndDb[key] =
          new MySQL._(host, portAsInt, username, password, db);
    }

    return _instancesByHostAndDb[key];
  }

  factory MySQL.fromUri(String uri) {
    var _ = Uri.parse(uri);
    var credentials = _.userInfo.split(':');
    var db = _.path.replaceFirst('/', '');
    return new MySQL(_.host, _.port, credentials.first, credentials.last, db);
  }

  ConnectionPool get connectionPool {
    if (_connectionPool == null) {
      _connectionPool = new ConnectionPool(
          host: host,
          port: port,
          user: username,
          password: password,
          max: 1,
          db: db);
    }

    return _connectionPool;
  }

  // TODO: consider using transaction and `SELECT FOR UPDATE` with update counter to prevent concurrent updates?
  Future put(String table, Map record) async {
    List update = [];
    for (var key in record.keys) {
      update.add('${key}=VALUES(${key})');
    }

    var keys = record.keys.join('`, `');
    var values = new List.filled(record.length, '?').join(', ');
    var updates = update.join(', ');
    var query = await connectionPool.prepare(
        'INSERT into ${table} (`${keys}`) VALUES (${values}) ON DUPLICATE KEY UPDATE ${updates}');
    var result = await query.execute(record.values.toList());

    assert([0, 1, 2].contains(result.affectedRows));
  }

  Future<Map<String, dynamic>> get(String table, id,
      {String column, String database}) async {
    column ??= 'id';
    var from = (database is String) ? '`${database}`.`${table}`' : '`${table}`';
    var query = await connectionPool
        .prepare('SELECT * FROM ${from} WHERE `${column}` = ? LIMIT 1');
    var result = await query.execute([id]);
    var rows = await result.toList();
    if (rows.isEmpty) {
      return null;
    }
    var row = rows.first;
    return rowToMap(row, result.fields);
  }

  Stream<Map<String, dynamic>> batchGet(String table, Set ids,
      {String column, String database}) {
    StreamController<Map<String, dynamic>> controller = new StreamController();

    column ??= 'id';
    var from = (database is String) ? '`${database}`.`${table}`' : '`${table}`';
    var placeholders = new List.filled(ids.length, '?');
    connectionPool
        .prepare(
            'SELECT * FROM ${from} WHERE `${column}` IN (${placeholders.join(", ")})')
        .then((q) {
      return q.execute(ids.toList(growable: false));
    }).then((results) {
      return results.map((row) => rowToMap(row, results.fields));
    }).then((stream) {
      return controller.addStream(stream);
    }).then((_) => controller.close());

    return controller.stream;
  }

  Future<Results> query(String sql) => connectionPool.query(sql);

  Future<List<String>> listColumns(String table) async {
    var result = await query('SHOW COLUMNS FROM `${table}`');
    var rows = await result.toList();
    return rows.map((_) => _.elementAt(0));
  }

  /// Converts
  Map<String, dynamic> rowToMap(Row row, List<Field> fields) {
    Map<String, dynamic> record = new Map();
    for (var i = 0; i < row.length; i++) {
      var field = fields.elementAt(i);
      record[field.name] = row.elementAt(i);
    }

    return record;
  }

  void closeConnection() {
    connectionPool.closeConnectionsWhenNotInUse();
  }
}
