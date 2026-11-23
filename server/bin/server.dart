import 'dart:io';

import 'package:nafa_server/nafa_server.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Démarrage : DATABASE_URL (ex. postgresql://nafa:motdepasse@localhost:5432/nafa)
/// et PORT (8080 par défaut). Placer un proxy HTTPS (Caddy, Nginx) devant.
Future<void> main() async {
  final url = Platform.environment['DATABASE_URL'];
  if (url == null || url.isEmpty) {
    stderr.writeln('DATABASE_URL manquant.');
    exit(64);
  }
  final api = NafaApi(Pool.withUrl(url));
  await api.migrate();
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(api.handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Serveur Nafa Élevage sur le port ${server.port}');
}
