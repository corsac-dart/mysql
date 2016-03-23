part of corsac_mysql;

/// Generic implementation of MySQL repository for domain entities.
class MySQLRepository<T> implements Repository<T> {
  final MySQL mysql;
  final String tableName;

  MySQLRepository(this.mysql, this.tableName);

  String getIdentityFieldName() {
    final mirror = reflectClass(T);

    if (mirror.declarations.containsKey(const Symbol('id'))) {
      return 'id';
    } else {
      var annotatedField = mirror.declarations.values.firstWhere((_) {
        return _ is VariableMirror && _.metadata.contains(reflect(identity));
      }, orElse: () => null);

      if (annotatedField is VariableMirror) {
        return MirrorSystem.getName(annotatedField.simpleName);
      }
    }

    throw new StateError('Can not determine identity field name for ${T}.');
  }

  @override
  Future<T> get(id) {
    var fieldName = getIdentityFieldName();
    return mysql
        .get(tableName, id, column: humps.decamelize(fieldName))
        .then((record) {
      if (record is Map) {
        var state = recordToStateObject(record);
        return State.restore(T, state);
      } else {
        return null;
      }
    });
  }

  @override
  Future put(T entity) {
    var record = stateObjectToRecord(State.snapshot(entity));
    return mysql.put(tableName, record);
  }

  /// Normalizes MySQL record structure into a state object which can be
  /// used to reconstruct the entity.
  ///
  /// Default implementation only performs conversion of keys in the record map
  /// from `underscore_separated` to `camelCase`.
  Map recordToStateObject(Map record) {
    return humps.camelizeKeys(record);
  }

  /// Normalizes entity's state object to MySQL record according to schema.
  ///
  /// Default implementation only performs conversion of keys in the state map
  /// from `camelCase` to `underscore_separated`.
  Map stateObjectToRecord(Map object) {
    return humps.decamelizeKeys(object);
  }

  @override
  Stream<T> find(Criteria criteria) {
    var controller = new StreamController<T>();
    var q = buildQuery(criteria);
    mysql.connectionPool.prepare(q.sql).then((preparedQuery) {
      return preparedQuery.execute(q.parameters);
    }).then((results) {
      return results.map((row) {
        var record = mysql.rowToMap(row, results.fields);
        var state = recordToStateObject(record);
        return State.restore(T, state);
      });
    }).then((stream) {
      return controller.addStream(stream);
    }).then((_) {
      controller.close();
    });
    return controller.stream;
  }

  @override
  Future<T> findOne(Criteria criteria) {
    criteria.skip = null;
    criteria.take = 1;

    return find(criteria)
        .first
        .catchError((error) => null, test: (error) => error is StateError);
  }

  SQLQuery buildQuery(Criteria criteria) {
    criteria.conditions.forEach((c) {
      c.key = humps.decamelize(c.key);
    });
    return new SQLQuery.buildSelect(criteria, tableName);
  }

  @override
  Stream<T> batchGet(Set ids) {
    var fieldName = getIdentityFieldName();
    return mysql
        .batchGet(tableName, ids, column: humps.decamelize(fieldName))
        .map((record) {
      var state = recordToStateObject(record);
      return State.restore(T, state);
    });
  }

  @override
  Future batchPut(Set<T> entities) {
    // TODO: implement batchPut
    throw new StateError('MySQLRepository.batchGet() is not implemented yet.');
  }

  @override
  Future<int> count([Criteria<T> criteria]) {
    var query = new SQLQuery.buildSelect(criteria, tableName, count: true);
    return mysql.connectionPool
        .prepare(query.sql)
        .then((prepared) => prepared.execute(query.parameters))
        .then((results) => results.first)
        .then((row) => row.first);
  }
}

/// SQL query builder.
///
/// Current limitations:
///
///  * no joins
///  * only AND for conditions in `WHERE` clause
class SQLQuery {
  final String sql;
  final List parameters;
  SQLQuery._(this.sql, this.parameters);

  factory SQLQuery.buildSelect(Criteria criteria, String tableName,
      {bool count: false}) {
    var where = [];
    var parameters = [];
    var limit = '';
    if (criteria is Criteria) {
      for (var c in criteria.conditions) {
        where.add("${c.key} ${c.predicate} ?");
        parameters.add(c.value);
      }

      if (criteria.skip != null || criteria.take != null) {
        var limits = [];
        if (criteria.skip != null) limits.add(criteria.skip);
        if (criteria.take != null) limits.add(criteria.take);
        limit = " LIMIT " + limits.join(', ');
      }
    }

    var whereSql = where.isNotEmpty ? 'WHERE ' + where.join(' AND ') : '';
    var sql = '';
    if (count) {
      sql = "SELECT COUNT(*) FROM `${tableName}` $whereSql";
    } else {
      sql = "SELECT * FROM `${tableName}` $whereSql " + limit;
    }

    return new SQLQuery._(sql, parameters);
  }
}
