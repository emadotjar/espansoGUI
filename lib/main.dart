// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart' as y;

void main() {
  runApp(const YamlViewerApp());
}

class YamlViewerApp extends StatelessWidget {
  const YamlViewerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YAML Viewer',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const YamlViewerPage(),
    );
  }
}

class YamlViewerPage extends StatefulWidget {
  const YamlViewerPage({super.key});
  @override
  State<YamlViewerPage> createState() => _YamlViewerPageState();
}

class _YamlViewerPageState extends State<YamlViewerPage> {
  String? _yamlText;
  String? _error;
  late final String _yamlPath;
  List<Map<String, dynamic>> _matches = [];

  static String getEspansoBaseYamlPath() {
    final home = Platform.environment['HOME'] ?? '';
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/espanso/match/base.yml';
    } else if (Platform.isLinux) {
      return '$home/.config/espanso/match/base.yml';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      return '$appData\\espanso\\match\\base.yml';
    } else {
      return 'espanso/match/base.yml'; // fallback
    }
  }

  @override
  void initState() {
    super.initState();
    _yamlPath = getEspansoBaseYamlPath();
    _loadYamlFromPath();
  }

  Future<void> _loadYamlFromPath() async {
    setState(() {
      _error = null;
      _matches = [];
    });

    try {
      final file = File(_yamlPath);
      if (!await file.exists()) {
        setState(() => _error = 'File not found: $_yamlPath');
        return;
      }
      final text = await file.readAsString();

      try {
        final yaml = y.loadYaml(text);
        if (yaml is Map && yaml['matches'] is List) {
          _matches = List<Map<String, dynamic>>.from(
            (yaml['matches'] as List).map((e) => Map<String, dynamic>.from(e)),
          );
        }
        setState(() => _yamlText = text);
      } catch (e) {
        _error =
            'Warning: YAML parse error — content will still be shown. Details: $e';
        setState(() => _yamlText = text);
      }
    } catch (e) {
      setState(() => _error = 'Failed to open file: $e');
    }
  }

  Future<void> _saveYamlToPath() async {
    // Compose YAML from _matches
    final buffer = StringBuffer();
    buffer.writeln('matches:');
    for (final match in _matches) {
      buffer.writeln('  - trigger: "${match['trigger'] ?? ''}"');
      buffer.writeln('    replace: "${match['replace'] ?? ''}"');
      if (match['vars'] is List) {
        buffer.writeln('    vars:');
        for (final v in match['vars']) {
          buffer.writeln('      - name: "${v['name'] ?? ''}"');
          buffer.writeln('        type: "${v['type'] ?? ''}"');
          if (v['params'] is Map) {
            buffer.writeln('        params:');
            v['params'].forEach((k, val) {
              buffer.writeln('          $k: "$val"');
            });
          }
        }
      }
    }
    final yamlString = buffer.toString();

    try {
      final file = File(_yamlPath);
      await file.writeAsString(yamlString);
      setState(() => _yamlText = yamlString);
    } catch (e) {
      setState(() => _error = 'Failed to save file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _yamlText == null
        ? Center(child: Text('Loading YAML from $_yamlPath'))
        : Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _yamlText!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('YAML Viewer')),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(child: body),
          if (_matches.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _matches.length,
                itemBuilder: (context, idx) {
                  final match = _matches[idx];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: match['trigger'] ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Trigger',
                            ),
                            onChanged: (val) => match['trigger'] = val,
                          ),
                          TextFormField(
                            initialValue: match['replace'] ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Replace',
                            ),
                            onChanged: (val) => match['replace'] = val,
                          ),
                          if (match['vars'] is List)
                            ...List.generate((match['vars'] as List).length, (
                              vIdx,
                            ) {
                              final v = match['vars'][vIdx];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    initialValue: v['name'] ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Var Name',
                                    ),
                                    onChanged: (val) => v['name'] = val,
                                  ),
                                  TextFormField(
                                    initialValue: v['type'] ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Var Type',
                                    ),
                                    onChanged: (val) => v['type'] = val,
                                  ),
                                  if (v['params'] is Map)
                                    ...v['params'].entries.map(
                                      (entry) => TextFormField(
                                        initialValue: entry.value ?? '',
                                        decoration: InputDecoration(
                                          labelText: 'Param: ${entry.key}',
                                        ),
                                        onChanged: (val) =>
                                            v['params'][entry.key] = val,
                                      ),
                                    ),
                                ],
                              );
                            }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete Match',
                              onPressed: () {
                                setState(() {
                                  _matches.removeAt(idx);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                onPressed: _saveYamlToPath,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Match'),
              onPressed: () {
                setState(() {
                  _matches.add({
                    'trigger': '',
                    'replace': '',
                    // You can add more fields here if needed
                  });
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
