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
      expect(libelleStatut('EN_ATTENTE'), 'En attente de paiement');
      expect(libelleStatut('EMBARQUE'), 'Embarqué');
      expect(libelleStatut('INCONNU'), 'inconnu');
    });
  });
}
