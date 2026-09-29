import 'package:flutter_test/flutter_test.dart';
import 'package:silimu_app/api.dart';
import 'package:silimu_app/pages.dart';

void main() {
  group('Adresse du serveur', () {
    test('ajoute le schéma et /api', () {
      expect(
        ApiClient.normaliserServeur('10.0.0.2:8000'),
        'http://10.0.0.2:8000/api',
      );
    });

    test('ne duplique pas /api et nettoie le / final', () {
      expect(
        ApiClient.normaliserServeur('https://exemple.onrender.com/api/'),
        'https://exemple.onrender.com/api',
      );
    });

    test('accepte une adresse vide', () {
      expect(ApiClient.normaliserServeur('   '), '');
    });
  });

  group('Formatage', () {
    test('montants avec séparateur de milliers', () {
      expect(montant(25000), '25 000 FC');
      expect(montant(1000), '1 000 FC');
      expect(montant(100), '100 FC');
    });

    test('montants tolèrent une chaîne', () {
      expect(montant('12 500'), '12 500 FC');
      expect(montant(null), '0 FC');
    });

    test('dates en français', () {
      expect(dateFr('2026-03-12T07:00:00'), '12/03/2026 à 07:00');
      expect(dateFr('2026-03-12'), '12/03/2026');
      expect(dateFr(null), '');
    });
  });

  group('Statuts', () {
    test('libellés lisibles', () {
      expect(libelleStatut('EN_ATTENTE'), 'En attente');
      expect(libelleStatut('EMBARQUE'), 'Embarqué');
      expect(libelleStatut('INCONNU'), 'inconnu');
    });
  });

  group('Lecture des données', () {
    test('une traversée est lue depuis le JSON de l’API', () {
      final t = Traversee(objet(<String, dynamic>{
        'id': 7,
        'date': '2026-03-12',
        'heure': '07:30:00',
        'prix': 25000,
        'statut': 'PROGAMMEE',
        'places_disponibles': 12,
        'route': {
          'duree_min': 95,
          'port_depart': {'id': 1, 'nom': 'Bukavu'},
          'port_arrivee': {'id': 2, 'nom': 'Goma'},
        },
        'bateau': {'nom': 'MS Kivu'},
      }));
      expect(t.id, 7);
      expect(t.depart, 'Bukavu');
      expect(t.arrivee, 'Goma');
      expect(t.heure, '07:30');
      expect(t.date, '12/03/2026');
      expect(t.prix, '25 000 FC');
      expect(t.duree, '95 min');
      expect(t.nomBateau, 'MS Kivu');
      expect(t.statut, 'Programmée');
      expect(t.reserveable, isTrue);
    });

    test('une traversée complète ou annulée n’est pas réservable', () {
      final complete = Traversee(objet(<String, dynamic>{'statut': 'COMPLETE', 'places_disponibles': 30}));
      final annulee = Traversee(objet(<String, dynamic>{'statut': 'ANNULEE', 'places_disponibles': 30}));
      final vide = Traversee(objet(<String, dynamic>{'statut': 'PROGAMMEE', 'places_disponibles': 0}));
      expect(complete.reserveable, isFalse);
      expect(annulee.reserveable, isFalse);
      expect(vide.reserveable, isFalse);
    });

    test('les listes de l’API sont acceptées avec ou sans pagination', () {
      expect(ApiClient.liste(<dynamic>[1, 2]).length, 2);
      expect(ApiClient.liste(objet(<String, dynamic>{'results': <dynamic>[1]})).length, 1);
      expect(ApiClient.liste(objet(<String, dynamic>{'resultats': <dynamic>[1, 2, 3]})).length, 3);
      expect(ApiClient.liste(null), isEmpty);
    });

    test('initiales pour l’avatar du profil', () {
      expect(initiales('Jean-Pierre Mukendi'), 'JM');
      expect(initiales('Alice'), 'A');
      expect(initiales('  '), '?');
    });
  });
}
