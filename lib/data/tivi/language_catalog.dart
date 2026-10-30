/// Détection de la langue / du pays d'une chaîne à partir du groupe ou du nom
/// de la playlist (« FR | Sport », « |UK| BBC One », « [DE] ZDF », « FRANCE HD »…).
class LanguageInfo {
  const LanguageInfo(this.code, this.label, this.flag);
  final String code;
  final String label;

  /// Code pays pour le drapeau (flagcdn.com), null = icône globe.
  final String? flag;
}

/// Infos d'une langue ; les langues hors catalogue (`x-…`) gardent leur nom iptv-org.
LanguageInfo languageInfo(String code) {
  final known = kLanguages[code];
  if (known != null) return known;
  final name = code.startsWith('x-') ? code.substring(2) : code;
  return LanguageInfo(code, name.isEmpty ? code : name[0].toUpperCase() + name.substring(1), null);
}

const kLanguages = <String, LanguageInfo>{
  'fr': LanguageInfo('fr', 'Français', 'fr'),
  'en': LanguageInfo('en', 'English', 'gb'),
  'us': LanguageInfo('us', 'English (US)', 'us'),
  'ca': LanguageInfo('ca', 'Canada', 'ca'),
  'de': LanguageInfo('de', 'Deutsch', 'de'),
  'es': LanguageInfo('es', 'Español', 'es'),
  'mx': LanguageInfo('mx', 'Latino', 'mx'),
  'it': LanguageInfo('it', 'Italiano', 'it'),
  'pt': LanguageInfo('pt', 'Português', 'pt'),
  'br': LanguageInfo('br', 'Português (BR)', 'br'),
  'nl': LanguageInfo('nl', 'Nederlands', 'nl'),
  'be': LanguageInfo('be', 'Belgique', 'be'),
  'ch': LanguageInfo('ch', 'Suisse', 'ch'),
  'ar': LanguageInfo('ar', 'العربية', 'sa'),
  'tr': LanguageInfo('tr', 'Türkçe', 'tr'),
  'pl': LanguageInfo('pl', 'Polski', 'pl'),
  'ro': LanguageInfo('ro', 'Română', 'ro'),
  'gr': LanguageInfo('gr', 'Ελληνικά', 'gr'),
  'ru': LanguageInfo('ru', 'Русский', 'ru'),
  'ua': LanguageInfo('ua', 'Українська', 'ua'),
  'in': LanguageInfo('in', 'India', 'in'),
  'al': LanguageInfo('al', 'Shqip', 'al'),
  'se': LanguageInfo('se', 'Svenska', 'se'),
  'no': LanguageInfo('no', 'Norsk', 'no'),
  'dk': LanguageInfo('dk', 'Dansk', 'dk'),
  'fi': LanguageInfo('fi', 'Suomi', 'fi'),
  'cz': LanguageInfo('cz', 'Čeština', 'cz'),
  'hu': LanguageInfo('hu', 'Magyar', 'hu'),
  'bg': LanguageInfo('bg', 'Български', 'bg'),
  'ir': LanguageInfo('ir', 'فارسی', 'ir'),
  'zh': LanguageInfo('zh', '中文', 'cn'),
  'hi': LanguageInfo('hi', 'हिन्दी', 'in'),
  'id': LanguageInfo('id', 'Bahasa Indonesia', 'id'),
  'ta': LanguageInfo('ta', 'தமிழ்', 'in'),
  'bn': LanguageInfo('bn', 'বাংলা', 'bd'),
  'vi': LanguageInfo('vi', 'Tiếng Việt', 'vn'),
  'ur': LanguageInfo('ur', 'اردو', 'pk'),
  'te': LanguageInfo('te', 'తెలుగు', 'in'),
  'ko': LanguageInfo('ko', '한국어', 'kr'),
  'th': LanguageInfo('th', 'ไทย', 'th'),
  'ml': LanguageInfo('ml', 'മലയാളം', 'in'),
  'pa': LanguageInfo('pa', 'ਪੰਜਾਬੀ', 'in'),
  'sk': LanguageInfo('sk', 'Slovenčina', 'sk'),
  'sr': LanguageInfo('sr', 'Srpski', 'rs'),
  'cat': LanguageInfo('cat', 'Català', 'es-ct'),
  'kk': LanguageInfo('kk', 'Қазақ', 'kz'),
  'mn': LanguageInfo('mn', 'Монгол', 'mn'),
  'kn': LanguageInfo('kn', 'ಕನ್ನಡ', 'in'),
  'ja': LanguageInfo('ja', '日本語', 'jp'),
  'he': LanguageInfo('he', 'עברית', 'il'),
  'hr': LanguageInfo('hr', 'Hrvatski', 'hr'),
  'bs': LanguageInfo('bs', 'Bosanski', 'ba'),
  'mk': LanguageInfo('mk', 'Македонски', 'mk'),
  'sl': LanguageInfo('sl', 'Slovenščina', 'si'),
  'lt': LanguageInfo('lt', 'Lietuvių', 'lt'),
  'lv': LanguageInfo('lv', 'Latviešu', 'lv'),
  'et': LanguageInfo('et', 'Eesti', 'ee'),
  'ka': LanguageInfo('ka', 'ქართული', 'ge'),
  'hy': LanguageInfo('hy', 'Հայերեն', 'am'),
  'az': LanguageInfo('az', 'Azərbaycan', 'az'),
  'ms': LanguageInfo('ms', 'Bahasa Melayu', 'my'),
  'tl': LanguageInfo('tl', 'Filipino', 'ph'),
  'sw': LanguageInfo('sw', 'Kiswahili', 'ke'),
  'ne': LanguageInfo('ne', 'नेपाली', 'np'),
  'si': LanguageInfo('si', 'සිංහල', 'lk'),
  'be-by': LanguageInfo('be-by', 'Беларуская', 'by'),
  'uz': LanguageInfo('uz', 'Oʻzbek', 'uz'),
  'ku': LanguageInfo('ku', 'Kurdî', 'iq'),
  'ps': LanguageInfo('ps', 'پښتو', 'af'),
  'is': LanguageInfo('is', 'Íslenska', 'is'),
  'mt': LanguageInfo('mt', 'Malti', 'mt'),
  'af': LanguageInfo('af', 'Afrikaans', 'za'),
  'so': LanguageInfo('so', 'Soomaali', 'so'),
  'am': LanguageInfo('am', 'አማርኛ', 'et'),
};

/// Noms de langue anglais utilisés comme group-title par iptv-org (index.language.m3u).
const _englishNames = <String, String>{
  'FRENCH': 'fr',
  'ENGLISH': 'en',
  'SPANISH': 'es',
  'RUSSIAN': 'ru',
  'PORTUGUESE': 'pt',
  'HINDI': 'hi',
  'ARABIC': 'ar',
  'ITALIAN': 'it',
  'GERMAN': 'de',
  'CHINESE': 'zh',
  'DUTCH': 'nl',
  'PERSIAN': 'ir',
  'ROMANIAN': 'ro',
  'UKRAINIAN': 'ua',
  'INDONESIAN': 'id',
  'TURKISH': 'tr',
  'HUNGARIAN': 'hu',
  'POLISH': 'pl',
  'DANISH': 'dk',
  'SWEDISH': 'se',
  'TAMIL': 'ta',
  'NORWEGIAN': 'no',
  'NORWEGIAN BOKMÅL': 'no',
  'BENGALI': 'bn',
  'VIETNAMESE': 'vi',
  'GREEK': 'gr',
  'MODERN GREEK (1453-)': 'gr',
  'URDU': 'ur',
  'TELUGU': 'te',
  'CZECH': 'cz',
  'BULGARIAN': 'bg',
  'KOREAN': 'ko',
  'THAI': 'th',
  'MALAYALAM': 'ml',
  'PANJABI': 'pa',
  'PUNJABI': 'pa',
  'SLOVAK': 'sk',
  'SERBIAN': 'sr',
  'CATALAN': 'cat',
  'KAZAKH': 'kk',
  'ALBANIAN': 'al',
  'MONGOLIAN': 'mn',
  'KANNADA': 'kn',
  'JAPANESE': 'ja',
  'HEBREW': 'he',
  'CROATIAN': 'hr',
  'FINNISH': 'fi',
  'BOSNIAN': 'bs',
  'MACEDONIAN': 'mk',
  'SLOVENIAN': 'sl',
  'LITHUANIAN': 'lt',
  'LATVIAN': 'lv',
  'ESTONIAN': 'et',
  'GEORGIAN': 'ka',
  'ARMENIAN': 'hy',
  'AZERBAIJANI': 'az',
  'MALAY': 'ms',
  'FILIPINO': 'tl',
  'TAGALOG': 'tl',
  'SWAHILI': 'sw',
  'NEPALI': 'ne',
  'SINHALA': 'si',
  'BELARUSIAN': 'be-by',
  'UZBEK': 'uz',
  'KURDISH': 'ku',
  'PUSHTO': 'ps',
  'PASHTO': 'ps',
  'ICELANDIC': 'is',
  'MALTESE': 'mt',
  'AFRIKAANS': 'af',
  'SOMALI': 'so',
  'AMHARIC': 'am',
};

/// Langue d'un group-title iptv-org : code connu, ou `x-<nom>` pour les autres.
String? iptvOrgLanguage(String? group) {
  if (group == null || group.isEmpty) return null;
  final u = group.trim().toUpperCase();
  if (u == 'UNDEFINED') return null;
  return _englishNames[u] ?? 'x-${group.trim().toLowerCase()}';
}

/// Jetons reconnus en préfixe (« FR | … ») : courts, donc seulement en tête.
const _prefixAliases = <String, String>{
  'FR': 'fr', 'FRA': 'fr', 'VF': 'fr', 'VOSTFR': 'fr',
  'UK': 'en', 'GB': 'en', 'EN': 'en', 'ENG': 'en',
  'US': 'us', 'USA': 'us',
  'CA': 'ca', 'CAN': 'ca',
  'DE': 'de', 'GER': 'de', 'DEU': 'de',
  'ES': 'es', 'ESP': 'es', 'SP': 'es',
  'MX': 'mx', 'LAT': 'mx', 'LATINO': 'mx',
  'IT': 'it', 'ITA': 'it',
  'PT': 'pt', 'POR': 'pt',
  'BR': 'br', 'BRA': 'br',
  'NL': 'nl', 'NED': 'nl',
  'BE': 'be', 'BEL': 'be',
  'CH': 'ch', 'SUI': 'ch',
  'AR': 'ar', 'ARA': 'ar', 'ARAB': 'ar',
  'TR': 'tr', 'TUR': 'tr',
  'PL': 'pl', 'POL': 'pl',
  'RO': 'ro', 'ROM': 'ro',
  'GR': 'gr', 'GRE': 'gr',
  'RU': 'ru', 'RUS': 'ru',
  'UA': 'ua', 'UKR': 'ua',
  'IN': 'in', 'IND': 'in',
  'AL': 'al', 'ALB': 'al',
  'SE': 'se', 'SWE': 'se',
  'NO': 'no', 'NOR': 'no',
  'DK': 'dk', 'DEN': 'dk',
  'FI': 'fi', 'FIN': 'fi',
  'CZ': 'cz', 'HU': 'hu', 'BG': 'bg',
  'IR': 'ir', 'PER': 'ir',
};

/// Mots complets reconnus n'importe où (≥ 4 lettres pour éviter les faux positifs).
const _wordAliases = <String, String>{
  'FRANCE': 'fr', 'FRENCH': 'fr', 'FRANCAIS': 'fr', 'FRANÇAIS': 'fr',
  'ENGLISH': 'en', 'BRITAIN': 'en',
  'CANADA': 'ca', 'QUEBEC': 'ca',
  'GERMANY': 'de', 'GERMAN': 'de', 'DEUTSCH': 'de', 'ALLEMAGNE': 'de',
  'SPAIN': 'es', 'SPANISH': 'es', 'ESPANA': 'es', 'ESPAÑA': 'es',
  'ITALY': 'it', 'ITALIA': 'it', 'ITALIAN': 'it',
  'PORTUGAL': 'pt', 'BRAZIL': 'br', 'BRASIL': 'br',
  'NETHERLANDS': 'nl', 'HOLLAND': 'nl', 'DUTCH': 'nl',
  'BELGIUM': 'be', 'BELGIQUE': 'be', 'SUISSE': 'ch', 'SWISS': 'ch',
  'ARABIC': 'ar', 'TURKEY': 'tr', 'TURKIYE': 'tr', 'TURKISH': 'tr',
  'POLAND': 'pl', 'POLSKA': 'pl', 'ROMANIA': 'ro', 'GREECE': 'gr',
  'RUSSIA': 'ru', 'UKRAINE': 'ua', 'INDIA': 'in', 'ALBANIA': 'al',
  'SWEDEN': 'se', 'NORWAY': 'no', 'DENMARK': 'dk', 'FINLAND': 'fi',
  'PERSIAN': 'ir', 'IRAN': 'ir',
};

final _prefix = RegExp(r'^[^A-Z0-9]*([A-Z]{2,7})[^A-Z0-9]*[|:\-–»•\]]');
final _splitter = RegExp(r'[^A-ZÀ-Ü]+');

/// Code langue (`fr`, `en`…) ou null si rien n'est reconnu.
String? detectLanguage(String? group, String name) {
  final byName = group == null ? null : _englishNames[group.trim().toUpperCase()];
  if (byName != null) return byName;
  for (final source in [group, name]) {
    if (source == null || source.isEmpty) continue;
    final u = source.toUpperCase().trim();
    final m = _prefix.firstMatch(u);
    if (m != null) {
      final code = _prefixAliases[m.group(1)];
      if (code != null) return code;
    }
    for (final word in u.split(_splitter)) {
      if (word.length < 4) continue;
      final code = _wordAliases[word];
      if (code != null) return code;
    }
  }
  return null;
}

/// Retire le préfixe de langue d'un titre (« FR - Le Film » → « Le Film »).
String stripLanguagePrefix(String s) => s.replaceFirst(RegExp(r'^[^\w]*[A-Z]{2,7}[^\w]*[|:\-–»•\]]\s*'), '').trim();
