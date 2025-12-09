package br.com.bluethermalmais.blue_thermal_mais

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class BlueThermalMaisPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null

    // Variáveis Bluetooth
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    // UUID Padrão SPP
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    // Para Stream de Scan
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "blue_thermal_mais")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "blue_thermal_mais/scan")
        eventChannel.setStreamHandler(this)

        val bluetoothManager = context?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "isOn" -> result.success(bluetoothAdapter?.isEnabled == true)
            "startScan" -> {
                // No Android Classic Bluetooth, "Scan" geralmente é listar pareados
                // ou startDiscovery. Para impressoras, listar pareados é o mais comum/estável.
                scanPairedDevices()
                result.success(true)
            }
            "connect" -> {
                val address = call.argument<String>("address")
                if (address != null) {
                    connectToDevice(address, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Address is null", null)
                }
            }
            "disconnect" -> {
                disconnectInternal()
                result.success(true)
            }
            "print" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes != null) {
                    printData(bytes, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Bytes are null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // --- Lógica Bluetooth Baseada no seu Código ---

    private fun scanPairedDevices() {
        // Nota: Assumimos que as permissões BLUETOOTH_CONNECT já foram solicitadas pelo app Flutter
        try {
            val pairedDevices = bluetoothAdapter?.bondedDevices
            val list = ArrayList<Map<String, String>>()

            pairedDevices?.forEach { device ->
                val deviceMap = mapOf(
                    "name" to (device.name ?: "Unknown"),
                    "address" to device.address
                )
                list.add(deviceMap)
            }

            // Envia para o Flutter via Stream
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(list)
            }
        } catch (e: SecurityException) {
            // Log de erro
        }
    }

    private fun connectToDevice(address: String, result: Result) {
        // Executar em Thread separada para não travar a UI Thread
        Thread {
            try {
                val device = bluetoothAdapter?.getRemoteDevice(address)

                // Fecha anterior se existir
                bluetoothSocket?.close()

                // Cria Socket SPP
                // Nota: try/catch para SecurityException omitido para brevidade,
                // mas deve ser tratado em produção
                val socket = device?.createRfcommSocketToServiceRecord(SPP_UUID)
                socket?.connect()

                bluetoothSocket = socket
                outputStream = socket?.outputStream

                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                try {
                    bluetoothSocket?.close()
                } catch (e2: Exception) {}

                Handler(Looper.getMainLooper()).post {
                    result.error("CONNECTION_FAILED", e.message, null)
                }
            }
        }.start()
    }

    private fun disconnectInternal() {
        try {
            outputStream?.close()
            bluetoothSocket?.close()
            outputStream = null
            bluetoothSocket = null
        } catch (e: Exception) {}
    }

    private fun printData(bytes: ByteArray, result: Result) {
        Thread {
            try {
                if (outputStream == null) {
                    throw IOException("Not connected")
                }
                outputStream?.write(bytes)
                outputStream?.flush()

                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                disconnectInternal() // Se falhar escrita, desconecta
                Handler(Looper.getMainLooper()).post {
                    result.error("PRINT_FAILED", e.message, null)
                }
            }
        }.start()
    }

    // --- Stream Handler (EventChannel) ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Ao ouvir, já manda os pareados atuais
        scanPairedDevices()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        disconnectInternal()
    }
}