# SILIMU — application mobile & web

Application de réservation de billets de transport lacustre sur le **lac Kivu** et le
**lac Tanganyika** : recherche de traversées, réservation, billet avec code, suivi
depuis l'application.

<p align="center">
  <img src="assets/logo.png" width="140" alt="SILIMU">
</p>

<p align="center">
  <a href="https://github.com/davidbafulwa/silimu-app/releases/latest/download/SILIMU.apk"><img alt="Télécharger l'APK" src="https://img.shields.io/badge/T%C3%A9l%C3%A9charger-APK%20Android-0FB5B0?style=for-the-badge&logo=android&logoColor=white"></a>
  <a href="https://github.com/davidbafulwa/silimu-app/releases/latest"><img alt="Version" src="https://img.shields.io/github/v/release/davidbafulwa/silimu-app?color=0FB5B0&style=flat-square&label=version"></a>
  <a href="https://github.com/davidbafulwa/silimu-app/actions/workflows/build-apk.yml"><img alt="Build" src="https://github.com/davidbafulwa/silimu-app/actions/workflows/build-apk.yml/badge.svg"></a>
  <img alt="Téléchargements" src="https://img.shields.io/github/downloads/davidbafulwa/silimu-app/total?color=0FB5B0&style=flat-square&label=t%C3%A9l%C3%A9chargements">
  <img alt="Taille de l'APK" src="https://img.shields.io/badge/APK-17%20Mo-555?style=flat-square&label=taille">
  <img alt="Plateformes" src="https://img.shields.io/badge/Android%20%7C%20Web%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-07303F?style=flat-square&label=plates-formes">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47.5-0FB5B0?style=flat-square&logo=flutter&logoColor=white">
  <img alt="API" src="https://img.shields.io/badge/API-Django%20REST-07303F?style=flat-square&label=backend">
  <img alt="Statut" src="https://img.shields.io/badge/statut-en%20ligne-4CAF50?style=flat-square">
</p>

---

## Téléchargements

L'APK est recompilé automatiquement à chaque modification et publié dans
l'onglet **[Releases](https://github.com/davidbafulwa/silimu-app/releases)**.

| Version | Fichier | Pour qui | Taille |
|---------|---------|----------|--------|
| 1.0.0 | [**SILIMU.apk**](https://github.com/davidbafulwa/silimu-app/releases/latest/download/SILIMU.apk) | Téléphones Android récents (95 % des cas) | ~17 Mo |
| 1.0.0 | [SILIMU-arm32.apk](https://github.com/davidbafulwa/silimu-app/releases) | Téléphones Android anciens | ~15 Mo |
| 1.0.0 | SILIMU-emu.apk | Émulateurs Android | ~17 Mo |

Chaque fichier contient **une seule architecture** : c'est 3 fois plus léger
qu'un APK universel de 48 Mo.

**Installer sur Android**
1. Télécharger `SILIMU.apk`.
2. Autoriser « Sources inconnues » pour l'application qui ouvre le fichier.
3. Ouvrir le `.apk` → *Installer*.

**Version la plus légère (0 Mo)** : ouvrir le site dans Chrome/Edge puis
« Installer l'application » (PWA) — même interface, sur téléphone et sur
ordinateur, utilisable hors ligne.

**Sur cet ordinateur** : cette commande télécharge l'application et la dépose
sur le Bureau.

```bash
bash ~/.local/bin/silimu-apk.sh
```

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
et anti-fraude. Le client ne contient aucun secret et ne peut pas contourner ces
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
flutter build apk --release --split-per-abi   # APK Android léger
flutter build web --release # version web
```

La compilation se fait aussi toute seule sur GitHub : chaque `push` sur `main`
produit les APK de la release (voir `.github/workflows/build-apk.yml`).

## Technologies

- **Flutter / Dart** — interface unique Android, web et desktop
- **HTTP** — seule dépendance : échanges avec l'API
- **GitHub Actions** — compilation et publication des releases

## Licence

Projet propriétaire. Code fourni à titre de démonstration technique.
