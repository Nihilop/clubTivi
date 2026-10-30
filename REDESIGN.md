# Redesign Tivi

Branche `redesign`. Nouvelle interface pensée d'abord pour **Android TV** (télécommande / D-pad),
adaptée au mobile, développée sous Windows.

Maquettes et design system de référence : `../design/` (HTML).

## Ce qui a changé

| Dossier | Contenu |
|---|---|
| `lib/ui/` | Design system : tokens, échelle TV/mobile, typo Rubik, focus D-pad, composants |
| `lib/data/tivi/` | Données des nouvelles vues : langues, index EPG, catalogue VOD, favoris, reprise |
| `lib/features/home/` | Accueil (4 tuiles, horloge, réglages) |
| `lib/features/live/` | TV en direct : choix de langue unique + liste + aperçu |
| `lib/features/vod/` | Films / séries : hero qui défile + rangées de posters |
| `lib/features/player/tivi_player_screen.dart` | Lecteur direct / film / épisode |
| `lib/features/live/tv_guide_screen.dart` | Guide TV : chaînes + programmes, rappels |
| `lib/features/search/search_screen.dart` | Recherche : chaînes, programmes, films, séries |
| `lib/features/settings/tivi_settings_screen.dart` | Réglages (langue, playlists, guide, clés API) |
| `backup/` | Copie de `lib/` et du manifeste Android d'origine (référence, non compilée) |

Les écrans d'origine (playlists, EPG, réglages avancés, Trakt) restent accessibles depuis
Accueil → Réglages, avec le nouveau thème.

## Règles D-pad

- Tout élément atteignable passe par `TvFocusable` (OK / Entrée / clic / tap → action).
- Les longues listes (chaînes, posters) utilisent `TvIndexedList` : un seul nœud de focus,
  les flèches de l'axe déplacent l'index, les autres sortent vers le voisin.
- Un seul `PopScope` par écran gère le Retour (fermer un panneau, revenir à la liste…).
- Windows : flèches, Entrée = OK, Échap = Retour, Espace = lecture/pause, Page ↑/↓ = CH+/CH−.

## Lancer

```bash
flutter run -d windows
```

Android TV (sur le réseau, débogage ADB activé sur la TV) :

```bash
adb connect <ip-de-la-tv>:5555
flutter run -d <ip-de-la-tv>:5555
```

## Sources par défaut

- **Chaînes** : `iptv-org` (`index.language.m3u`), ajoutée et activée au premier lancement,
  rafraîchie chaque jour, jamais réajoutée si l'utilisateur la supprime. Le `group-title` est
  la langue : seules les chaînes de la langue choisie sont affichées.
- **Guide TV** : guides par pays d'iptv-epg.org (mêmes identifiants qu'iptv-org, suffixe
  `@SD` ignoré), activés selon la langue (`lib/data/tivi/epg_language_sync.dart`).
- L'accueil n'affiche Films / Séries que si une source en contient.

## Limites connues

- Films / séries : uniquement les entrées VOD des playlists M3U. L'import VOD Xtream
  (`get_vod_streams`, `get_series`) existe dans `XtreamClient` mais n'est pas encore branché.
- Pas de visuels de programmes (l'EPG n'en fournit pas) : l'aperçu utilise le logo de la chaîne.
- Radios et recherche vocale : pas encore disponibles.
- Rappels : notification dans l'app uniquement (pas de notification système si l'app est fermée).
