package com.babymonitor.baby_monitor

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.babymonitor/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPlatformInfo" -> {
                        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                        val isTV = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                        val isFireTV = Build.MANUFACTURER.equals("Amazon", ignoreCase = true)

                        result.success(
                            mapOf(
                                "isTV" to isTV,
                                "isFireTV" to (isTV && isFireTV)
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
