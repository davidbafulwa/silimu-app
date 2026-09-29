#!/usr/bin/env python3
"""SILIMU — génération des icônes de l'application.

Redessine le logo SILIMU (mêmes courbes que le logo du site : carré navy à
coins arrondis, vague teal pleine, vague orange en trait) aux tailles
Android et web, puis assemble les dossiers `res/` prêts à copier dans un
projet Flutter.

    python3 tools/generate_icons.py

Sorties :
    mobile_app/assets/icon-512.png      (logo complet, utilisé dans l'app)
    mobile_app/assets/icon-192.png
    mobile_app/assets/favicon-32.png
    mobile_app/assets/apple-touch-icon-180.png
    mobile_app/assets/android/mipmap-*dpi*/ic_launcher.png (+ _round, _foreground)
    mobile_app/assets/android/drawable/ic_launcher_background.xml
    mobile_app/assets/android/mipmap-anydpi-v26/ic_launcher*.xml
"""
import math
import os

from PIL import Image, ImageDraw

NAVY = (7, 48, 63, 255)
TEAL = (15, 181, 176, 255)
SUNSET = (244, 117, 51, 255)
TRANSPARENT = (0, 0, 0, 0)

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RACINE, "mobile_app", "assets")
ANDROID = os.path.join(ASSETS, "android")
# Facteur de suréchantillonnage (anticrénelage).
SS = 8


def bezier(p0, p1, p2, p3, pas=24):
    """Échantillonne une courbe de Bézier cubique."""
    points = []
    for i in range(pas + 1):
        t = i / pas
        mt = 1 - t
        x = (mt ** 3) * p0[0] + 3 * (mt ** 2) * t * p1[0] + 3 * mt * (t ** 2) * p2[0] + (t ** 3) * p3[0]
        y = (mt ** 3) * p0[1] + 3 * (mt ** 2) * t * p1[1] + 3 * mt * (t ** 2) * p2[1] + (t ** 3) * p3[1]
        points.append((x, y))
    return points


def reflet(p, autour):
    """Point symétrique (utilisé par les courbes 's' du logo)."""
    return (2 * autour[0] - p[0], 2 * autour[1] - p[1])


# --- Géométrie du logo, dans un repère 64x64 (comme le viewBox du site) ----
# Vague teal (pleine) : M8 40 c6-8 12-8 16-2 s12 6 18 0 s10-6 14-2 v10 H8 z
TEAL_SEGMENTS = [
    ((8, 40), (14, 32), (20, 32), (24, 38)),
    ((24, 38), (28, 44), (36, 44), (42, 38)),
    ((42, 38), (48, 32), (52, 32), (56, 36)),
]
TEAL_FIN = [(56, 46), (8, 46)]

# Vague orange (trait) : M8 30 c6-8 12-8 16-2 s12 6 18 0 s10-6 14-2
SUNSET_SEGMENTS = [
    ((8, 30), (14, 22), (20, 22), (24, 28)),
    ((24, 28), (28, 34), (36, 34), (42, 28)),
    ((42, 28), (48, 22), (52, 22), (56, 26)),
]


def chemin(segments, fin=None):
    points = []
    for segment in segments:
        courbe = bezier(*segment)
        points.extend(courbe if not points else courbe[1:])
    if fin:
        points.extend(fin)
    return points


def dessiner_vagues(dessin, echelle, offset=(0, 0), trait=4.0):
    """Dessine les deux vagues, mises à l'échelle, translationnée."""
    dx, dy = offset
    def convertir(points):
        return [(x * echelle + dx, y * echelle + dy) for x, y in points]

    # Vague teal pleine
    dessin.polygon(convertir(chemin(TEAL_SEGMENTS, TEAL_FIN)), fill=TEAL)

    # Vague orange en trait, extrémités arrondies
    orange = convertir(chemin(SUNSET_SEGMENTS))
    largeur = max(1, int(round(trait * echelle)))
    dessin.line(orange, fill=SUNSET, width=largeur, joint="curve")
    rayon = largeur / 2
    for x, y in (orange[0], orange[-1]):
        dessin.ellipse([x - rayon, y - rayon, x + rayon, y + rayon], fill=SUNSET)


def logo_complet(taille, arrondi=0.25):
    """Logo complet : carré navy arrondi + vagues."""
    px = taille * SS
    image = Image.new("RGBA", (px, px), TRANSPARENT)
    dessin = ImageDraw.Draw(image)
    rayon = int(px * arrondi)
    dessin.rounded_rectangle([0, 0, px - 1, px - 1], radius=rayon, fill=NAVY)
    dessiner_vagues(dessin, px / 64.0, trait=4.0)
    return image.resize((taille, taille), Image.LANCZOS)


def logo_avant_plan(taille, contenu=0.62):
    """Calque avant plan adaptatif : vagues seules, zone sûre respectée."""
    px = taille * SS
    image = Image.new("RGBA", (px, px), TRANSPARENT)
    dessin = ImageDraw.Draw(image)
    echelle = px * contenu / 64.0
    marge = (px - 64 * echelle) / 2
    dessiner_vagues(dessin, echelle, offset=(marge, marge), trait=4.0)
    return image.resize((taille, taille), Image.LANCZOS)


def ecrire(image, chemin_fichier):
    os.makedirs(os.path.dirname(chemin_fichier), exist_ok=True)
    image.save(chemin_fichier, "PNG", optimize=True)
    print("  ", os.path.relpath(chemin_fichier, RACINE))


# --- Fichiers web / in-app --------------------------------------------------
print("Icône principale (application et site) :")
ecrire(logo_complet(512), os.path.join(ASSETS, "icon-512.png"))
ecrire(logo_complet(192), os.path.join(ASSETS, "icon-192.png"))
ecrire(logo_complet(180), os.path.join(ASSETS, "apple-touch-icon-180.png"))
ecrire(logo_complet(32), os.path.join(ASSETS, "favicon-32.png"))

# --- Densités Android -------------------------------------------------------
# mdpi=1, hdpi=1.5, xhdpi=2, xxhdpi=3, xxxhdpi=4 (facteur par dp)
DENSITES = {
    "mipmap-mdpi": 1,
    "mipmap-hdpi": 1.5,
    "mipmap-xhdpi": 2,
    "mipmap-xxhdpi": 3,
    "mipmap-xxxhdpi": 4,
}
print("Icônes Android (legacy) :")
for dossier, facteur in DENSITES.items():
    cible = os.path.join(ANDROID, dossier)
    taille = int(round(48 * facteur))
    ecrire(logo_complet(taille), os.path.join(cible, "ic_launcher.png"))
    ecrire(logo_complet(taille), os.path.join(cible, "ic_launcher_round.png"))

print("Icônes Android adaptatives (Android 8+) :")
for dossier, facteur in DENSITES.items():
    cible = os.path.join(ANDROID, dossier)
    taille = int(round(108 * facteur))  # 108 dp de zone adaptive
    ecrire(logo_avant_plan(taille), os.path.join(cible, "ic_launcher_foreground.png"))

# --- Fichiers XML de l'icône adaptative ------------------------------------
print("XML adaptatifs :")
os.makedirs(os.path.join(ANDROID, "drawable"), exist_ok=True)
with open(os.path.join(ANDROID, "drawable", "ic_launcher_background.xml"), "w") as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:shape="rectangle">\n'
        '    <solid android:color="#07303F" />\n'
        "</shape>\n"
    )
print("   mobile_app/assets/android/drawable/ic_launcher_background.xml")

os.makedirs(os.path.join(ANDROID, "mipmap-anydpi-v26"), exist_ok=True)
for nom in ("ic_launcher.xml", "ic_launcher_round.xml"):
    with open(os.path.join(ANDROID, "mipmap-anydpi-v26", nom), "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            "</adaptive-icon>\n"
        )
    print(f"   mobile_app/assets/android/mipmap-anydpi-v26/{nom}")

print("Terminé.")
