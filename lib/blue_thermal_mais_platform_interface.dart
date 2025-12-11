import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'blue_thermal_mais_method_channel.dart';
import 'models/bluetooth_device_model.dart';

abstract class BlueThermalMaisPlatform extends PlatformInterface {
  BlueThermalMaisPlatform() : super(token: _token);

  static final Object _token = Object();
  static BlueThermalMaisPlatform _instance = MethodChannelBlueThermalMais();

  static BlueThermalMaisPlatform get instance => _instance;

  static set instance(BlueThermalMaisPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // --- Métodos ---

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<bool> isOn() {
    throw UnimplementedError('isOn() has not been implemented.');
  }

  Stream<List<BluetoothDeviceModel>> scan() {
    throw UnimplementedError('scan() has not been implemented.');
  }

  /// NOVO: Método essencial para parar o scan antes de conectar
  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  Future<bool> connect(String address) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<bool> printRaw(List<int> bytes) {
    throw UnimplementedError('printRaw() has not been implemented.');
  }
}
