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
    var methodChannel: FlutterMethodChannel?

    // Resultado pendente para conexão
    var pendingConnectionResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "blue_thermal_mais", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "blue_thermal_mais/scan", binaryMessenger: registrar.messenger())

        let instance = BlueThermalMaisPlugin()
        instance.methodChannel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        // Inicializa o manager (Apenas cria, não escaneia ainda)
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
            result(nil) // Retorno imediato, dados vão via Stream

        case "stopScan":
            centralManager.stopScan()
            result(true)

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

    // MARK: - Lógica de Bluetooth

    func startScan() {
        discoveredPeripherals.removeAll()
        // Limpa a lista na UI do Flutter enviando lista vazia
        eventSink?([])

        if centralManager.state == .poweredOn {
            // Escaneia tudo (nil em services).
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func connectToDevice(uuidString: String, result: @escaping FlutterResult) {
        // 1. Tenta achar na lista de escaneados recentes
        if let peripheral = discoveredPeripherals.first(where: { $0.identifier.uuidString == uuidString }) {
            initiateConnection(peripheral, result: result)
        }
        // 2. Se não achou, tenta recuperar pelo UUID (caso o app tenha sido reiniciado)
        else if let uuid = UUID(uuidString: uuidString),
                let known = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            initiateConnection(known, result: result)
        } else {
            result(FlutterError(code: "NOT_FOUND", message: "Device not found", details: nil))
        }
    }

    func initiateConnection(_ peripheral: CBPeripheral, result: @escaping FlutterResult) {
        self.pendingConnectionResult = result
        centralManager.stopScan()

        // Se já estiver conectado, apenas retornamos sucesso
        if peripheral.state == .connected {
             peripheral.delegate = self
             self.connectedPeripheral = peripheral
             // Dispara descoberta de serviços novamente só por garantia
             peripheral.discoverServices(nil)
             return
        }

        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnectDevice() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }

    func printData(data: Data, result: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            result(FlutterError(code: "NOT_CONNECTED", message: "No active connection", details: nil))
            return
        }

        // Detecta se a impressora suporta resposta ou não
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: type)

        // Para WriteWithoutResponse, o retorno é imediato.
        // Para WithResponse, deveríamos esperar o delegate, mas simplificamos aqui.
        result(true)
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Opcional: Notificar Flutter que o estado do BT mudou
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filtro básico: Apenas dispositivos com nome
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) && peripheral.name != nil {
            discoveredPeripherals.append(peripheral)
            sendUpdateToFlutter()
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
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
        // Opcional: Avisar o Flutter que desconectou via MethodChannel
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            // Procura característica de escrita
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                self.writeCharacteristic = characteristic

                // Conexão concluída com sucesso!
                if let pending = pendingConnectionResult {
                    pending(true)
                    pendingConnectionResult = nil
                }
                return
            }
        }
    }

    // MARK: - Helper Stream

    func sendUpdateToFlutter() {
        guard let sink = eventSink else { return }
        let devicesList = discoveredPeripherals.map { p -> [String: String] in
            return [
                "name": p.name ?? "Unknown",
                "address": p.identifier.uuidString // UUID no iOS
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