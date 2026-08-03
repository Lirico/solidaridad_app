package com.solidaridad.poc_verifone

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var psdkBridge: PsdkBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = PsdkBridge(applicationContext)
        psdkBridge = bridge

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PsdkBridge.METHOD_CHANNEL,
        ).setMethodCallHandler(bridge)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PsdkBridge.EVENT_CHANNEL,
        ).setStreamHandler(bridge)
    }
}
