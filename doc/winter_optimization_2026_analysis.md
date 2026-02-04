# Analyse der Winteroptimierungs-Einstellungen für Januar/Februar 2026

## Zusammenfassung

Die Einstellungen in `miscsrc/winter_optimization.pl` wurden analysiert, um zu prüfen, ob sie für den aktuellen Winter (Januar und Februar 2026) angemessen sind.

**Ergebnis: ✓ Die aktuellen Einstellungen sind angemessen.**

## Aktuelle Konfiguration

Die Winteroptimierung ist in den Konfigurationsdateien für die Monate 11-3 (November bis März) aktiviert:

```perl
if (1) {
    my @l = localtime;
    my $m = $l[4]+1;
    $use_winter_optimization = ($m >= 11 || $m <= 3);
    $winter_hardness = 'dry_cold';
}
```

**Aktueller Winter-Härtegrad:** `dry_cold`

## Verfügbare Winter-Härtegrade

### 1. `dry_cold` (aktuell verwendet)
- **Beschreibung:** Trocken und kalt, alle Straßen geräumt, kein Eis außer auf Fuß- und Radwegen
- **Verwendbarkeit:** 
  - NN (unbekannte Wege): 1 (sehr schlecht)
  - N, NH, H, HH, B (alle anderen): 6 (sehr gut)
- **Optimierungen:** Keine KFZ-, Kopfsteinpflaster- oder Tram-Optimierungen
- **Anwendungsfall:** Später Winter oder nach Räumung, minimaler Schnee/Eis

### 2. `snowy`
- **Beschreibung:** Moderate Schneebedingungen, einige Straßen geräumt
- **Verwendbarkeit:**
  - NN: 1, N: 3, NH: 4, H: 5, HH: 6, B: 6
- **Optimierungen:** Verwendet KFZ-Anpassung, Kopfsteinpflaster- und Tram-Optimierungen
- **Anwendungsfall:** Aktiver Winter mit mäßiger Schneedecke

### 3. `very_snowy`
- **Beschreibung:** Starke Schneebedingungen, erste Tage mit Schnee
- **Verwendbarkeit:**
  - NN: 1, N: 2, NH: 4, H: 5, HH: 6, B: 6
- **Optimierungen:** Verwendet KFZ-Anpassung, Kopfsteinpflaster- und Tram-Optimierungen
- **Anwendungsfall:** Frischer Schneefall, begrenzte Straßenräumung

## Empfehlung für Januar/Februar 2026

Für die Monate Januar und Februar (Hochwinter) ist die Einstellung abhängig von den tatsächlichen Bedingungen:

### Aktuelle Einstellung: `dry_cold` ✓

**Geeignet für:**
- Typische Berliner Winterbedingungen
- Hauptstraßen sind regelmäßig geräumt
- Hauptproblem sind vereiste Radwege und Fußwege
- Kein durchgehender Schnee auf Fahrbahnen

**Begründung:**
Die Einstellung `dry_cold` ist für Januar/Februar 2026 angemessen, da in Berlin üblicherweise:
1. Die Hauptstraßen regelmäßig geräumt werden
2. Schnee auf Fahrbahnen die Ausnahme ist
3. Radwege und Fußwege das Hauptproblem darstellen (diese werden durch NN=1 stark bestraft)

### Alternative Einstellungen

Falls sich die Wetterbedingungen ändern:

- **Bei mäßiger Schneedecke mit teilweiser Räumung:**
  - Wechsel zu `snowy`
  - Bessere Routenführung um schlecht gewartete Straßen

- **Bei starkem Schneefall oder frischem Schnee:**
  - Wechsel zu `very_snowy`
  - Routen bevorzugen Hauptstraßen und Buslinien

## Implementierungsdetails

1. **Konfigurationsdateien:**
   - `cgi/bbbike2-test.cgi.config`: `$winter_hardness = 'dry_cold'`
   - `cgi/bbbike2-debian.cgi.config`: `$winter_hardness = 'dry_cold'`
   - `cgi/bbbike2-ci.cgi.config`: Lädt extern von `/root/work/bbbike-webserver/etc/winter_hardness`

2. **Penalty-Dateien:**
   - Werden generiert in: `tmp/winter_optimization.$hardness.st`
   - Format: Storable oder JSON
   - Werden bei Bedarf automatisch erstellt

3. **Benutzer-Einstellungen:**
   - CGI-Parameter `pref_winter` erlaubt Benutzer-Override
   - Werte: "" (aus), "WI1" (schwach), "WI2" (stark)
   - WI1 verwendet Koeffizient 0.5, WI2 verwendet Koeffizient 1.0

## Fazit

Die aktuellen Einstellungen in `miscsrc/winter_optimization.pl` sind für Januar und Februar 2026 angemessen. Die Einstellung `dry_cold` passt zu typischen Berliner Winterbedingungen, bei denen:

- Hauptstraßen regelmäßig geräumt sind
- Die Hauptherausforderung vereiste Radwege und Fußwege sind
- Durchgehende Schneedecken auf Fahrbahnen eher selten sind

Die Einstellungen können bei Bedarf dynamisch angepasst werden, wenn sich die Wetterbedingungen ändern (z.B. bei starkem Schneefall auf `snowy` oder `very_snowy` umstellen).

## Validierung

Ein Validierungsskript wurde erstellt unter `miscsrc/validate_winter_settings.pl`, das:
- Die aktuellen Einstellungen analysiert
- Empfehlungen basierend auf Monat und Bedingungen gibt
- Die verschiedenen Härtegrade dokumentiert

Ausführung:
```bash
cd miscsrc
perl validate_winter_settings.pl
```

---

**Analysedatum:** 4. Februar 2026  
**Status:** ✓ Einstellungen geprüft und als angemessen befunden
