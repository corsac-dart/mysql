library corsac_mysql.tests.all;

import 'mysql_test.dart' as mysql_test;
import 'repository_test.dart' as repo_test;

void main() {
  mysql_test.main();
  repo_test.main();
}
