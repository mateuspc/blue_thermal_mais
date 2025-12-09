import 'blue_thermal_mais_platform_interface.dart';
import 'models/bluetooth_device_model.dart';

class BlueThermalMais {
  Future<String?> getPlatformVersion() {
    return BlueThermalMaisPlatform.instance.getPlatformVersion();
  }

  Future<bool> isOn() {
    return BlueThermalMaisPlatform.instance.isOn();
  }

  Stream<List<BluetoothDeviceModel>> scan() {
    return BlueThermalMaisPlatform.instance.scan();
  }

  Future<bool> connect(BluetoothDeviceModel device) {
    return BlueThermalMaisPlatform.instance.connect(device.address);
  }

  Future<bool> disconnect() {
    return BlueThermalMaisPlatform.instance.disconnect();
  }

  /// Imprime bytes brutos. 
  /// Dica: Use uma lib como 'esc_pos_utils' no Flutter para gerar esses bytes.
  Future<bool> printRaw(List<int> bytes) {
    return BlueThermalMaisPlatform.instance.printRaw(bytes);
  }
}