/// MySQL bindings for Corsac projects.
library corsac_mysql.base;

import 'package:corsac_kernel/corsac_kernel.dart';
import 'package:corsac_mysql/corsac_mysql.dart';
import 'package:corsac_console/corsac_console.dart';
import 'dart:async';

part 'src/base/console_commands.dart';

/// Default kernel module for MySQL.
class MySQLKernelModule extends KernelModule {
  /// Name of environment variable containg mysql connection URI.
  ///
  /// Example of an URI: `mysql://user:pass@mysqlhost:3306/dbname`.
  final String mysqlUriEnvVariableName = 'MYSQL_CONNECTION_URI';

  /// List of types of MySQL migrations.
  final List<Type> migrations = [];

  Map getServiceConfiguration(String environment) {
    return {
      // Dynamic lists
      'console.commands': DI.add([DI.get(MySQLCommand)]),
      'mysql.migrations': migrations.map((m) => DI.get(m)),

      // Services
      MySQL: DI.object()
        ..constructor = 'fromUri'
        ..bindParameter('uri', DI.env(mysqlUriEnvVariableName)),

      // Console commands
      MySQLMigrateCommand: DI.object()
        ..bindParameter('migrations', DI.get('mysql.migrations')),
    };
  }
}

/// Interface for MySQL schema migrations.
abstract class MySQLMigration {
  Future migrate();
}
