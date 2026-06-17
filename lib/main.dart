import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as web;

void main() {
  runApp(const FristenApp());
}

class FristenApp extends StatelessWidget {
  const FristenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Date Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HauptSeite(),
    );
  }
}

class AppEintrag {
  String name;
  DateTime datum;
  String? gruppenId;

  AppEintrag({required this.name, required this.datum, this.gruppenId});

  Map<String, dynamic> toJson() => {
        'name': name,
        'datum': datum.toIso8601String(),
        'gruppenId': gruppenId,
      };

  factory AppEintrag.fromJson(Map<String, dynamic> json) => AppEintrag(
        name: json['name'],
        datum: DateTime.parse(json['datum']),
        gruppenId: json['gruppenId'],
      );
}

class AppGruppe {
  final String id;
  String name;

  AppGruppe({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory AppGruppe.fromJson(Map<String, dynamic> json) => AppGruppe(id: json['id'], name: json['name']);
}

class HauptSeite extends StatefulWidget {
  const HauptSeite({super.key});

  @override
  State<HauptSeite> createState() => _HauptSeiteState();
}

class _HauptSeiteState extends State<HauptSeite> {
  final List<AppEintrag> _eintraege = [];
  final List<AppGruppe> _gruppen = [];
  late SharedPreferences _prefs;

  int _gelbeTage = 30;
  int _roteTage = 14;

  String _aktuelleSortierung = 'none';
  bool _aufsteigend = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gruppenNameController = TextEditingController();
  DateTime? _gewaehltesDatum;
  String? _ausgewaehlteGruppeId;

  @override
  void initState() {
    super.initState();
    _ladeDaten();
    // Hinweis beim Start anzeigen
    WidgetsBinding.instance.addPostFrameCallback((_) => _zeigeCacheHinweis());
  }

  void _zeigeCacheHinweis() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wichtiger Hinweis'),
        content: const Text('Deine Daten werden lokal im Browser gespeichert. Wenn du den Browser-Cache leerst, gehen diese verloren! Bitte sichere deine Daten regelmäßig unter Einstellungen.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Verstanden'))],
      ),
    );
  }

  // Export: Daten als JSON-Datei im Browser herunterladen
  void _exportiereDaten() {
    final Map<String, dynamic> daten = {
      'eintraege': _eintraege.map((e) => e.toJson()).toList(),
      'gruppen': _gruppen.map((g) => g.toJson()).toList(),
    };
    final String jsonString = jsonEncode(daten);
    
    final blob = web.Blob([jsonString], 'application/json');
    final url = web.Url.createObjectUrlFromBlob(blob);
    final anchor = web.AnchorElement(href: url)
      ..setAttribute("download", "date_tracker_backup.json")
      ..click();
    web.Url.revokeObjectUrl(url);
  }

  // Import: JSON-Datei auswählen und Daten überschreiben
  void _importiereDaten() {
    final input = web.FileUploadInputElement()..accept = '.json';
    input.click();
    input.onChange.listen((e) {
      final file = input.files!.first;
      final reader = web.FileReader();
      reader.readAsText(file);
      reader.onLoadEnd.listen((e) {
        final Map<String, dynamic> daten = jsonDecode(reader.result as String);
        setState(() {
          _eintraege.clear();
          _eintraege.addAll((daten['eintraege'] as List).map((e) => AppEintrag.fromJson(e)));
          _gruppen.clear();
          _gruppen.addAll((daten['gruppen'] as List).map((g) => AppGruppe.fromJson(g)));
          _speichereDaten();
        });
      });
    });
  }

  void _bearbeiteGruppeDialog(AppGruppe gruppe) {
    _gruppenNameController.text = gruppe.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe umbenennen'),
        content: TextField(controller: _gruppenNameController),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              setState(() {
                gruppe.name = _gruppenNameController.text;
                _speichereDaten();
              });
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _loescheGruppeBestaetigen(AppGruppe gruppe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe löschen?'),
        content: Text('Möchtest du "${gruppe.name}" löschen? Die enthaltenen Einträge verlieren ihre Gruppenzuordnung.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              setState(() {
                // Gruppenzuordnung der Einträge entfernen
                for (var e in _eintraege) {
                  if (e.gruppenId == gruppe.id) e.gruppenId = null;
                }
                _gruppen.remove(gruppe);
                _speichereDaten();
              });
              Navigator.pop(context);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _ladeDaten() async {
    _prefs = await SharedPreferences.getInstance();
    final String? gespeicherteEintraege = _prefs.getString('eintraege_liste');
    final String? gespeicherteGruppen = _prefs.getString('gruppen_liste');
    
    setState(() {
      if (gespeicherteGruppen != null) {
        final List<dynamic> decodedG = jsonDecode(gespeicherteGruppen);
        _gruppen.clear();
        for (var item in decodedG) {
          _gruppen.add(AppGruppe.fromJson(item));
        }
      }
      if (gespeicherteEintraege != null) {
        final List<dynamic> decodedE = jsonDecode(gespeicherteEintraege);
        _eintraege.clear();
        for (var item in decodedE) {
          _eintraege.add(AppEintrag.fromJson(item));
        }
      }
    });
  }

  void _speichereDaten() async {
    final String encodierteEintraege = jsonEncode(_eintraege.map((e) => e.toJson()).toList());
    final String encodierteGruppen = jsonEncode(_gruppen.map((g) => g.toJson()).toList());
    await _prefs.setString('eintraege_liste', encodierteEintraege);
    await _prefs.setString('gruppen_liste', encodierteGruppen);
  }

  int _berechneTage(DateTime zielDatum) {
    final jetzt = DateTime.now();
    final heuteBereinigt = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final ziel = DateTime(zielDatum.year, zielDatum.month, zielDatum.day);
    return ziel.difference(heuteBereinigt).inDays;
  }

  Color _holeFarbeFuerTage(int tageFrist) {
    if (tageFrist <= 0) return Colors.red.shade200;
    if (tageFrist <= _roteTage) return Colors.orange.shade200;
    if (tageFrist <= _gelbeTage) return Colors.yellow.shade100;
    return Colors.green.shade100;
  }

  Color _holeFarbeFuerEintrag(DateTime zielDatum) {
    return _holeFarbeFuerTage(_berechneTage(zielDatum));
  }

  Color _holeFarbeFuerGruppe(String gruppenId) {
    final gruppenEintraege = _eintraege.where((e) => e.gruppenId == gruppenId).toList();
    if (gruppenEintraege.isEmpty) return Colors.grey.shade100;

    int kritischsteTage = _berechneTage(gruppenEintraege.first.datum);
    for (var e in gruppenEintraege) {
      int t = _berechneTage(e.datum);
      if (t < kritischsteTage) {
        kritischsteTage = t;
      }
    }
    return _holeFarbeFuerTage(kritischsteTage);
  }

  void _sortiere(String spalte) {
    setState(() {
      if (_aktuelleSortierung == spalte) {
        _aufsteigend = !_aufsteigend;
      } else {
        _aktuelleSortierung = spalte;
        _aufsteigend = true;
      }

      if (spalte == 'name') {
        _eintraege.sort((a, b) => _aufsteigend 
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase()) 
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      } else if (spalte == 'tage') {
        _eintraege.sort((a, b) {
          final tageA = _berechneTage(a.datum);
          final tageB = _berechneTage(b.datum);
          return _aufsteigend ? tageA.compareTo(tageB) : tageB.compareTo(tageA);
        });
      }
    });
  }

  void _loescheEintragBestaetigen(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('Möchtest du "${_eintraege[index].name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              setState(() {
                _eintraege.removeAt(index);
                _speichereDaten();
              });
              Navigator.pop(context);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- DIE NEUE FUNKTION: HILFS-DIALOG ZUM SCHNELLEN ERSTELLEN ---
  // Gibt true zurück, wenn eine Gruppe erstellt wurde
  Future<bool> _schnellGruppeErstellenDialog() async {
    _gruppenNameController.clear();
    bool erstellt = false;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Gruppe erstellen'),
        content: TextField(
          controller: _gruppenNameController,
          decoration: const InputDecoration(labelText: 'Gruppenname'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              if (_gruppenNameController.text.isNotEmpty) {
                setState(() {
                  final neueId = DateTime.now().millisecondsSinceEpoch.toString();
                  _gruppen.add(AppGruppe(id: neueId, name: _gruppenNameController.text));
                  _ausgewaehlteGruppeId = neueId; // Automatisch die neue Gruppe vorauswählen
                  _speichereDaten();
                  erstellt = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
    return erstellt;
  }

  void _bearbeiteEintragDialog(int index) {
    _nameController.text = _eintraege[index].name;
    _gewaehltesDatum = _eintraege[index].datum;
    _ausgewaehlteGruppeId = _eintraege[index].gruppenId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Eintrag bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 15),
              // Zeile mit Dropdown UND Schnell-Erstellen-Button
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ausgewaehlteGruppeId,
                      decoration: const InputDecoration(labelText: 'Gruppe (Optional)'),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Keine Gruppe')),
                        ..._gruppen.map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name))),
                      ],
                      onChanged: (val) => setDialogState(() => _ausgewaehlteGruppeId = val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    tooltip: 'Neue Gruppe erstellen',
                    onPressed: () async {
                      bool hatErstellt = await _schnellGruppeErstellenDialog();
                      if (hatErstellt) {
                        // Aktualisiert den aktuellen Dialog, damit die neue Gruppe im Dropdown auftaucht
                        setDialogState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: Text('Datum: ${_gewaehltesDatum!.day}.${_gewaehltesDatum!.month}.${_gewaehltesDatum!.year}')),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _gewaehltesDatum!,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setDialogState(() => _gewaehltesDatum = picked);
                    },
                    child: const Icon(Icons.calendar_month),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _gewaehltesDatum != null) {
                  setState(() {
                    _eintraege[index].name = _nameController.text;
                    _eintraege[index].datum = _gewaehltesDatum!;
                    _eintraege[index].gruppenId = _ausgewaehlteGruppeId;
                    _speichereDaten();
                    if (_aktuelleSortierung != 'none') _sortiere(_aktuelleSortierung);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _zeigeEintragDialog() {
    _nameController.clear();
    _gewaehltesDatum = null;
    _ausgewaehlteGruppeId = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neuer Eintrag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name/Ereignis')),
              const SizedBox(height: 15),
              // Zeile mit Dropdown UND Schnell-Erstellen-Button
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ausgewaehlteGruppeId,
                      decoration: const InputDecoration(labelText: 'Gruppe zuweisen (Optional)'),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Keine Gruppe')),
                        ..._gruppen.map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name))),
                      ],
                      onChanged: (val) => setDialogState(() => _ausgewaehlteGruppeId = val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    tooltip: 'Neue Gruppe erstellen',
                    onPressed: () async {
                      bool hatErstellt = await _schnellGruppeErstellenDialog();
                      if (hatErstellt) {
                        // Aktualisiert das UI des Dialogs, damit das Dropdown die neue Gruppe sofort anzeigt
                        setDialogState(() {});
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: Text(_gewaehltesDatum == null ? 'Kein Datum' : 'Datum: ${_gewaehltesDatum!.day}.${_gewaehltesDatum!.month}.${_gewaehltesDatum!.year}')),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setDialogState(() => _gewaehltesDatum = picked);
                    },
                    child: const Icon(Icons.calendar_month),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _gewaehltesDatum != null) {
                  setState(() {
                    _eintraege.add(AppEintrag(
                      name: _nameController.text,
                      datum: _gewaehltesDatum!,
                      gruppenId: _ausgewaehlteGruppeId,
                    ));
                    _speichereDaten();
                    if (_aktuelleSortierung != 'none') _sortiere(_aktuelleSortierung);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baueEintragZeile(AppEintrag eintrag, int index) {
    final restTage = _berechneTage(eintrag.datum);
    return Column(
      children: [
        Container(
          color: _holeFarbeFuerEintrag(eintrag.datum),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              Expanded(child: Text(eintrag.name)),
              Expanded(
                child: Text(restTage < 0 
                    ? 'Abgelaufen' 
                    : '$restTage Tage (bis ${eintrag.datum.day}.${eintrag.datum.month}.${eintrag.datum.year})'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) => val == 'edit' ? _bearbeiteEintragDialog(index) : _loescheEintragBestaetigen(index),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Ändern')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Löschen', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final heimatloseEintraege = _eintraege.where((e) => e.gruppenId == null).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Date Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Übersicht'),
              Tab(icon: Icon(Icons.settings), text: 'Einstellungen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.fromLTRB(12.0, 12.0, 48.0, 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _sortiere('name'),
                          child: Row(
                            children: [
                              const Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                              if (_aktuelleSortierung == 'name') Icon(_aufsteigend ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _sortiere('tage'),
                          child: Row(
                            children: [
                              const Text('Verbleibende Tage', style: TextStyle(fontWeight: FontWeight.bold)),
                              if (_aktuelleSortierung == 'tage') Icon(_aufsteigend ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _eintraege.isEmpty
                      ? const Center(child: Text('Noch keine Einträge vorhanden.'))
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 80.0),
                          children: [
                            ..._gruppen.map((gruppe) {
                              final gruppenEintraege = _eintraege.where((e) => e.gruppenId == gruppe.id).toList();
                              
                              return Card(
                                margin: const EdgeInsets.all(8.0),
                                elevation: 3,
                                child: ExpansionTile(
                                  backgroundColor: _holeFarbeFuerGruppe(gruppe.id),
                                  collapsedBackgroundColor: _holeFarbeFuerGruppe(gruppe.id),
                                  title: Text(gruppe.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Text('${gruppenEintraege.length} Einträge'),
                                  // --- HIER NEU ---
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (val) => val == 'edit' 
                                        ? _bearbeiteGruppeDialog(gruppe) 
                                        : _loescheGruppeBestaetigen(gruppe),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Umbenennen')),
                                      const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                  children: gruppenEintraege.isEmpty
                                      ? [const Padding(padding: EdgeInsets.all(12.0), child: Text('Diese Gruppe ist leer. Bearbeite ein Produkt, um es hierher zu verschieben.'))]
                                      : gruppenEintraege.map((eintrag) {
                                          int originalIndex = _eintraege.indexOf(eintrag);
                                          return _baueEintragZeile(eintrag, originalIndex);
                                        }).toList(),
                                ),
                              );
                            }),
                            if (heimatloseEintraege.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('Einträge ohne Gruppe', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ...heimatloseEintraege.map((eintrag) {
                                int originalIndex = _eintraege.indexOf(eintrag);
                                return _baueEintragZeile(eintrag, originalIndex);
                              }),
                            ],
                          ],
                        ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Warnstufen konfigurieren', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text('Ab wie vielen Tagen GELB markieren? ($_gelbeTage Tage)'),
                  Slider(
                    value: _gelbeTage.toDouble(), min: 1, max: 60, divisions: 60, label: _gelbeTage.toString(),
                    onChanged: (val) => setState(() => _gelbeTage = val.round()),
                  ),
                  const SizedBox(height: 20),
                  Text('Ab wie vielen Tagen ORANGE markieren? ($_roteTage Tage)'),
                  Slider(
                    value: _roteTage.toDouble(), min: 1, max: 30, divisions: 30, label: _roteTage.toString(),
                    onChanged: (val) => setState(() => _roteTage = val.round()),
                  ),
                  const Divider(height: 40),
                  const Text('Datenverwaltung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Daten als Datei sichern'),
                    onTap: _exportiereDaten,
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload),
                    title: const Text('Daten aus Datei importieren'),
                    onTap: _importiereDaten,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _zeigeEintragDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}