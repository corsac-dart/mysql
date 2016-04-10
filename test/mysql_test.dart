library corsac_mysql.tests.mysql;

import 'package:test/test.dart';
import 'package:corsac_mysql/corsac_mysql.dart';

void main() {
  group('MySQL:', () {
    MySQL mysql;

    setUp(() async {
      mysql = new MySQL('127.0.0.1', 3306, 'root', null, null);
      await mysql.query(
          'CREATE DATABASE IF NOT EXISTS mysql_test DEFAULT CHARACTER SET utf8;');
      await mysql.query('USE mysql_test;');
      await mysql.query(
          'CREATE TABLE IF NOT EXISTS example_innodb (id INT, data VARCHAR(100), UNIQUE KEY `id` (`id`)) ENGINE=innodb;');
    });

    tearDown(() async {
      await mysql.connectionPool.query('DROP DATABASE IF EXISTS mysql_test;');
      mysql.closeConnection();
    });

    test('it can put record in table', () async {
      await mysql.put('example_innodb', {'id': 1, 'data': 'test'});
    });

    test('it can update record in table', () async {
      await mysql.put('example_innodb', {'id': 1, 'data': 'test'});
      await mysql.put('example_innodb', {'id': 1, 'data': 'updated'});

      var rec = await mysql.get('example_innodb', 1);
      expect(rec, equals({'id': 1, 'data': 'updated'}));
    });

    test('it returns null if record not found', () async {
      var rec = await mysql.get('example_innodb', 423);
      expect(rec, isNull);
    });

    test('it can list columns in a table', () async {
      var list = await mysql.listColumns('example_innodb');
      expect(['id', 'data'], equals(list));
    });
  });
}
