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
      return 'En attente';
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
  if (code == 'ANNULEE') return const Color(0xFFB3261E);
  if (code == 'EMBARQUE' || code == 'PAYE' || code == 'CONFIRME') return const Color(0xFF0E7C4A);
  return kSunset;
}

Map<String, dynamic> objet(dynamic valeur) {
  if (valeur is Map) return Map<String, dynamic>.from(valeur);
  return <String, dynamic>{};
}

String nomPort(Map<String, dynamic> route, String cle) {
  final port = objet(route[cle]);
  if (port.isEmpty) return '';
  return (port['nom'] ?? port['ville'] ?? '').toString();
}

String initiales(String nom) {
  final morceaux = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (morceaux.isEmpty) return '?';
  if (morceaux.length == 1) return morceaux.first.substring(0, 1).toUpperCase();
  return (morceaux.first.substring(0, 1) + morceaux[1].substring(0, 1)).toUpperCase();
}

/// Pastille de statut colorée.
class Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  const Pastille(this.texte, this.couleur, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: couleur.withValues(alpha: 0.22)),
      ),
      child: Text(
        texte,
        style: TextStyle(color: couleur, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class Traversee {
  final Map<String, dynamic> brut;
  Traversee(this.brut);

  int get id => (brut['id'] as num?)?.toInt() ?? 0;
  Map<String, dynamic> get route => objet(brut['route']);
  Map<String, dynamic> get bateau => objet(brut['bateau']);
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
  bool get reserveable => places > 0 && codeStatut != 'ANNULEE' && codeStatut != 'COMPLETE';
  String get depart => nomPort(route, 'port_depart');
  String get arrivee => nomPort(route, 'port_arrivee');
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
    return Scaffold(
      body: Column(
        children: [
          const EnTeteSilimu(),
          Expanded(
            child: switch (_index) {
              1 => const OngletBillets(),
              2 => const OngletCompte(),
              _ => const OngletTraversees(),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_boat_outlined),
            selectedIcon: Icon(Icons.directions_boat, color: kNavy),
            label: 'Traversées',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number, color: kNavy),
            label: 'Mes billets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: kNavy),
            label: 'Compte',
          ),
        ],
      ),
    );
  }
}

/// En-tête dégradé avec le logo SILIMU.
class EnTeteSilimu extends StatelessWidget {
  const EnTeteSilimu({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionPortee.lire(context);
    final nom = (objet(session.passager)['nom_complet'] ?? '').toString();
    final morceaux = nom.split(' ');
    final prenom = morceaux.first;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavy, kNavyClair],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Row(
            children: [
              const LogoSilimu(taille: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SILIMU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prenom.isEmpty ? 'Réservez votre passage' : 'Bonjour $prenom',
                      style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.waves, color: kTeal, size: 15),
                    SizedBox(width: 5),
                    Text('Kivu', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        depart ??= (ports.first as Map)['id'] as int;
        arrivee ??= (ports[1] as Map)['id'] as int;
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Text(
              libelle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: valeur,
                borderRadius: BorderRadius.circular(14),
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
      ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: ombre(0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _selecteurPort('DÉPART', _depart, (v) => _depart = v),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 18, color: kSunset),
                    ),
                    _selecteurPort('ARRIVÉE', _arrivee, (v) => _arrivee = v),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _charger,
                  icon: const Icon(Icons.search, size: 19),
                  label: const Text('Rechercher'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_erreur != null)
            BandeauErreur(_erreur!, _charger)
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _traversees.isEmpty
                      ? 'Aucune traversée'
                      : '${_traversees.length} traversée${_traversees.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNavy),
                ),
                const Text('par place', style: TextStyle(fontSize: 11.5, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 12),
            if (_traversees.isEmpty)
              const _Vide(message: 'Aucune traversée programmée pour cet itinéraire.\nChange d’itinéraire ou réessaie plus tard.')
            else
              ..._traversees.map(_carteTraversee),
          ],
        ],
      ),
    );
  }

  Widget _carteTraversee(Traversee t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: ombre(0.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: kTeal),
                        const SizedBox(width: 6),
                        Text(
                          t.date,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: kNavy, fontSize: 13.5),
                        ),
                      ],
                    ),
                    Pastille(t.statut, couleurStatut(t.codeStatut)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        t.depart,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kNavy),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 20, color: kSunset),
                    ),
                    Expanded(
                      child: Text(
                        t.arrivee,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kNavy),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.black38),
                    const SizedBox(width: 5),
                    Text(t.heure, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                    const SizedBox(width: 12),
                    const Icon(Icons.directions_boat_outlined, size: 14, color: Colors.black38),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        t.nomBateau,
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${t.places} place${t.places > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0A6E6A)),
                      ),
                    ),
                    Text(
                      t.prix,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSunset),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BandeauErreur extends StatelessWidget {
  final String message;
  final VoidCallback reessayer;
  const BandeauErreur(this.message, this.reessayer, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFB3261E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFF8C1D18), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: reessayer, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  final String message;
  const _Vide({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.directions_boat_outlined, size: 44, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black45, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kNavy, kNavyClair],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.date,
                      style: const TextStyle(
                        color: Color(0xB8FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Pastille(t.statut, Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${t.depart}  →  ${t.arrivee}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${t.heure}  •  ${t.nomBateau}',
                  style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _statutBloc('Départ', t.heure, Icons.schedule),
                    ),
                    Expanded(
                      child: _statutBloc('Durée', t.duree.isEmpty ? '—' : t.duree, Icons.timelapse),
                    ),
                    Expanded(
                      child: _statutBloc('Places', '${t.places}', Icons.event_seat),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: ombre(0.4),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Prix par place', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    Text(
                      t.prix,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kSunset),
                    ),
                  ],
                ),
                if (t.places > 0 && t.places <= 5) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSunset.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Dernière minute : il ne reste que ${t.places} place${t.places > 1 ? 's' : ''}.',
                      style: const TextStyle(color: Color(0xFFA8471B), fontSize: 12.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: t.reserveable
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => PageReservation(traversee: t)),
                    )
                : null,
            child: Text(t.reserveable ? 'Réserver cette traversée' : 'Réservation indisponible'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Le billet est « en attente » jusqu’au paiement. Présente ton code au contrôleur à l’embarquement.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statutBloc(String libelle, String valeur, IconData icone) {
    return Column(
      children: [
        Icon(icone, color: kTeal, size: 19),
        const SizedBox(height: 5),
        Text(valeur, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(libelle, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5)),
      ],
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
    final passager = objet(SessionPortee.lire(context).passager);
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

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _reserver() async {
    if (_nom.text.trim().length < 3) {
      _message('Indique ton nom complet.');
      return;
    }
    if (_telephone.text.trim().length < 8) {
      _message('Indice un numéro de téléphone valide.');
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

  void _confirmerBillet(Map<String, dynamic> billet) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF0E7C4A)),
            SizedBox(width: 10),
            Expanded(child: Text('Réservation enregistrée')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ton code de billet', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kSand,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kTeal.withValues(alpha: 0.35), width: 1.4),
              ),
              child: SelectableText(
                (billet['code'] ?? '—').toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total à payer', style: TextStyle(fontSize: 13.5)),
                Text(
                  montant(billet['total']),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSunset),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Statut', style: TextStyle(fontSize: 13.5)),
                Text(
                  libelleStatut((billet['statut'] ?? '').toString()),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: couleurStatut((billet['statut'] ?? '').toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Conserve ce code : il sera vérifié à l’embarquement.',
              style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: ombre(0.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.depart} → ${t.arrivee}',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: kNavy)),
                const SizedBox(height: 4),
                Text('${t.date} à ${t.heure} • ${t.nomBateau}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Passager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 10),
          TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(
            controller: _telephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail (pour recevoir le billet)',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Places', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Text('Nombre de places', style: TextStyle(fontSize: 14)),
                const Spacer(),
                IconButton(
                  onPressed: _places > 1 ? () => setState(() => _places--) : null,
                  icon: const Icon(Icons.remove_circle_outline, color: kNavy),
                ),
                Text('$_places', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
                IconButton(
                  onPressed: _places < t.places ? () => setState(() => _places++) : null,
                  icon: const Icon(Icons.add_circle_outline, color: kNavy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _paiement,
                borderRadius: BorderRadius.circular(14),
                items: _paiements.entries
                    .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _paiement = v ?? _paiement),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enCours ? null : _reserver,
            child: _enCours
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text('Réserver • ${montant(t.prixNum * _places)}'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler ce billet ?'),
        content: Text('Le billet $code sera annulé et la place remise en vente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler'),
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
      return const _Vide(message: 'Connecte-toi pour retrouver tes billets.');
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
              children: [BandeauErreur('${snapshot.error}', _rafraichir)],
            );
          }
          final billets = snapshot.data ?? <Map<String, dynamic>>[];
          if (billets.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 20),
                _Vide(message: 'Aucun billet pour le moment.\nRéserve ta première traversée depuis l’onglet Traversées.'),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: billets.length,
            itemBuilder: (context, index) => _carteBillet(billets[index]),
          );
        },
      ),
    );
  }

  Widget _carteBillet(Map<String, dynamic> billet) {
    final traversee = Traversee(objet(billet['traversee']));
    final code = (billet['code'] ?? '').toString();
    final statut = (billet['statut'] ?? '').toString();
    final annulable = statut != 'ANNULE' && statut != 'EMBARQUE';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ombre(0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BILLET',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.6,
                      ),
                    ),
                    Pastille(libelleStatut(statut), couleurStatut(statut)),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${traversee.depart}  →  ${traversee.arrivee}',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kNavy)),
                const SizedBox(height: 4),
                Text(
                  '${traversee.date} à ${traversee.heure}  •  ${billet['nb_places']} place${(billet['nb_places'] as num?) == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ${montant(billet['total'])}',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: kSunset),
                ),
                if (annulable)
                  TextButton(
                    onPressed: () => _annuler(billet),
                    child: const Text('Annuler', style: TextStyle(color: Color(0xFFB3261E))),
                  )
                else
                  const Text('—', style: TextStyle(color: Colors.black26)),
              ],
            ),
          ),
        ],
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
    final passager = objet(session.passager);
    final nom = (passager['nom_complet'] ?? 'Passager').toString();
    final email = (passager['email'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kNavy, kNavyClair],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    initiales(nom),
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Membre depuis ${dateFr(passager['date_inscription'])}',
                      style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ombre(0.4),
          ),
          child: Column(
            children: [
              _ligne(Icons.phone_outlined, 'Téléphone', (passager['telephone'] ?? '—').toString()),
              const Divider(height: 1, indent: 56),
              _ligne(Icons.mail_outline, 'E-mail', email.isEmpty ? 'Non renseigné' : email),
              const Divider(height: 1, indent: 56),
              _ligne(Icons.dns_outlined, 'Serveur', session.api.baseUrl),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => session.fermer(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: const Color(0xFFB3261E),
            side: const BorderSide(color: Color(0x33B3261E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Se déconnecter'),
        ),
        const SizedBox(height: 14),
        const Text(
          'SILIMU 1.0.0 — Transport lacustre · Lac Kivu & Tanganyika',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.black38),
        ),
      ],
    );
  }

  Widget _ligne(IconData icone, String libelle, String valeur) {
    return ListTile(
      dense: true,
      leading: Icon(icone, color: kTeal, size: 20),
      title: Text(libelle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      subtitle: Text(
        valeur,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNavy),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
