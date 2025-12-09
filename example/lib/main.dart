import 'dart:convert'; // Para utf8.encode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:blue_thermal_mais/blue_thermal_mais.dart';
import 'package:blue_thermal_mais/models/bluetooth_device_model.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

// 1. CLASSE DE CONFIGURAÇÃO (RAIZ)
// Cria o MaterialApp e fornece o ScaffoldMessenger para os filhos.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrinterPage(), // Chama a página separada
    );
  }
}

// 2. CLASSE DA TELA (LÓGICA)
// Aqui fica toda a lógica de Bluetooth e UI
class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final _blueThermalMais = BlueThermalMais();

  List<BluetoothDeviceModel> _devices = [];
  BluetoothDeviceModel? _connectedDevice;
  bool _isLoading = false;
  bool _isBluetoothOn = false;

  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para garantir que a tela já desenhou
    // antes de tentar pedir permissão ou mostrar SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBluetoothStatus();
      _requestPermissions();
    });
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      bool isOn = await _blueThermalMais.isOn();
      if (mounted) setState(() => _isBluetoothOn = isOn);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _requestPermissions() async {
    // Pede múltiplas permissões necessárias para Android 10, 11, 12+
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _scan(); // Se deu tudo certo, inicia o scan
    } else {
      _showSnack("Permissões negadas! Verifique as configurações.");
    }
  }

  void _scan() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _devices = [];
    });

    _blueThermalMais.scan().listen((deviceList) {
      if (!mounted) return;
      setState(() {
        _devices = deviceList;
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Erro no scan: $e");
    });
  }

  Future<void> _connect(BluetoothDeviceModel device) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      bool isConnected = await _blueThermalMais.connect(device);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (isConnected) {
        setState(() => _connectedDevice = device);
        _showSnack("Conectado a ${device.name}");
      } else {
        _showSnack("Falha ao conectar.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Erro: $e");
    }
  }

  Future<void> _disconnect() async {
    await _blueThermalMais.disconnect();
    if (!mounted) return;
    setState(() => _connectedDevice = null);
    _showSnack("Desconectado.");
  }

  Future<void> _printTest() async {
    if (_connectedDevice == null) return;

    try {
      // Comandos Manuais (Sem libs extras para evitar erros de versão)
      const List<int> cmdReset = [0x1B, 0x40];
      const List<int> cmdAlignCenter = [0x1B, 0x61, 0x01];
      const List<int> cmdAlignLeft = [0x1B, 0x61, 0x00];
      const List<int> cmdBoldOn = [0x1B, 0x45, 0x01];
      const List<int> cmdBoldOff = [0x1B, 0x45, 0x00];
      const List<int> cmdFeed3 = [0x1B, 0x64, 0x03];

      List<int> bytes = [];
      bytes.addAll(cmdReset);

      bytes.addAll(cmdAlignCenter);
      bytes.addAll(cmdBoldOn);
      bytes.addAll(utf8.encode("PLUGIN FLUTTER\n"));
      bytes.addAll(utf8.encode("BlueThermalMais\n"));
      bytes.addAll(cmdBoldOff);
      bytes.addAll(utf8.encode("--------------------------------\n"));

      bytes.addAll(cmdAlignLeft);
      bytes.addAll(utf8.encode("Item A              R\$ 10,00\n"));
      bytes.addAll(utf8.encode("Item B              R\$ 20,00\n"));
      bytes.addAll(utf8.encode("--------------------------------\n"));

      bytes.addAll(cmdBoldOn);
      bytes.addAll(utf8.encode("TOTAL               R\$ 30,00\n"));
      bytes.addAll(cmdBoldOff);

      bytes.addAll(cmdFeed3);

      await _blueThermalMais.printRaw(bytes);
    } catch (e) {
      _showSnack("Erro ao imprimir: $e");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    // O ScaffoldMessenger agora funciona porque PrinterPage é filho de MaterialApp
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste Plugin'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () { _checkBluetoothStatus(); _scan(); }
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: _isBluetoothOn ? Colors.blue[50] : Colors.red[50],
            child: Row(
              children: [
                Icon(_isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled),
                const SizedBox(width: 10),
                Text(_isBluetoothOn ? "Bluetooth Ligado" : "Bluetooth Desligado"),
              ],
            ),
          ),
          if (_connectedDevice != null)
            Container(
              color: Colors.green[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text("Conectado!"),
                  const Spacer(),
                  TextButton(onPressed: _disconnect, child: const Text("Sair"))
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _requestPermissions,
              child: Text(_isLoading ? "Buscando..." : "Buscar"),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final dev = _devices[index];
                return ListTile(
                  title: Text(dev.name),
                  subtitle: Text(dev.address),
                  onTap: () => _connect(dev),
                  trailing: _connectedDevice?.address == dev.address
                      ? const Icon(Icons.check, color: Colors.green) : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _connectedDevice != null ? _printTest : null,
                child: const Text("IMPRIMIR TESTE"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}