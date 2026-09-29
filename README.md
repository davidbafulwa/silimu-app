# SILIMU — application mobile & web

Application de réservation de billets de transport lacustre sur le **lac Kivu** et le
**lac Tanganyika** : recherche de traversées, réservation, billet avec code, suivi
depuis l'application.

📲 **Télécharger l'APK Android** : voir la section [Téléchargements](#téléchargements)
ci-dessous (ou l'onglet *Releases* de ce dépôt).

<p align="center">
  <img src="assets/logo.png" width="140" alt="SILIMU">
</p>

---

## Téléchargements

L'APK est recompilé automatiquement à chaque modification et publié dans
l'onglet **[Releases](https://github.com/davidbafulwa/silimu-app/releases)**.

| Version | Fichier | Détail |
|---------|---------|--------|
| 1.0.0 | [`app-release.apk`](https://github.com/davidbafulwa/silimu-app/releases) | Android, ~22 Mo |

**Installer sur Android**
1. Télécharger `app-release.apk`.
2. Autoriser « Sources inconnues » pour l'application qui ouvre le fichier.
3. Ouvrir le `.apk` → *Installer*.

**Installer sur ordinateur** : ouvrir la version web dans Chrome/Edge puis
« Installer l'application » (fenêtre dédiée, utilisable hors ligne).

---

## Fonctionnalités

- **Connexion / inscription** — compte passager protégé par mot de passe, authentification par jeton opaque (aucun secret dans l'application).
- **Recherche de traversées** — choix du port de départ et d'arrivée, horaires, places restantes, prix, bateau.
- **Réservation** — nombre de places, moyen de paiement (Orange Money, Airtel Money, M-Pesa, carte, espèces au comptoir), code de billet immédiat.
- **Mes billets** — historique complet, statut, montant, annulation en un geste (la place est libérée).
- **Profil** — informations du compte et serveur connecté.

## Comment ça marche

L'application est une interface native ; **toute la logique métier reste sur le
serveur** (Django + REST Framework) : disponibilité des places, prix, anti-surbooking
et Anti-fraude. Le client ne contient aucun secret et ne peut pas contourner ces
règles.

```
Application Flutter  ──HTTPS──▶  API Django REST
                               ├─ /api/auth/…            (jeton opaque)
                               ├─ /api/ports/            (liste des ports)
                               ├─ /api/traversees/       (recherche, filtres)
                               ├─ /api/reservations/     (création, code)
                               └─ /api/reservations/mes/ (billets du passager)
```

L'adresse du serveur est saisie par l'utilisateur au premier lancement
(`http://…:8000` en local, `https://…` en production) : une seule application
fonctionne pour tous les environnements.

## Développer

```bash
flutter pub get
flutter run                 # téléphone ou émulateur connecté
flutter test                # tests unitaires
flutter build apk --release # APK Android
flutter build web --release # version web
```

La compilation se fait aussi toute seule sur GitHub : chaque `push` sur `main`
produit un nouvel APK (voir `.github/workflows/build-apk.yml`).

## Technologies

- **Flutter / Dart** — interface unique Android, web et desktop
- **HTTP** — seule dépendance : échanges avec l'API
- **GitHub Actions** — compilation et publication des releases

## Licence

Projet propriétaire. Code fourni à titre de démonstration technique.
