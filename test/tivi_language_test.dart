import 'package:clubtivi/data/tivi/language_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectLanguage', () {
    test('préfixes de groupe courants', () {
      expect(detectLanguage('FR | Sport', 'beIN Sports 1'), 'fr');
      expect(detectLanguage('|UK| Entertainment', 'BBC One'), 'en');
      expect(detectLanguage('[DE] Nachrichten', 'ZDF'), 'de');
      expect(detectLanguage('US: News', 'CNN'), 'us');
      expect(detectLanguage('AR - MBC', 'MBC 1'), 'ar');
    });

    test('mots complets dans le groupe ou le nom', () {
      expect(detectLanguage('FRANCE HD', 'TF1'), 'fr');
      expect(detectLanguage(null, 'Italia Uno'), 'it');
      expect(detectLanguage('Chaînes Belgique', 'RTL TVI'), 'be');
    });

    test('pas de faux positif sur des mots courts', () {
      expect(detectLanguage('Movies', 'Into the Wild'), isNull);
      expect(detectLanguage(null, 'IN DA CLUB'), isNull);
    });
  });

  test('stripLanguagePrefix', () {
    expect(stripLanguagePrefix('FR - Le Grand Voyage'), 'Le Grand Voyage');
    expect(stripLanguagePrefix('|UK| BBC One'), 'BBC One');
    expect(stripLanguagePrefix('Le Grand Voyage'), 'Le Grand Voyage');
  });

  test('groupes de langue iptv-org', () {
    expect(iptvOrgLanguage('French'), 'fr');
    expect(iptvOrgLanguage('English'), 'en');
    expect(iptvOrgLanguage('Abkhazian'), 'x-abkhazian');
    expect(iptvOrgLanguage('Undefined'), isNull);
    expect(languageInfo('x-abkhazian').label, 'Abkhazian');
    expect(languageInfo('fr').flag, 'fr');
    expect(detectLanguage('Spanish', 'Canal 24'), 'es');
  });
}
