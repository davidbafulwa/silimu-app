import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';

// ================= Utilitaires d'affichage =================

String montant(dynamic valeur) {
  var n = 0;
  if (valeur is num) {
    n = valeur.round();
  } else {
    n = double.tryParse('${valeur ?? ''}'.replaceAll(' ', ''))?.round() ?? 0;
  }
  final chiffres = n.toString();
  final tampon = StringBuffer();
  for (var k = 0; k < chiffres.length; k++) {
    if (k > 0 && (chiffres.length - k) % 3 == 0) tampon.write(' ');
    tampon.write(chiffres[k]);
  }
  return '${tampon.toString()} FC';
}

String dateFr(dynamic iso) {
  if (iso == null) return '';
  final s = iso.toString();
  if (s.length < 10) return s;
  final base = '${s.substring(8, 10)}/${s.substring(5, 7)}/${s.substring(0, 4)}';
  if (s.length >= 16) return '$base à ${s.substring(11, 16)}';
  return base;
}

String libelleStatut(String code) {
  switch (code) {
    case 'PROGAMMEE':
      return 'Programmée';
    case 'EN_COURS':
      return 'En cours';
    case 'COMPLETE':
      return 'Terminée';
    case 'ANNULEE':
      return 'Annulée';
    case 'EN_ATTENTE':
      return 'En attente de paiement';
    case 'CONFIRME':
      return 'Confirmé';
    case 'PAYE':
      return 'Payé';
    case 'EMBARQUE':
      return 'Embarqué';
    default:
      return code.isEmpty ? '—' : code.replaceAll('_', ' ').toLowerCase();
  }
}

Color couleurStatut(String code) {
  if (code == 'ANNULEE') return const Color(0xFF9B2C2C);
  if (code == 'EMBARQUE' || code == 'PAYE' || code == 'CONFIRME') return const Color(0xFF146C43);
  return kSunset;
}

Map<String, dynamic> _objet(dynamic valeur) {
  if (valeur is Map) return Map<String, dynamic>.from(valeur);
  return <String, dynamic>{};
}

String _nomPort(Map<String, dynamic> route, String cle) {
  final port = _objet(route[cle]);
  if (port.isEmpty) return '';
  return (port['nom'] ?? port['ville'] ?? '').toString();
}

class Traversee {
  final Map<String, dynamic> brut;
  Traversee(this.brut);

  int get id => (brut['id'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get route => _objet(brut['route']);
  Map<String, dynamic> get bateau => _objet(brut['bateau']);
  String get date => dateFr(brut['date']);
  String get heure {
    final h = (brut['heure'] ?? '').toString();
    return h.length >= 5 ? h.substring(0, 5) : h;
  }
  String get prix => montant(brut['prix']);
  num get prixNum {
    final v = brut['prix'];
    if (v is num) return v;
    return double.tryParse('${v ?? ''}'.replaceAll(' ', '')) ?? 0;
  }
  String get codeStatut => (brut['statut'] ?? '').toString();
  String get statut => libelleStatut(codeStatut);
  int get places => (brut['places_disponibles'] as num?)?.toInt() ?? 0;
  String get depart => _nomPort(route, 'port_depart');
  String get arrivee => _nomPort(route, 'port_arrivee');
  String get nomBateau => (bateau['nom'] ?? 'Bateau').toString();
  String get duree {
    final minutes = (route['duree_min'] as num?)?.toInt();
    if (minutes == null) return '';
    return '$minutes min';
  }
}

// ================= Accueil (onglets) =================

class PageAccueil extends StatefulWidget {
  const PageAccueil({super.key});

  @override
  State<PageAccueil> createState() => _PageAccueilState();
}

class _PageAccueilState extends State<PageAccueil> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = SessionPortee.lire(context);
    final passager = _objet(session.passager);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SILIMU', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                (passager['nom_complet'] ?? '').toString(),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      body: switch (_index) {
        1 => const OngletBillets(),
        2 => const OngletCompte(),
        _ => const OngletTraversees(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_boat_outlined), label: 'Traversées'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'Mes billets'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Compte'),
        ],
      ),
    );
  }
}

class OngletTraversees extends StatefulWidget {
  const OngletTraversees({super.key});

  @override
  State<OngletTraversees> createState() => _OngletTraverseesState();
}

class _OngletTraverseesState extends State<OngletTraversees> {
  List<dynamic> _ports = <dynamic>[];
  List<Traversee> _traversees = <Traversee>[];
  int? _depart;
  int? _arrivee;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final session = SessionPortee.lire(context);
    try {
      final ports = await session.api.ports();
      var depart = _depart;
      var arrivee = _arrivee;
      if (ports.length >= 2) {
        final premier = (ports.first as Map)['id'] as int;
        final second = (ports[1] as Map)['id'] as int;
        depart ??= premier;
        arrivee ??= second;
      } else if (ports.length == 1) {
        depart ??= (ports.first as Map)['id'] as int;
      }
      final data = await session.api.traversees(portDepart: depart, portArrivee: arrivee);
      if (!mounted) return;
      setState(() {
        _ports = ports;
        _depart = depart;
        _arrivee = arrivee;
        _traversees = data
            .whereType<Map>()
            .map((m) => Traversee(Map<String, dynamic>.from(m)))
            .toList();
        _chargement = false;
      });
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  int? _idPort(Map p) => (p['id'] as num?)?.toInt();

  Widget _selecteurPort(String libelle, int? valeur, ValueChanged<int?> choisir) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(libelle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: valeur,
              items: _ports
                  .whereType<Map>()
                  .map((p) => DropdownMenuItem<int>(
                        value: _idPort(p),
                        child: Text('${p['nom']}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => choisir(v)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_erreur != null)
            _bandeauErreur(_erreur!, _charger)
          else ...[
            Row(
              children: [
                Expanded(child: _selecteurPort('Départ', _depart, (v) => _depart = v)),
                const SizedBox(width: 10),
                Expanded(child: _selecteurPort('Arrivée', _arrivee, (v) => _arrivee = v)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _charger,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher les traversées'),
            ),
            const SizedBox(height: 18),
            if (_traversees.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune traversée programmée pour cet itinéraire.'),
              ),
            ..._traversees.map(_carteTraversee),
          ],
        ],
      ),
    );
  }

  Widget _carteTraversee(Traversee t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kNavy.withValues(alpha: .08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PageDetailTraversee(traversee: t)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.date, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: couleurStatut(t.codeStatut).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.statut,
                      style: TextStyle(
                        color: couleurStatut(t.codeStatut),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${t.depart}  →  ${t.arrivee}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kNavy),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.heure} • ${t.nomBateau}${t.duree.isEmpty ? '' : ' • ${t.duree}'}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${t.places} place(s) restante(s)',
                    style: const TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w700),
                  ),
                  Text(t.prix, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kSunset)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _bandeauErreur(String message, VoidCallback reessayer) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFDECEC),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: Color(0xFF9B2C2C))),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: reessayer, child: const Text('Réessayer')),
      ],
    ),
  );
}

// ================= Détail d'une traversée =================

class PageDetailTraversee extends StatelessWidget {
  final Traversee traversee;
  const PageDetailTraversee({super.key, required this.traversee});

  @override
  Widget build(BuildContext context) {
    final t = traversee;
    return Scaffold(
      appBar: AppBar(title: const Text('Traversée')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('${t.depart} → ${t.arrivee}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 6),
          Text('${t.date} à ${t.heure}'),
          const SizedBox(height: 18),
          _ligne(Icons.directions_boat, 'Bateau', t.nomBateau),
          _ligne(Icons.schedule, 'Durée', t.duree.isEmpty ? '—' : t.duree),
          _ligne(Icons.event_seat, 'Places disponibles', '${t.places}'),
          _ligne(Icons.confirmation_number, 'Statut', t.statut),
          _ligne(Icons.payments_outlined, 'Prix par place', t.prix),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: t.places <= 0 || t.codeStatut == 'ANNULEE'
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PageReservation(traversee: t),
                      ),
                    ),
            child: Text(t.places <= 0 ? 'Complet' : 'Réserver'),
          ),
        ],
      ),
    );
  }

  Widget _ligne(IconData icone, String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icone, size: 20, color: kTeal),
          const SizedBox(width: 12),
          Text('$libelle : ', style: const TextStyle(color: Colors.black54)),
          Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

// ================= Réservation =================

class PageReservation extends StatefulWidget {
  final Traversee traversee;
  const PageReservation({super.key, required this.traversee});

  @override
  State<PageReservation> createState() => _PageReservationState();
}

class _PageReservationState extends State<PageReservation> {
  late final TextEditingController _nom;
  late final TextEditingController _telephone;
  late final TextEditingController _email;
  int _places = 1;
  String _paiement = 'ORANGE_MONEY';
  bool _enCours = false;

  static const _paiements = <String, String>{
    'ORANGE_MONEY': 'Orange Money',
    'AIRTEL_MONEY': 'Airtel Money',
    'MPESA': 'M-Pesa',
    'CARTE': 'Carte bancaire',
    'ESPECES': 'Espèces (comptoir)',
  };

  @override
  void initState() {
    super.initState();
    final passager = _objet(SessionPortee.lire(context).passager);
    _nom = TextEditingController(text: (passager['nom_complet'] ?? '').toString());
    _telephone = TextEditingController(text: (passager['telephone'] ?? '').toString());
    _email = TextEditingController(text: (passager['email'] ?? '').toString());
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _reserver() async {
    if (_nom.text.trim().length < 3) {
      _message('Indique ton nom complet.');
      return;
    }
    if (_telephone.text.trim().length < 8) {
      _message('Indique un numéro de téléphone valide.');
      return;
    }
    setState(() => _enCours = true);
    final session = SessionPortee.lire(context);
    try {
      final billet = await session.api.creerReservation(
        traversee: widget.traversee.id,
        nomPassager: _nom.text.trim(),
        telephone: _telephone.text.trim(),
        email: _email.text.trim(),
        nbPlaces: _places,
        modePaiement: _paiement,
      );
      if (!mounted) return;
      _confirmerBillet(billet);
    } on ErreurApi catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  void _confirmerBillet(Map<String, dynamic> billet) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réservation enregistrée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ton code de billet :'),
            const SizedBox(height: 10),
            SelectableText(
              (billet['code'] ?? '—').toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kNavy),
            ),
            const SizedBox(height: 12),
            Text('Total : ${montant(billet['total'])}'),
            Text('Statut : ${libelleStatut((billet['statut'] ?? '').toString())}'),
            const SizedBox(height: 10),
            const Text(
              'Passe à l\'embarquement avec ce code : il sera vérifié par le contrôleur.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.traversee;
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('${t.depart} → ${t.arrivee}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
          Text('${t.date} à ${t.heure} • ${t.nomBateau}'),
          const SizedBox(height: 20),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom du passager')),
          const SizedBox(height: 12),
          TextField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail (pour recevoir le billet)'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Nombre de places', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: _places > 1 ? () => setState(() => _places--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_places', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: _places < (t.places <= 0 ? 1 : t.places)
                    ? () => setState(() => _places++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _paiement,
                items: _paiements.entries
                    .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _paiement = v ?? _paiement),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enCours ? null : _reserver,
            child: _enCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Réserver ${montant(t.prixNum * _places)}'),
          ),
          const SizedBox(height: 10),
          const Text(
            'La réservation est « en attente » jusqu\'au paiement. Vérifie bien ton code avant de rejoindre le port.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ================= Mes billets =================

class OngletBillets extends StatefulWidget {
  const OngletBillets({super.key});

  @override
  State<OngletBillets> createState() => _OngletBilletsState();
}

class _OngletBilletsState extends State<OngletBillets> {
  Future<List<Map<String, dynamic>>>? _futur;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_futur == null) _futur = _charger();
  }

  Future<List<Map<String, dynamic>>> _charger() async {
    final session = SessionPortee.lire(context);
    if (!session.connecte) return <Map<String, dynamic>>[];
    final data = await session.api.mesBillets();
    return ApiClient.liste(data['resultats'] ?? data['results'])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  void _rafraichir() {
    setState(() => _futur = _charger());
  }

  Future<void> _annuler(Map<String, dynamic> billet) async {
    final code = (billet['code'] ?? '').toString();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler ce billet ?'),
        content: Text('Le billet $code sera annulé et la place libérée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Garder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler le billet'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final session = SessionPortee.lire(context);
    try {
      await session.api.annulerBillet(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Billet $code annulé.')));
      _rafraichir();
    } on ErreurApi catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionPortee.lire(context);
    if (!session.connecte) {
      return const Center(child: Text('Connecte-toi pour retrouver tes billets.'));
    }
    return RefreshIndicator(
      onRefresh: () async => _rafraichir(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futur,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _bandeauErreur('${snapshot.error}', _rafraichir),
              ],
            );
          }
          final billets = snapshot.data ?? <Map<String, dynamic>>[];
          if (billets.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('Aucun billet pour le moment.')),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: billets.length,
            itemBuilder: (context, index) {
              final billet = billets[index];
              final traversee = Traversee(_objet(billet['traversee']));
              final code = (billet['code'] ?? '').toString();
              final statut = (billet['statut'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: kNavy.withValues(alpha: .08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            code,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kNavy,
                            ),
                          ),
                          Text(
                            libelleStatut(statut),
                            style: TextStyle(
                              color: couleurStatut(statut),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${traversee.depart} → ${traversee.arrivee}'),
                      Text(
                        '${traversee.date} à ${traversee.heure} • ${billet['nb_places']} place(s)',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total : ${montant(billet['total'])}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: kSunset),
                      ),
                      if (statut != 'ANNULE' && statut != 'EMBARQUE') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _annuler(billet),
                            child: const Text('Annuler ce billet'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ================= Compte =================

class OngletCompte extends StatelessWidget {
  const OngletCompte({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionPortee.lire(context);
    final passager = _objet(session.passager);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (passager['nom_complet'] ?? 'Passager').toString(),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy),
                ),
                const SizedBox(height: 6),
                Text('Téléphone : ${passager['telephone'] ?? '—'}'),
                Text('E-mail : ${passager['email'] != null && (passager['email'] as String).isNotEmpty ? passager['email'] : '—'}'),
                Text('Membre depuis : ${dateFr(passager['date_inscription'])}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.dns_outlined, color: kTeal),
            title: const Text('Serveur connecté'),
            subtitle: Text(session.api.baseUrl),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => session.fermer(),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}
