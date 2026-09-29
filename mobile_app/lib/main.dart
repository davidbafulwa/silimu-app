import 'package:flutter/material.dart';

import 'api.dart';
import 'pages.dart';

/// Adresse du serveur par défaut au premier lancement.
/// Sur un téléphone réel, l'utilisateur la change dans l'écran de connexion
/// (par exemple http://192.168.1.10:8000). Sur l'émulateur Android,
/// la machine hôte est accessible via 10.0.2.2.
const String kServeurParDefaut = String.fromEnvironment(
  'SILIMU_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

const Color kNavy = Color(0xFF07303F);
const Color kTeal = Color(0xFF0FB5B0);
const Color kSunset = Color(0xFFF47533);
const Color kSand = Color(0xFFF6F2EA);
const Color kEncre = Color(0xFF123140);

void main() {
  runApp(const SilimuApp());
}

/// État de session : client API + passager connecté.
class Session extends ChangeNotifier {
  Session() : api = ApiClient(kServeurParDefaut);

  ApiClient api;

  Map<String, dynamic>? passager;
  String? erreur;

  bool get connecte => passager != null;

  void ouvrir(Map<String, dynamic> reponse) {
    final p = reponse['passager'];
    if (p is Map) passager = Map<String, dynamic>.from(p);
    erreur = null;
    notifyListeners();
  }

  void definirErreur(String message) {
    erreur = message;
    notifyListeners();
  }

  void changerServeur(String saisie) {
    final base = ApiClient.normaliserServeur(saisie);
    if (base.isNotEmpty) api.baseUrl = base;
    notifyListeners();
  }

  void fermer() {
    api.deconnexion();
    api.jeton = null;
    passager = null;
    notifyListeners();
  }
}

class SessionPortee extends InheritedNotifier<Session> {
  const SessionPortee({super.key, required Session session, required super.child})
      : super(notifier: session);

  static Session lire(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionPortee>()!.notifier!;
}

class SilimuApp extends StatefulWidget {
  const SilimuApp({super.key});

  @override
  State<SilimuApp> createState() => _SilimuAppState();
}

class _SilimuAppState extends State<SilimuApp> {
  final Session _session = Session();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  ThemeData get _theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kNavy).copyWith(
        primary: kNavy,
        secondary: kTeal,
      ),
      scaffoldBackgroundColor: kSand,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kNavy,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionPortee(
      session: _session,
      child: AnimatedBuilder(
        animation: _session,
        builder: (context, _) => MaterialApp(
          title: 'SILIMU',
          debugShowCheckedModeBanner: false,
          theme: _theme,
          home: _session.connecte ? const PageAccueil() : const PageConnexion(),
        ),
      ),
    );
  }
}

/// Écran de connexion / inscription.
class PageConnexion extends StatefulWidget {
  const PageConnexion({super.key});

  @override
  State<PageConnexion> createState() => _PageConnexionState();
}

class _PageConnexionState extends State<PageConnexion>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _serveur = TextEditingController(text: kServeurParDefaut);
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();

  bool _enCours = false;

  @override
  void dispose() {
    _tabs.dispose();
    _serveur.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    _nom.dispose();
    _email.dispose();
    super.dispose();
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _validerServeur() async {
    final session = SessionPortee.lire(context);
    final base = ApiClient.normaliserServeur(_serveur.text);
    if (base.isEmpty) {
      _message('Indique l’adresse du serveur.');
      return;
    }
    setState(() => _enCours = true);
    try {
      await session.api.ports();
      session.changerServeur(_serveur.text);
      _message('Serveur joignable : $base');
    } on ErreurApi catch (e) {
      session.changerServeur(_serveur.text);
      _message(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _connexion() async {
    final session = SessionPortee.lire(context);
    setState(() => _enCours = true);
    try {
      final reponse = await session.api.connexion(
        _telephone.text.trim(),
        _motDePasse.text,
      );
      session.ouvrir(reponse);
    } on ErreurApi catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _inscription() async {
    final session = SessionPortee.lire(context);
    setState(() => _enCours = true);
    try {
      final reponse = await session.api.inscription(
        nomComplet: _nom.text.trim(),
        telephone: _telephone.text.trim(),
        email: _email.text.trim(),
        motDePasse: _motDePasse.text,
      );
      session.ouvrir(reponse);
      _message('Compte créé. Bienvenue à bord !');
    } on ErreurApi catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'SILIMU',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Transport lacustre — Kivu & Tanganyika',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xB8FFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    controller: _tabs,
                    labelColor: kNavy,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: kSunset,
                    tabs: const [Tab(text: 'Connexion'), Tab(text: 'Inscription')],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _serveur,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Adresse du serveur',
                      hintText: 'http://192.168.1.10:8000',
                      suffixIcon: IconButton(
                        tooltip: 'Vérifier',
                        onPressed: _enCours ? null : _validerServeur,
                        icon: const Icon(Icons.wifi_tethering),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _tabs,
                    builder: (context, _) => _tabs.index == 0
                        ? _formulaire(
                            champs: [
                              _champ(_telephone, 'Téléphone', Icons.phone, TextInputType.phone),
                              _champ(_motDePasse, 'Mot de passe', Icons.lock_outline, TextInputType.text, passe: true),
                            ],
                            action: 'Se connecter',
                            surAction: _connexion,
                          )
                        : _formulaire(
                            champs: [
                              _champ(_nom, 'Nom complet', Icons.person_outline, TextInputType.text),
                              _champ(_telephone, 'Téléphone', Icons.phone, TextInputType.phone),
                              _champ(_email, 'E-mail (optionnel)', Icons.mail_outline, TextInputType.emailAddress),
                              _champ(_motDePasse, 'Mot de passe (8 caractères)', Icons.lock_outline, TextInputType.text, passe: true),
                            ],
                            action: 'Créer mon compte',
                            surAction: _inscription,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _champ(
    TextEditingController controleur,
    String libelle,
    IconData icone,
    TextInputType type, {
    bool passe = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controleur,
        obscureText: passe,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: libelle,
          prefixIcon: Icon(icone),
        ),
      ),
    );
  }

  Widget _formulaire({
    required List<Widget> champs,
    required String action,
    required Future<void> Function() surAction,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...champs,
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _enCours ? null : surAction,
            child: _enCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(action),
          ),
        ],
      ),
    );
  }
}
