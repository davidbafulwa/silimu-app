import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ErreurApi implements Exception {
  final String message;
  ErreurApi(this.message);

  @override
  String toString() => message;
}

/// Client de l'API SILIMU (Django REST Framework).
///
/// Authentification par jeton opaque : en-tête `Authorization: Jeton <valeur>`.
/// Aucun secret n'est stocké dans l'application.
class ApiClient {
  String baseUrl;
  String? jeton;

  ApiClient(this.baseUrl);

  /// Accepte « 10.225.101.106:8000 », « http://… » ou « https://…/api »
  /// et renvoie toujours une base API correcte.
  static String normaliserServeur(String saisie) {
    var s = saisie.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('/api')) return s;
    return '$s/api';
  }

  Map<String, String> get _entetes => <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (jeton != null && jeton!.isNotEmpty) 'Authorization': 'Jeton $jeton',
      };

  Uri _uri(String chemin, [Map<String, String>? params]) {
    final base = Uri.parse('$baseUrl$chemin');
    if (params == null || params.isEmpty) return base;
    return base.replace(queryParameters: params);
  }

  Future<dynamic> _envoyer(Future<http.Response> Function() requete) async {
    http.Response reponse;
    try {
      reponse = await requete().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ErreurApi('Le serveur met trop de temps à répondre.');
    } on Exception {
      throw ErreurApi("Serveur injoignable. Vérifie l'adresse du serveur.");
    }

    dynamic data;
    if (reponse.body.isNotEmpty) {
      try {
        data = jsonDecode(reponse.body);
      } on FormatException {
        data = null;
      }
    }

    if (reponse.statusCode >= 200 && reponse.statusCode < 300) {
      return data;
    }
    throw ErreurApi(_messageErreur(data, reponse.statusCode));
  }

  String _messageErreur(dynamic data, int statut) {
    if (data is Map) {
      final erreur = data['erreur'];
      if (erreur is String && erreur.isNotEmpty) return erreur;
      if (erreur is List && erreur.isNotEmpty) return erreur.first.toString();
    }
    if (statut == 401 || statut == 403) {
      return 'Session expirée, reconnecte-toi.';
    }
    return 'Erreur du serveur ($statut).';
  }

  /// L'API renvoie soit une liste simple, soit une page
  /// {count, results} / {count, resultats} : on accepte les deux.
  static List<dynamic> liste(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final r = data['results'];
      if (r is List) return r;
      final a = data['resultats'];
      if (a is List) return a;
    }
    return <dynamic>[];
  }

  static Map<String, dynamic> carte(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ---------- Ports & traversées ----------

  Future<List<dynamic>> ports() async {
    final data = await _envoyer(() => http.get(_uri('/ports/'), headers: _entetes));
    return liste(data);
  }

  Future<List<dynamic>> traversees({
    int? portDepart,
    int? portArrivee,
    String? dateMin,
  }) async {
    final params = <String, String>{};
    if (portDepart != null) params['port_depart'] = '$portDepart';
    if (portArrivee != null) params['port_arrivee'] = '$portArrivee';
    if (dateMin != null && dateMin.isNotEmpty) params['date_min'] = dateMin;
    final data = await _envoyer(
      () => http.get(_uri('/traversees/', params), headers: _entetes),
    );
    return liste(data);
  }

  // ---------- Compte ----------

  Future<Map<String, dynamic>> inscription({
    required String nomComplet,
    required String telephone,
    String? email,
    required String motDePasse,
    String appareil = 'mobile',
  }) async {
    final data = await _envoyer(
      () => http.post(
        _uri('/auth/inscription/'),
        headers: _entetes,
        body: jsonEncode(<String, dynamic>{
          'nom_complet': nomComplet,
          'telephone': telephone,
          'email': email ?? '',
          'mot_de_passe': motDePasse,
          'appareil': appareil,
        }),
      ),
    );
    final map = carte(data);
    final jeton = map['jeton'];
    if (jeton is String) this.jeton = jeton;
    return map;
  }

  Future<Map<String, dynamic>> connexion(
    String telephone,
    String motDePasse, {
    String appareil = 'mobile',
  }) async {
    final data = await _envoyer(
      () => http.post(
        _uri('/auth/connexion/'),
        headers: _entetes,
        body: jsonEncode(<String, dynamic>{
          'telephone': telephone,
          'mot_de_passe': motDePasse,
          'appareil': appareil,
        }),
      ),
    );
    final map = carte(data);
    final jeton = map['jeton'];
    if (jeton is String) this.jeton = jeton;
    return map;
  }

  Future<void> deconnexion() async {
    if (jeton == null || jeton!.isEmpty) return;
    try {
      await _envoyer(
        () => http.post(_uri('/auth/deconnexion/'), headers: _entetes, body: '{}'),
      );
    } on Exception {
      // Déconnexion locale dans tous les cas.
    }
  }

  Future<Map<String, dynamic>> moi() async {
    final data = await _envoyer(() => http.get(_uri('/auth/moi/'), headers: _entetes));
    return carte(data);
  }

  // ---------- Billets ----------

  Future<Map<String, dynamic>> mesBillets() async {
    final data = await _envoyer(
      () => http.get(_uri('/reservations/mes/'), headers: _entetes),
    );
    return carte(data);
  }

  Future<Map<String, dynamic>> creerReservation({
    required int traversee,
    required String nomPassager,
    required String telephone,
    String? email,
    required int nbPlaces,
    required String modePaiement,
  }) async {
    final data = await _envoyer(
      () => http.post(
        _uri('/reservations/'),
        headers: _entetes,
        body: jsonEncode(<String, dynamic>{
          'traversee': traversee,
          'nom_passager': nomPassager,
          'telephone': telephone,
          'email': email ?? '',
          'nb_places': nbPlaces,
          'mode_paiement': modePaiement,
        }),
      ),
    );
    return carte(data);
  }

  Future<Map<String, dynamic>> billetParCode(String code) async {
    final data = await _envoyer(
      () => http.get(_uri('/reservations/$code/'), headers: _entetes),
    );
    return carte(data);
  }

  Future<void> annulerBillet(String code) async {
    await _envoyer(
      () => http.post(_uri('/reservations/$code/annuler/'), headers: _entetes, body: '{}'),
    );
  }
}
