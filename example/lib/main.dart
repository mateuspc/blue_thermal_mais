import 'dart:convert'; // Para utf8.encode
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:blue_thermal_mais/blue_thermal_mais.dart';
import 'package:blue_thermal_mais/models/bluetooth_device_model.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

// 1. CLASSE DE CONFIGURAÇÃO (RAIZ)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrinterPage(),
    );
  }
}

// 2. CLASSE DA TELA (LÓGICA)
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

  // StreamSubscription para poder cancelar o listen se sair da tela
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBluetoothStatus();
      _requestPermissions();
    });
  }

  @override
  void dispose() {
    // Sempre cancele subscriptions e pare o scan ao sair da tela
    _scanSubscription?.cancel();
    _blueThermalMais.stopScan();
    super.dispose();
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
    // Permissões completas para Android 12+ e anteriores
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Necessário para Android 11 e inferior
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _scan();
    } else {
      _showSnack(
        "Permissões negadas! Verifique as configurações.",
        color: Colors.red,
      );
    }
  }

  void _scan() {
    if (!mounted) return;

    // Cancela scan anterior se houver
    _scanSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _devices = []; // Limpa a lista visual
    });

    try {
      _scanSubscription = _blueThermalMais.scan().listen(
        (deviceList) {
          if (!mounted) return;
          setState(() {
            _devices = deviceList;
            // Não setamos isLoading = false aqui porque o scan é contínuo
            // O usuário deve parar manualmente ou ao conectar
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showSnack("Erro no scan: $e", color: Colors.red);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Erro ao iniciar scan: $e", color: Colors.red);
    }
  }

  void _stopScanManually() {
    _scanSubscription?.cancel();
    _blueThermalMais.stopScan();
    setState(() => _isLoading = false);
  }

  // --- AQUI ESTÁ A MUDANÇA CRUCIAL PARA O PAREAMENTO ---
  Future<void> _connect(BluetoothDeviceModel device) async {
    if (!mounted) return;

    // 1. Para o scan visualmente e logicamente antes de conectar
    _stopScanManually();

    setState(() => _isLoading = true);

    try {
      // O método connect da sua classe wrapper já tem o stopScan interno
      // e lança a exceção tratada se precisar parear.
      bool isConnected = await _blueThermalMais.connect(device);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (isConnected) {
        setState(() => _connectedDevice = device);
        _showSnack("Conectado a ${device.name}", color: Colors.green);
      } else {
        _showSnack("Falha ao conectar (retornou false).", color: Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Tratamento específico para a mensagem de pareamento
      String erro = e.toString();
      if (erro.contains("Pareamento iniciado")) {
        _showDialogPairingInfo(); // Mostra um alerta amigável
      } else {
        _showSnack("Erro: $erro", color: Colors.red);
      }
    }
  }

  Future<void> _disconnect() async {
    await _blueThermalMais.disconnect();
    if (!mounted) return;
    setState(() => _connectedDevice = null);
    _showSnack("Desconectado.");
  }

  // Helper para mostrar alerta de pareamento
  void _showDialogPairingInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pareamento Necessário"),
        content: const Text(
          "O Android iniciou o processo de pareamento.\n\n"
          "1. Verifique a notificação na barra superior ou um popup na tela.\n"
          "2. Digite o PIN (geralmente 0000 ou 1234).\n"
          "3. Após parear, toque no dispositivo aqui novamente para conectar.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendi"),
          ),
        ],
      ),
    );
  }

  Future<void> _printTest() async {
    if (_connectedDevice == null) return;

    try {
      const List<int> cmdReset = [0x1B, 0x40];
      const List<int> cmdFeed3 = [0x1B, 0x64, 0x03];

      List<int> bytes = [];
      bytes.addAll(cmdReset);
      bytes.addAll(utf8.encode("TESTE DE IMPRESSAO\n"));
      bytes.addAll(utf8.encode("Funciona!\n"));
      bytes.addAll(cmdFeed3);

      await _blueThermalMais.printRaw(bytes);
    } catch (e) {
      _showSnack("Erro ao imprimir: $e", color: Colors.red);
    }
  }

  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teste Plugin'),
        actions: [
          if (_isLoading)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopScanManually,
              tooltip: "Parar Scan",
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _checkBluetoothStatus();
                _scan();
              },
              tooltip: "Escanear",
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Status
          Container(
            padding: const EdgeInsets.all(10),
            color: _isBluetoothOn ? Colors.blue[50] : Colors.red[50],
            child: Row(
              children: [
                Icon(
                  _isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                ),
                const SizedBox(width: 10),
                Text(
                  _isBluetoothOn ? "Bluetooth Ligado" : "Bluetooth Desligado",
                ),
                if (_isLoading) ...[
                  const Spacer(),
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  const Text("Buscando..."),
                ],
              ],
            ),
          ),

          // Área de Conectado
          if (_connectedDevice != null)
            Container(
              color: Colors.green[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.print, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Conectado a: ${_connectedDevice!.name}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _disconnect,
                    child: const Text("Desconectar"),
                  ),
                ],
              ),
            ),

          // Botão Buscar (se não estiver na AppBar)
          if (!_isLoading && _connectedDevice == null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                onPressed: _requestPermissions,
                label: const Text("Buscar Dispositivos"),
              ),
            ),

          // Lista de Dispositivos
          Expanded(
            child: _devices.isEmpty
                ? const Center(child: Text("Nenhum dispositivo encontrado."))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final dev = _devices[index];
                      final isConnected =
                          _connectedDevice?.address == dev.address;

                      return ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          dev.name.isNotEmpty ? dev.name : "Sem Nome",
                        ),
                        subtitle: Text(
                          dev.address,
                        ), // No iOS mostra UUID, no Android MAC
                        onTap: isConnected ? null : () => _connect(dev),
                        trailing: isConnected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),

          // Botão de Imprimir
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _connectedDevice != null ? _printTest : null,
                child: const Text(
                  "IMPRIMIR TESTE",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
