import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

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
      title: 'BLE Aula',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(title: 'BLE Aula'),
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

  bool _advertising = false;
  bool _modoProfessor = false;
  bool _scanning = false;

  // Lista para armazenar os alunos encontrados
  final List<Map<String, dynamic>> _devices = [];

  double estimateDistance(int rssi, {int txPower = -59, double n = 2}) {
    return pow(10, (txPower - rssi) / (10 * n)).toDouble();
  }

  // =========================
  // BLE TRANSMISSOR (ALUNO)
  // =========================
  Future<void> _toggleAula() async {
    if (_advertising) {
      await _blePeripheral.stop();
      setState(() => _advertising = false);
      return;
    }

    String nome = _controller.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome')),
      );
      return;
    }

    // Criamos um protocolo: "0001" (4 bytes) + Nome do aluno
    // O manufacturerData tem limite de ~20 bytes, então o nome deve ser curto.
    List<int> dataPayload = utf8.encode("0001$nome");
    Uint8List manufacturerData = Uint8List.fromList(dataPayload);

    final advertiseData = AdvertiseData(
      includeDeviceName: false,
      // Desativado para sobrar espaço para o nome customizado
      manufacturerId: 1234,
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

      setState(() => _advertising = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transmitindo presença...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar: $e')),
      );
    }
  }

  // =========================
  // BLE SCANNER (PROFESSOR)
  // =========================
  void _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
    });

    // Inicia o scan com continuousUpdates para receber pacotes repetidos e atualizar RSSI
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: true,
    );

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;

      for (ScanResult r in results) {
        final manufacturerData = r.advertisementData.manufacturerData;

        if (manufacturerData.containsKey(1234)) {
          final Uint8List data = Uint8List.fromList(manufacturerData[1234]!);
          final String decoded = utf8.decode(data, allowMalformed: true);

          // Verifica se começa com a nossa chave "0001"
          if (decoded.startsWith("0001")) {
            final String nomeAluno = decoded.substring(4); // Remove o "0001"
            final double distance = estimateDistance(r.rssi);

            setState(() {
              // Remove duplicados pelo ID do dispositivo
              _devices.removeWhere((d) => d['id'] == r.device.remoteId.str);

              _devices.add({
                'id': r.device.remoteId.str,
                'name': nomeAluno.isEmpty ? "Sem nome" : nomeAluno,
                'rssi': r.rssi,
                'distance': distance,
              });

              // Ordenar por proximidade
              _devices.sort((a, b) =>
                  (a['distance'] as double).compareTo(b['distance']));
            });
          }
        }
      }
    });
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => _scanning = false);
  }

  // UI (Simplificada para o exemplo)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () => setState(() => _modoProfessor = false),
                  child: const Text("MODO ALUNO")),
              TextButton(onPressed: () => setState(() => _modoProfessor = true),
                  child: const Text("MODO PROFESSOR")),
            ],
          ),
          Expanded(
            child: _modoProfessor ? _buildProfessor() : _buildAluno(),
          ),
        ],
      ),
    );
  }

  Widget _buildAluno() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: _controller,
              decoration: const InputDecoration(labelText: 'Seu Nome')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _toggleAula,
            style: ElevatedButton.styleFrom(
                backgroundColor: _advertising ? Colors.red : Colors.green),
            child: Text(_advertising ? "PARAR PRESENÇA" : "ENVIAR PRESENÇA"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessor() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _scanning ? _stopScan : _startScan,
          child: Text(_scanning ? "PARAR BUSCA" : "BUSCAR ALUNOS"),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final d = _devices[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(d['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Distância: ${d['distance'].toStringAsFixed(
                    2)}m (RSSI: ${d['rssi']})"),
              );
            },
          ),
        ),
      ],
    );
  }
}