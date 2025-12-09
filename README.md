📦 BlueThermalMais — Plugin Flutter para Impressoras Térmicas via Bluetooth

BlueThermalMais é um plugin Flutter de conexão, escaneamento e impressão Bluetooth voltado para impressoras térmicas.
Construído com foco em estabilidade, baixa latência e simplicidade, ele oferece uma API moderna, intuitiva e compatível com Android 12+.

✨ Recursos

✔️ Escanear dispositivos Bluetooth próximos
✔️ Conectar e desconectar impressoras térmicas
✔️ Enviar bytes RAW diretamente para a impressora
✔️ Compatível com esc_pos_utils_plus
✔️ Suporte a permissões do Android 12+
✔️ Callback de scan em tempo real
✔️ Fácil de integrar e usar em qualquer app Flutter

🚀 Instalação

Adicione ao pubspec.yaml:

dependencies:
blue_thermal_mais: ^1.0.0


Execute:

flutter pub get

🛠 Configuração Android (MUITO IMPORTANTE)

Edite o arquivo:

android/app/src/main/AndroidManifest.xml


E inclua as permissões necessárias:

<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Android 12+ -->
<uses-permission
android:name="android.permission.BLUETOOTH_SCAN"
android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />


❗ Sem essas permissões, o scan não funcionará no Android 12+.

📱 Exemplo Completo de Uso

Aqui está um exemplo funcional com:

Scan

Conexão

Impressão simples

Gestão de permissões

UI completa

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:blue_thermal_mais/blue_thermal_mais.dart';
import 'package:blue_thermal_mais/models/bluetooth_device_model.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
const MyApp({super.key});
@override
Widget build(BuildContext context) {
return MaterialApp(
home: const BluetoothPage(),
debugShowCheckedModeBanner: false,
);
}
}

class BluetoothPage extends StatefulWidget {
const BluetoothPage({super.key});
@override
State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
final _bt = BlueThermalMais();
List<BluetoothDeviceModel> devices = [];
BluetoothDeviceModel? connected;

bool isLoading = false;
bool bluetoothOn = false;
String platformVersion = '...';

@override
void initState() {
super.initState();
_init();
}

Future<void> _init() async {
platformVersion = await _bt.getPlatformVersion() ?? "Erro";
bluetoothOn = await _bt.isOn();
setState(() {});
}

Future<void> _requestPermissions() async {
final result = await [
Permission.bluetooth,
Permission.bluetoothScan,
Permission.bluetoothConnect,
Permission.location
].request();

    if (result.values.every((e) => e.isGranted)) {
      _scan();
    } else {
      _show("Permissões negadas.");
    }
}

void _scan() {
setState(() => isLoading = true);

    _bt.scan().listen((list) {
      setState(() {
        devices = list;
        isLoading = false;
      });
    });
}

Future<void> _connect(BluetoothDeviceModel device) async {
setState(() => isLoading = true);

    final ok = await _bt.connect(device);

    setState(() {
      isLoading = false;
      if (ok) connected = device;
    });

    _show(ok ? "Conectado!" : "Erro ao conectar.");
}

Future<void> _print() async {
final profile = await CapabilityProfile.load();
final gen = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];
    bytes += gen.text("TESTE DO BLUE THERMAL MAIS",
        styles: const PosStyles(bold: true, align: PosAlign.center));
    bytes += gen.hr();
    bytes += gen.text("Impressão concluída!");
    bytes += gen.feed(2);
    bytes += gen.cut();

    await _bt.printRaw(bytes);
}

void _show(String msg) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("BlueThermalMais"),
),
body: Column(
children: [
ListTile(
leading: Icon(
bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
color: bluetoothOn ? Colors.blue : Colors.red,
),
title: Text("Bluetooth: $bluetoothOn | OS: $platformVersion"),
),

          ElevatedButton(
            onPressed: _requestPermissions,
            child: Text(isLoading ? "Buscando..." : "Buscar dispositivos"),
          ),

          Expanded(
            child: devices.isEmpty
                ? const Center(child: Text("Nenhum dispositivo."))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (_, i) {
                      final d = devices[i];
                      return ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(d.name.isNotEmpty ? d.name : "Sem Nome"),
                        subtitle: Text(d.address),
                        trailing: connected?.address == d.address
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => _connect(d),
                      );
                    },
                  ),
          ),

          if (connected != null)
            SafeArea(
              child: ElevatedButton(
                onPressed: _print,
                child: const Text("Imprimir Teste"),
              ),
            ),
        ],
      ),
    );
}
}

📡 API do Plugin
🔍 Scan
_blueThermalMais.scan().listen((List<BluetoothDeviceModel> devices) {});

🔗 Conectar
await _blueThermalMais.connect(device);

❌ Desconectar
await _blueThermalMais.disconnect();

🖨 Impressão RAW
await _blueThermalMais.printRaw(bytes);

🎛 Verificar se está ligado
await _blueThermalMais.isOn();

📚 Modelo de Dispositivo
class BluetoothDeviceModel {
final String name;
final String address;
}

🧩 Compatibilidade
Recurso	Android	iOS
Scan Bluetooth	✔️	❌
Conectar	✔️	❌
Impressão RAW	✔️	❌
ESC/POS	✔️	❌

Atualmente somente Android suporta impressão Bluetooth.

🐛 Troubleshooting
❗ Bluetooth permission missing in manifest

Você não adicionou as permissões no AndroidManifest.xml.
Volte à seção Configuração Android.

❗ Scan não encontra dispositivos

Possíveis causas:

Bluetooth OFF

Permissões negadas

Impressora não está em modo visível

Impressora já conectada a outro dispositivo

Android 12+ sem BLUETOOTH_SCAN / CONNECT

❗ Impressão não sai ou sai cortada

Confirme que a impressora é ESC/POS

Verifique se o papel é 58mm ou ajuste:

Generator(PaperSize.mm80, profile);

🤝 Contribuições

Pull Requests são muito bem-vindos!
Encontrou um problema? Abra uma Issue no GitHub.

📄 Licença

Este projeto está licenciado sob a licença MIT.
Use livremente em projetos pessoais e comerciais.

❤️ Criado por

Mateus Polonini
Desenvolvedor Flutter & Python
Criador de apps profissionais com foco em performance e experiência do usuário.