part of corsac_mysql.base;

/// Base console command for MySQL operations.
class MySQLCommand extends Command {
  @override
  String get description => 'MySQL utility commands';

  @override
  String get name => 'mysql';

  MySQLCommand(MySQLMigrateCommand migrate) {
    addSubcommand(migrate);
  }
}

/// Command to run all registered schema migrations.
class MySQLMigrateCommand extends Command {
  @override
  String get description => 'Migrates MySQL storage schemas to latest version.';

  @override
  String get name => 'migrate';

  final List<MySQLMigration> migrations;

  MySQLMigrateCommand(this.migrations);

  @override
  Future run() async {
    for (var migration in migrations) {
      await migration.migrate();
    }
  }
}
