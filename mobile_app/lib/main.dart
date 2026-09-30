import 'package:flutter/material.dart';

import 'adresse.dart';
import 'api.dart';
import 'pages.dart';

const Color kNavy = Color(0xFF07303F);
const Color kNavyClair = Color(0xFF0C4A5E);
const Color kTeal = Color(0xFF0FB5B0);
const Color kSunset = Color(0xFFF47533);
const Color kSand = Color(0xFFF6F2EA);
const Color kEncre = Color(0xFF123140);
const String kLogo = 'assets/icon-512.png';

void main() {
  runApp(const SilimuApp());
}

/// Ombre douce réutilisée par les cartes.
List<BoxShadow> ombre(double force) => <BoxShadow>[
      BoxShadow(
        color: kNavy.withValues(alpha: 0.06 + force * 0.04),
        blurRadius: 18 + force * 10,
        offset: Offset(0, 6 + force * 4),
      ),
    ];

/// État de session : client API + passager connecté.
class Session extends ChangeNotifier {
  Session() : api = ApiClient(kServeurParDefaut);

  ApiClient api;

  Map<String, dynamic>? passager;
  String? erreur;
  bool adresseEnCours = true;

  bool get connecte => passager != null;

  /// Va chercher l'adresse du serveur toute seule, puis l'utilise.
  /// L'utilisateur n'a donc plus à saisir d'adresse ni de port.
  Future<void> demarrer() async {
    adresseEnCours = true;
    notifyListeners();
    final adresse = await trouverServeur();
    api.baseUrl = apiDepuisAdresse(adresse);
    adresseEnCours = false;
    notifyListeners();
  }

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
    if (base.isNotEmpty) {
      api.baseUrl = base;
      memoriserServeur(saisie.trim());
    }
    notifyListeners();
  }

  /// Force une nouvelle recherche d'adresse (bouton « Actualiser »).
  Future<void> rafraichirAdresse() async {
    adresseEnCours = true;
    notifyListeners();
    final adresse = await trouverServeur();
    if (adresse.isNotEmpty) {
      api.baseUrl = apiDepuisAdresse(adresse);
      await memoriserServeur(adresse);
    }
    adresseEnCours = false;
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
  void initState() {
    super.initState();
    // L'adresse du serveur est découverte automatiquement : l'application
    // n'a besoin ni d'adresse IP ni de port à saisir.
    _session.demarrer();
  }

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
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: kSand,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: kNavy,
          letterSpacing: -0.4,
        ),
        titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: kNavy),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kNavy),
        bodyMedium: const TextStyle(fontSize: 14, color: kEncre, height: 1.35),
        labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F7F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kTeal, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kNavy,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: kTeal.withValues(alpha: 0.16),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kNavy),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? kNavy : Colors.black45,
            size: 23,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x14073040), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kNavy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// Logo SILIMU sur fond blanc arrondi (comme l'icône de l'application).
class LogoSilimu extends StatelessWidget {
  final double taille;
  final bool surBlanc;
  const LogoSilimu({super.key, this.taille = 84, this.surBlanc = true});

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      kLogo,
      width: taille * 0.72,
      height: taille * 0.72,
      fit: BoxFit.contain,
    );
    if (!surBlanc) return logo;
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(taille * 0.28)),
      child: Center(child: logo),
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

  final _serveur = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();

  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final session = SessionPortee.lire(context);
    // L'adresse a été trouvée automatiquement au démarrage : on l'affiche,
    // l'utilisateur n'a rien à saisir.
    _serveur.text = session.api.baseUrl.replaceFirst(RegExp(r'/api$'), '');
  }

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

  /// Relance la recherche de l'adresse officielle du site.
  Future<void> _rechercherAdresse() async {
    final session = SessionPortee.lire(context);
    setState(() => _enCours = true);
    await session.rafraichirAdresse();
    if (!mounted) return;
    setState(() {
      _serveur.text = session.api.baseUrl.replaceFirst(RegExp(r'/api$'), '');
      _enCours = false;
    });
    _message('Adresse mise à jour : ${_serveur.text}');
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
    // On applique d'abord l'adresse saisie, on la teste ensuite : sinon on
    // vérifiait l'ancienne adresse et le test ne disait rien de la nouvelle.
    session.changerServeur(_serveur.text);
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C4A5E), kNavy, Color(0xFF04202B)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              const Center(child: LogoSilimu(taille: 92)),
              const SizedBox(height: 16),
              const Text(
                'SILIMU',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Réservez votre passage sur le lac Kivu',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xB8FFFFFF), fontSize: 13.5),
              ),
              const SizedBox(height: 26),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: ombre(1),
                ),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabBar(
                      controller: _tabs,
                      labelColor: kNavy,
                      unselectedLabelColor: Colors.black45,
                      indicatorColor: kSunset,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: const Color(0x14073040),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      tabs: const [Tab(text: 'Connexion'), Tab(text: 'Inscription')],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _serveur,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Adresse du serveur',
                        helperText: 'Trouvée automatiquement — aucune saisie nécessaire',
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.dns_outlined, color: kTeal),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Chercher l’adresse',
                              onPressed: _enCours ? null : _rechercherAdresse,
                              icon: const Icon(Icons.sync, color: kTeal),
                            ),
                            IconButton(
                              tooltip: 'Vérifier la connexion',
                              onPressed: _enCours ? null : _validerServeur,
                              icon: const Icon(Icons.wifi_tethering, color: kNavy),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _tabs,
                      builder: (context, _) => _tabs.index == 0
                          ? _formulaire(
                              champs: [
                                _champ(_telephone, 'Téléphone', Icons.phone_outlined, TextInputType.phone),
                                _champ(_motDePasse, 'Mot de passe', Icons.lock_outline, TextInputType.text, passe: true),
                              ],
                              action: 'Se connecter',
                              surAction: _connexion,
                            )
                          : _formulaire(
                              champs: [
                                _champ(_nom, 'Nom complet', Icons.person_outline, TextInputType.text),
                                _champ(_telephone, 'Téléphone', Icons.phone_outlined, TextInputType.phone),
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
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Atout(icone: Icons.qr_code_2, texte: 'Billet QR'),
                  SizedBox(width: 18),
                  _Atout(icone: Icons.payments_outlined, texte: 'Mobile Money'),
                  SizedBox(width: 18),
                  _Atout(icone: Icons.lock_outline, texte: 'Paiement sûr'),
                ],
              ),
            ],
          ),
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
        decoration: InputDecoration(labelText: libelle, prefixIcon: Icon(icone, color: kTeal)),
      ),
    );
  }

  Widget _formulaire({
    required List<Widget> champs,
    required String action,
    required Future<void> Function() surAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...champs,
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _enCours ? null : surAction,
          child: _enCours
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Text(action),
        ),
      ],
    );
  }
}

class _Atout extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Atout({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, color: kTeal, size: 20),
        const SizedBox(height: 4),
        Text(texte, style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 10.5)),
      ],
    );
  }
}
