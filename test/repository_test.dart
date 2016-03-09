library corsac_mysql.tests.repository;

import 'package:test/test.dart';
import 'package:corsac_mysql/corsac_mysql.dart';

class User {
  final int id;
  String fullName;
  DateTime createdAt;

  User(this.id, this.fullName, this.createdAt);
}

void main() {
  group('MySQLRepository:', () {
    MySQL mysql;
    MySQLRepository<User> repo;

    setUp(() async {
      mysql = new MySQL('localhost', 3306, 'root', null, null);
      repo = new MySQLRepository<User>(mysql, 'users');
      await mysql.query(
          'CREATE DATABASE IF NOT EXISTS mysql_test DEFAULT CHARACTER SET utf8;');
      await mysql.query('USE mysql_test;');
      await mysql.query(
          'CREATE TABLE IF NOT EXISTS users (id INT, full_name VARCHAR(100), created_at VARCHAR(32), UNIQUE KEY `id` (`id`)) ENGINE=innodb;');
    });

    tearDown(() async {
      await mysql.connectionPool.query('DROP DATABASE IF EXISTS mysql_test;');
      mysql.closeConnection();
    });

    test('it can store entities', () async {
      var createdAt = new DateTime.now();
      await repo.put(new User(1, 'Burt Macklin', createdAt));
      var user = await repo.get(1);
      expect(user, new isInstanceOf<User>());
      expect(user.id, 1);
      expect(user.fullName, 'Burt Macklin');
      expect(user.createdAt, createdAt);
    });

    test('it can find entities', () async {
      var createdAt = new DateTime.now();
      await repo.put(new User(1, 'Burt Macklin', createdAt));
      await repo.put(new User(2, 'Johnny Karate', createdAt));
      await repo.put(new User(3, 'Deadpool', createdAt));
      var criteria = new Criteria<User>();
      criteria.where((u) => u.fullName == 'Deadpool');
      var result = await repo.find(criteria).toList();
      expect(result, hasLength(1));
      expect(result.first.fullName, 'Deadpool');
    });

    test('it can findOne entity', () async {
      var createdAt = new DateTime.now();
      await repo.put(new User(1, 'Burt Macklin', createdAt));
      await repo.put(new User(2, 'Johnny Karate', createdAt));
      await repo.put(new User(3, 'Deadpool', createdAt));
      var criteria = new Criteria<User>();
      criteria.where((u) => u.fullName == 'Deadpool');
      var result = await repo.findOne(criteria);
      expect(result, new isInstanceOf<User>());
      expect(result.fullName, 'Deadpool');
    });

    test('findOne returns null if not found', () async {
      var criteria = new Criteria<User>();
      criteria.where((u) => u.fullName == 'Green Lantern');
      var result = await repo.findOne(criteria);
      expect(result, isNull);
    });

    test('it can get batch of entities', () async {
      var createdAt = new DateTime.now();
      await repo.put(new User(1, 'Burt Macklin', createdAt));
      await repo.put(new User(2, 'Johnny Karate', createdAt));
      await repo.put(new User(3, 'Deadpool', createdAt));
      var result = await repo.batchGet([1, 3].toSet()).toList();
      expect(result, hasLength(2));
      expect(result.first.fullName, 'Burt Macklin');
      expect(result.last.fullName, 'Deadpool');
    });
  });
}
