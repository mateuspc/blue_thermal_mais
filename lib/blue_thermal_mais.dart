import 'package:flutter/services.dart'; // Necessário para PlatformException
import 'blue_thermal_mais_platform_interface.dart';
import 'models/bluetooth_device_model.dart';

class BlueThermalMais {
  Future<String?> getPlatformVersion() {
    return BlueThermalMaisPlatform.instance.getPlatformVersion();
  }

  Future<bool> isOn() {
    return BlueThermalMaisPlatform.instance.isOn();
  }

  /// Inicia o escaneamento.
  /// No Android: Inicia o Discovery (procura novos dispositivos não pareados).
  /// No iOS: Inicia o Scan BLE.
  Stream<List<BluetoothDeviceModel>> scan() {
    return BlueThermalMaisPlatform.instance.scan();
  }

  /// Para o escaneamento manualmente.
  /// É IMPORTANTE chamar isso antes de tentar conectar no Android para estabilidade.
  Future<void> stopScan() {
    return BlueThermalMaisPlatform.instance.stopScan();
  }

  /// Tenta conectar ao dispositivo.
  /// Retorna [true] se conectado com sucesso.
  /// Lança uma exceção amigável se o pareamento for iniciado (Android).
  Future<bool> connect(BluetoothDeviceModel device) async {
    try {
      // Boa prática: sempre parar o scan antes de conectar
      await stopScan();

      return await BlueThermalMaisPlatform.instance.connect(device.address);
    } on PlatformException catch (e) {
      if (e.code == 'PAIRING_INITIATED') {
        // O Android iniciou o processo de pareamento (popup de PIN).
        // Lançamos um erro legível para você mostrar um SnackBar/Toast na UI.
        throw Exception("Pareamento iniciado. Aceite a notificação no celular e tente conectar novamente.");
      } else if (e.code == 'NEEDS_BONDING') {
        throw Exception("O dispositivo precisa ser pareado nas configurações do Bluetooth primeiro.");
      }
      // Se for outro erro, apenas retornamos false ou repassamos o erro
      print("Erro ao conectar: ${e.message}");
      return false;
    }
  }

  Future<bool> disconnect() {
    return BlueThermalMaisPlatform.instance.disconnect();
  }

  /// Imprime bytes brutos.
  Future<bool> printRaw(List<int> bytes) {
    return BlueThermalMaisPlatform.instance.printRaw(bytes);
  }
}