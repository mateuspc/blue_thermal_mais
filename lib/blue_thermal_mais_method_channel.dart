import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'blue_thermal_mais_platform_interface.dart';
import 'models/bluetooth_device_model.dart';

class MethodChannelBlueThermalMais extends BlueThermalMaisPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('blue_thermal_mais');

  @visibleForTesting
  final eventChannel = const EventChannel('blue_thermal_mais/scan');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> isOn() async {
    final status = await methodChannel.invokeMethod<bool>('isOn');
    return status ?? false;
  }

  @override
  Stream<List<BluetoothDeviceModel>> scan() {
    // Inicia o scan nativo
    methodChannel.invokeMethod('startScan');

    // Escuta o stream de resultados
    return eventChannel.receiveBroadcastStream().map((dynamic event) {
      final List<dynamic> list = event;
      return list
          .map(
            (e) => BluetoothDeviceModel.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList();
    });
  }

  /// IMPLEMENTAÇÃO DO STOP SCAN
  @override
  Future<void> stopScan() async {
    await methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<bool> connect(String address) async {
    // Envia o address (String) para o nativo
    final result = await methodChannel.invokeMethod<bool>('connect', {
      'address': address,
    });
    return result ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final result = await methodChannel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  @override
  Future<bool> printRaw(List<int> bytes) async {
    final result = await methodChannel.invokeMethod<bool>('print', {
      'bytes': Uint8List.fromList(bytes),
    });
    return result ?? false;
  }
}
