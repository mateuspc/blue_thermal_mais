class BluetoothDeviceModel {
  final String name;
  final String address; // UUID no iOS, MAC Address no Android

  BluetoothDeviceModel({required this.name, required this.address});

  factory BluetoothDeviceModel.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothDeviceModel(
      name: map['name'] ?? 'Desconhecido',
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
    };
  }
}