package br.com.bluethermalmais.blue_thermal_mais // Ajuste para seu package real

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    // UUID padrão para Impressoras Térmicas (SPP)
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var eventSink: EventChannel.EventSink? = null

    // Lista local para acumular dispositivos achados no scan
    private val scannedDevices = ArrayList<BluetoothDevice>()
    private var discoveryReceiver: BroadcastReceiver? = null

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
                startDiscovery()
                result.success(true)
            }

            "stopScan" -> {
                bluetoothAdapter?.cancelDiscovery()
                result.success(true)
            }

            "connect" -> {
                val address = call.argument<String>("address")
                if (address != null) {
                    connectToDevice(address, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Address required", null)
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
                    result.error("INVALID_ARGUMENT", "Bytes required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // --- Lógica de Scan e Discovery (Achar novos dispositivos) ---

    private fun startDiscovery() {
        // Limpa lista anterior
        scannedDevices.clear()

        // Adiciona primeiramente os pareados (para o usuário ver os que já tem)
        val bonded = bluetoothAdapter?.bondedDevices
        bonded?.forEach {
            if (!scannedDevices.contains(it)) scannedDevices.add(it)
        }
        sendUpdateToFlutter() // Envia inicial

        // Cancela scan anterior se houver
        if (bluetoothAdapter?.isDiscovering == true) {
            bluetoothAdapter?.cancelDiscovery()
        }

        // Configura o Receiver para pegar novos dispositivos
        if (discoveryReceiver == null) {
            discoveryReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val action = intent.action
                    if (BluetoothDevice.ACTION_FOUND == action) {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        // Adiciona se tiver nome e não estiver na lista
                        if (device != null && device.name != null) {
                            // Evita duplicatas
                            val exists = scannedDevices.any { it.address == device.address }
                            if (!exists) {
                                scannedDevices.add(device)
                                sendUpdateToFlutter()
                            }
                        }
                    }
                }
            }
            val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
            context?.registerReceiver(discoveryReceiver, filter)
        }

        // Inicia a busca real
        bluetoothAdapter?.startDiscovery()
    }

    private fun sendUpdateToFlutter() {
        val list = scannedDevices.map { device ->
            mapOf(
                "name" to (device.name ?: "Unknown"),
                "address" to device.address,
                // Útil para o Flutter saber se desenha ícone de "Salvo"
                "isPaired" to (device.bondState == BluetoothDevice.BOND_BONDED).toString()
            )
        }
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(list)
        }
    }

    // --- Lógica de Conexão e Pareamento ---

    private fun connectToDevice(address: String, result: Result) {
        // IMPORTANTE: Cancelar discovery antes de conectar, senão falha/fica lento
        bluetoothAdapter?.cancelDiscovery()

        Thread {
            try {
                val device = bluetoothAdapter?.getRemoteDevice(address)

                // 1. Lógica de Pareamento
                if (device?.bondState != BluetoothDevice.BOND_BONDED) {
                    // Tenta criar o pareamento
                    device?.createBond()

                    // Retorna erro específico avisando o Flutter que o processo iniciou.
                    // O Android vai mostrar o Pop-up de PIN na tela.
                    // O usuário deve aceitar e clicar em conectar novamente.
                    Handler(Looper.getMainLooper()).post {
                        result.error("PAIRING_INITIATED", "Pairing request sent. Accept on device and try again.", null)
                    }
                    return@Thread
                }

                // 2. Conexão Socket (Se já estiver pareado)
                bluetoothSocket?.close()

                // Criação do socket seguro
                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect() // Bloqueante

                bluetoothSocket = socket
                outputStream = socket.outputStream

                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }

            } catch (e: Exception) {
                try { bluetoothSocket?.close() } catch (e2: Exception) {}
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
                if (outputStream == null) throw IOException("Device not connected")
                outputStream?.write(bytes)
                outputStream?.flush() // Garante envio

                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                disconnectInternal()
                Handler(Looper.getMainLooper()).post {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }
        }.start()
    }

    // --- Ciclo de Vida do Stream ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        // Para o scan se o Flutter parar de ouvir para economizar bateria
        bluetoothAdapter?.cancelDiscovery()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        // Limpeza crucial
        if (discoveryReceiver != null) {
            context?.unregisterReceiver(discoveryReceiver)
            discoveryReceiver = null
        }
        disconnectInternal()
    }
}