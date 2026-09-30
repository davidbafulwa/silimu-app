import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Adresse permanente du serveur SILIMU.
///
/// L'adresse publique du site change quand la connexion de l'ordinateur
/// hôte est rétablie. Elle est donc publiée en un seul endroit, toujours
/// accessible, et l'application va la chercher toute seule : plus aucun
/// numéro de port ni adresse IP à saisir.
const String kAdresseOfficielle =
    'https://davidbafulwa.github.io/silimu-app/adresse-serveur.txt';

const String _cleUrl = 'silimu.url';
const String _cleDate = 'silimu.date_url';

/// Adresse de tout secours, utilisée seulement si la découverte automatique
/// échoue et qu'aucune adresse n'a encore été mémorisée. Aucune IP ni port
/// n'est nécessaire dans le fonctionnement normal.
const String kServeurParDefaut = String.fromEnvironment(
  'SILIMU_URL',
  defaultValue: 'https://davidbafulwa.github.io',
);

/// Renvoie l'adresse du serveur, ou une chaîne vide si elle est introuvable.
Future<String> adressePublique() async {
  try {
    final reponse = await http
        .get(Uri.parse('$kAdresseOfficielle?t=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 8));
    if (reponse.statusCode != 200) return '';
    var texte = (utf8.decode(reponse.bodyBytes)).trim();
    if (texte.startsWith('http')) {
      return texte.replaceAll(RegExp(r'/+$'), '');
    }
    // Le fichier peut être stocké en base64 par l'outil de publication
    try {
      texte = utf8.decode(base64Decode(texte)).trim();
      return texte.startsWith('http') ? texte.replaceAll(RegExp(r'/+$'), '') : '';
    } catch (_) {
      return '';
    }
  } catch (_) {
    return '';
  }
}

/// L'adresse à utiliser, dans l'ordre de préférence :
///   1. celle découverte automatiquement sur le site officiel,
///   2. celle memorisee lors du dernier lancement reussi,
///   3. celle compilee dans l'application.
Future<String> trouverServeur() async {
  final prefs = await SharedPreferences.getInstance();

  String? memorisee;
  final dateMemo = prefs.getString(_cleDate);
  if (dateMemo != null) {
    final age = DateTime.now().difference(DateTime.tryParse(dateMemo) ?? DateTime(2000));
    if (age.inMinutes < 120) {
      memorisee = prefs.getString(_cleUrl);
    }
  }

  final trouvee = await adressePublique();
  if (trouvee.isNotEmpty) {
    await prefs.setString(_cleUrl, trouvee);
    await prefs.setString(_cleDate, DateTime.now().toIso8601String());
    return trouvee;
  }
  return memorisee ?? kServeurParDefaut;
}

Future<void> memoriserServeur(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cleUrl, url);
  await prefs.setString(_cleDate, DateTime.now().toIso8601String());
}

String apiDepuisAdresse(String adresse) => ApiClient.normaliserServeur(adresse);