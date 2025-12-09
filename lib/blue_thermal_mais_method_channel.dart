import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'blue_thermal_mais_platform_interface.dart';
import 'models/bluetooth_device_model.dart';

class MethodChannelBlueThermalMais extends BlueThermalMaisPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('blue_thermal_mais');

  // Canal de Eventos para receber o Scan em tempo real
  final eventChannel = const EventChannel('blue_thermal_mais/scan');

  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  @override
  Future<bool> isOn() async {
    final result = await methodChannel.invokeMethod<bool>('isOn');
    return result ?? false;
  }

  @override
  Stream<List<BluetoothDeviceModel>> scan() {
    // Inicia o scan no lado nativo
    methodChannel.invokeMethod('startScan');

    // Escuta o stream de resultados
    return eventChannel.receiveBroadcastStream().map((dynamic event) {
      List<dynamic> list = event;
      return list.map((e) => BluetoothDeviceModel.fromMap(e)).toList();
    });
  }

  @override
  Future<bool> connect(String address) async {
    try {
      final result = await methodChannel.invokeMethod<bool>('connect', {'address': address});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> printRaw(List<int> bytes) async {
    try {
      // Envia os bytes crus (Uint8List) para o nativo
      final result = await methodChannel.invokeMethod<bool>('print', {'bytes': Uint8List.fromList(bytes)});
      return result ?? false;
    } catch (e) {
      debugPrint("Erro ao imprimir: $e");
      return false;
    }
  }
}