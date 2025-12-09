import Flutter
import UIKit
import CoreBluetooth

public class BlueThermalMaisPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterStreamHandler {

    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?

    // Canais de comunicação
    var eventSink: FlutterEventSink?

    // Resultado pendente para conexão (para avisar o Flutter quando terminar)
    var pendingConnectionResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "blue_thermal_mais", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "blue_thermal_mais/scan", binaryMessenger: registrar.messenger())

        let instance = BlueThermalMaisPlugin()

        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        // Inicializa o manager
        instance.centralManager = CBCentralManager(delegate: instance, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "isOn":
            result(centralManager.state == .poweredOn)
        case "startScan":
            startScan()
            result(nil)
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let uuidString = args["address"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "UUID required", details: nil))
                return
            }
            connectToDevice(uuidString: uuidString, result: result)
        case "disconnect":
            disconnectDevice()
            result(true)
        case "print":
            guard let args = call.arguments as? [String: Any],
                  let flutterData = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Bytes required", details: nil))
                return
            }
            printData(data: flutterData.data, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Logic Adapted from your BluetoothViewModel

    func startScan() {
        discoveredPeripherals.removeAll()
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func connectToDevice(uuidString: String, result: @escaping FlutterResult) {
        // Procura na lista de descobertos
        if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == uuidString }) {
            self.pendingConnectionResult = result
            centralManager.stopScan()
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        } else {
            // Tenta recuperar pelo UUID se o sistema já conhece
            if let uuid = UUID(uuidString: uuidString),
               let known = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
                self.pendingConnectionResult = result
                centralManager.stopScan()
                connectedPeripheral = known
                known.delegate = self
                centralManager.connect(known, options: nil)
            } else {
                result(FlutterError(code: "NOT_FOUND", message: "Device not found in cache", details: nil))
            }
        }
    }

    func disconnectDevice() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }

    func printData(data: Data, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            result(FlutterError(code: "NOT_CONNECTED", message: "No active connection or characteristic", details: nil))
            return
        }

        // Define tipo de escrita baseada na característica (adaptado do seu código)
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: type)

        // Como BLE write pode ser assíncrono "fire and forget" para sem resposta:
        result(true)
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Opcional: Auto scan se desejar
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) && peripheral.name != nil {
            discoveredPeripherals.append(peripheral)
            sendUpdateToFlutter()
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Busca serviços assim que conecta
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        pendingConnectionResult?(FlutterError(code: "CONNECTION_ERROR", message: error?.localizedDescription, details: nil))
        pendingConnectionResult = nil
        connectedPeripheral = nil
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        writeCharacteristic = nil
    }

    // MARK: - CBPeripheralDelegate (Discovery Flow)

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Lógica do seu código: busca característica com permissão de escrita
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                self.writeCharacteristic = characteristic

                // Agora sim estamos prontos
                if let pending = pendingConnectionResult {
                    pending(true)
                    pendingConnectionResult = nil
                }
                return // Achou uma, para.
            }
        }
    }

    // MARK: - Helper to send data to Flutter

    func sendUpdateToFlutter() {
        guard let sink = eventSink else { return }

        let devicesList = discoveredPeripherals.map { p -> [String: String] in
            return [
                "name": p.name ?? "Sem Nome",
                "address": p.identifier.uuidString // No iOS usamos UUID, não MAC
            ]
        }
        sink(devicesList)
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
