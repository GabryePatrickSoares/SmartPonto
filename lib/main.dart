import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Aula Presença',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Sistema de Presença BLE'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  StreamSubscription? _scanSubscription;
  Timer? _refreshTimer;

  bool _advertising = false;
  bool _modoProfessor = false;
  bool _scanning = false;

  // Lista dos alunos encontrados
  final List<Map<String, dynamic>> _devices = [];

  // Identificação do app BLE
  final int _manufacturerId = 1234;
  final String _protocolKey = "AULA";

  // =========================
  // ESTIMATIVA DE DISTÂNCIA
  // =========================
  double estimateDistance(
      int rssi, {
        int txPower = -59,
        double n = 2.0,
      }) {
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  // =========================
  // MODO ALUNO
  // =========================
  Future<void> _toggleAula() async {
    if (_advertising) {
      await _blePeripheral.stop();

      setState(() {
        _advertising = false;
      });

      return;
    }

    String nome = _controller.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite seu nome primeiro'),
        ),
      );
      return;
    }

    List<int> payload = utf8.encode("$_protocolKey$nome");

    Uint8List manufacturerData = Uint8List.fromList(payload);

    final advertiseData = AdvertiseData(
      includeDeviceName: false,
      manufacturerId: _manufacturerId,
      manufacturerData: manufacturerData,
    );

    final settings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowLatency,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
      connectable: false,
    );

    try {
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: settings,
      );

      setState(() {
        _advertising = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua presença está sendo transmitida!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao iniciar transmissão: $e'),
        ),
      );
    }
  }

  // =========================
  // MODO PROFESSOR
  // =========================
  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
    });

    // Atualiza a lista em tempo real
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (!mounted) return;

        setState(() {
          // Remove dispositivos offline
          _devices.removeWhere((d) {
            final lastSeen = d['lastSeen'] as DateTime;

            return DateTime.now()
                .difference(lastSeen)
                .inSeconds >
                5;
          });

          // Recalcula distância
          for (var d in _devices) {
            d['distance'] =
                estimateDistance(d['rssi']);
          }

          // Ordena por proximidade
          _devices.sort(
                (a, b) => (a['distance'] as double)
                .compareTo(b['distance'] as double),
          );
        });
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
      );

      _scanSubscription =
          FlutterBluePlus.scanResults.listen(
                (results) {
              if (!mounted) return;

              for (ScanResult r in results) {
                final mDataMap =
                    r.advertisementData.manufacturerData;

                if (mDataMap.containsKey(_manufacturerId)) {
                  final Uint8List rawData =
                  Uint8List.fromList(
                    mDataMap[_manufacturerId]!,
                  );

                  final String decodedString =
                  utf8.decode(
                    rawData,
                    allowMalformed: true,
                  );

                  if (decodedString
                      .startsWith(_protocolKey)) {
                    final String nomeAluno =
                    decodedString.replaceFirst(
                      _protocolKey,
                      "",
                    );

                    final double distance =
                    estimateDistance(r.rssi);

                    setState(() {
                      final existingIndex =
                      _devices.indexWhere(
                            (d) =>
                        d['id'] ==
                            r.device.remoteId.str,
                      );

                      if (existingIndex != -1) {
                        // Atualiza dispositivo existente
                        _devices[existingIndex]['rssi'] =
                            r.rssi;

                        _devices[existingIndex]
                        ['distance'] = distance;

                        _devices[existingIndex]
                        ['lastSeen'] =
                            DateTime.now();
                      } else {
                        // Novo dispositivo
                        _devices.add({
                          'id': r.device.remoteId.str,
                          'name': nomeAluno.isEmpty
                              ? "Aluno sem nome"
                              : nomeAluno,
                          'rssi': r.rssi,
                          'distance': distance,
                          'lastSeen': DateTime.now(),
                        });
                      }

                      // Ordena pela distância
                      _devices.sort(
                            (a, b) =>
                            (a['distance'] as double)
                                .compareTo(
                              b['distance'] as double,
                            ),
                      );
                    });
                  }
                }
              }
            },
          );

      FlutterBluePlus.isScanning.listen(
            (isScanning) {
          if (!isScanning && mounted) {
            setState(() {
              _scanning = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("Erro no scan: $e");

      setState(() {
        _scanning = false;
      });
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();

    _scanSubscription?.cancel();
    _refreshTimer?.cancel();

    setState(() {
      _scanning = false;
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _refreshTimer?.cancel();
    _controller.dispose();

    super.dispose();
  }

  // =========================
  // INTERFACE
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor:
        Theme.of(context)
            .colorScheme
            .inversePrimary,
      ),
      body: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(
              vertical: 10,
            ),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text("Sou Aluno"),
                  selected: !_modoProfessor,
                  onSelected: (val) {
                    setState(() {
                      _modoProfessor = false;
                    });
                  },
                ),
                ChoiceChip(
                  label:
                  const Text("Sou Professor"),
                  selected: _modoProfessor,
                  onSelected: (val) {
                    setState(() {
                      _modoProfessor = true;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _modoProfessor
                ? _buildProfessorUI()
                : _buildAlunoUI(),
          ),
        ],
      ),
    );
  }

  // =========================
  // UI ALUNO
  // =========================
  Widget _buildAlunoUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.school,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLength: 15,
            decoration:
            const InputDecoration(
              border: OutlineInputBorder(),
              labelText:
              'Digite seu nome completo',
              prefixIcon:
              Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _toggleAula,
              icon: Icon(
                _advertising
                    ? Icons.stop
                    : Icons.play_arrow,
              ),
              label: Text(
                _advertising
                    ? "PARAR PRESENÇA"
                    : "INICIAR PRESENÇA",
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                _advertising
                    ? Colors.red
                    : Colors.green,
                foregroundColor:
                Colors.white,
              ),
            ),
          ),
          if (_advertising) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              "O professor já pode te ver na lista!",
            ),
          ]
        ],
      ),
    );
  }

  // =========================
  // UI PROFESSOR
  // =========================
  Widget _buildProfessorUI() {
    return Column(
      children: [
        Padding(
          padding:
          const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanning
                  ? _stopScan
                  : _startScan,
              icon: Icon(
                _scanning
                    ? Icons.search_off
                    : Icons.search,
              ),
              label: Text(
                _scanning
                    ? "PARAR BUSCA"
                    : "BUSCAR ALUNOS",
              ),
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: _devices.isEmpty
              ? Center(
            child: Text(
              _scanning
                  ? "Procurando alunos..."
                  : "Nenhum aluno encontrado",
            ),
          )
              : ListView.builder(
            itemCount:
            _devices.length,
            itemBuilder:
                (context, index) {
              final d =
              _devices[index];

              return Card(
                margin:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListTile(
                  leading:
                  const CircleAvatar(
                    child:
                    Icon(Icons.person),
                  ),
                  title: Text(
                    d['name'],
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        "Distância aprox: "
                            "${d['distance'].toStringAsFixed(2)} m",
                      ),
                      Text(
                        "Última atualização: "
                            "${DateTime.now().difference(d['lastSeen']).inSeconds}s atrás",
                      ),
                    ],
                  ),
                  trailing: Text(
                    "${d['rssi']} dBm",
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}