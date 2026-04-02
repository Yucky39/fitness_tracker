import 'database_interface.dart';

DatabaseAdapter createDatabaseAdapter() {
  throw UnsupportedError('Cannot create database adapter without dart:io or dart:html');
}
