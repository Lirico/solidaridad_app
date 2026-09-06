package com.solidaridad.poc_verifone

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.verifone.sdi.payment_sdk.CommerceListenerAdapter
import com.verifone.sdi.payment_sdk.PaymentSdk
import com.verifone.sdi.payment_sdk.SdiManager
import com.verifone.sdi.payment_sdk.SdiResultCode
import com.verifone.sdi.payment_sdk.SdiTlv
import com.verifone.sdi.payment_sdk.Status
import com.verifone.sdi.payment_sdk.StatusCode
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.gson.GsonBuilder
import java.nio.charset.Charset
import java.util.concurrent.Executors

/**
 * Thin Android bridge around Verifone PaymentSDK-SDI 4.x.
 *
 * Dart talks to this via:
 * - MethodChannel [METHOD_CHANNEL]
 * - EventChannel [EVENT_CHANNEL] (status / lifecycle events)
 *
 * POC note: MSR payloads are returned unmasked for lab/test cards.
 */
class PsdkBridge(private val appContext: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.solidaridad.poc_verifone/psdk"
        const val EVENT_CHANNEL = "com.solidaridad.poc_verifone/psdk_events"
        private const val TAG = "PsdkBridge"

        private const val TAG_MESSAGE = 0xF0
        private const val TAG_TRACK1 = 0x56L
        private const val TAG_TRACK2 = 0x57L
        private const val TAG_PAN = 0x5AL
        private const val TAG_EXPIRY = 0x5F24L

        /** Campos sensibles que se enmascaran en [logPayload]. */
        private val SENSITIVE_KEYS = setOf(
            "pan", "panHex", "panAscii", "panLength",
            "track1", "track2", "track1Hex", "track2Hex",
            "cardTokenHex", "responseToString", "rawResponseHex",
        )
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val gson = GsonBuilder().setPrettyPrinting().create()
    private var paymentSdk: PaymentSdk? = null
    private var sdiManager: SdiManager? = null
    private var lastStatus: Map<String, Any?>? = null
    private var initialized = false
    private var eventSink: EventChannel.EventSink? = null
    private var readCancelled = false


    private val commerceListener = object : CommerceListenerAdapter() {
        override fun handleStatus(status: Status) {
            val payload = statusToMap(status)
            lastStatus = payload
            val ok = status.status == StatusCode.SUCCESS
            if (ok) {
                sdiManager = paymentSdk?.sdiManager
                initialized = sdiManager != null
                Log.i(TAG, "PaymentSDK init OK; SDI ready=$initialized")
            } else {
                sdiManager = null
                initialized = false
                Log.w(TAG, "PaymentSDK status not SUCCESS: ${status.message} (${status.status})")
            }
            emit(payload)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "tearDown" -> tearDown(result)
            "getStatus" -> result.success(getStatusSnapshot())
            "getDeviceInfo" -> result.success(getDeviceInfo())
            "readMsr" -> {
                val timeoutSec = (call.argument<Int>("timeoutSec") ?: 30).coerceIn(1, 128)
                readMsr(timeoutSec, result)
            }
            "cancelReadMsr" -> cancelReadMsr(result)
            "printHtml" -> {

                val html = call.argument<String>("html")
                if (html.isNullOrBlank()) {
                    result.error("PSDK_BAD_ARGS", "html is required", null)
                } else {
                    val landscape = call.argument<Boolean>("landscape") ?: false
                    printHtml(html, landscape, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        lastStatus?.let { emit(it) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun initialize(result: MethodChannel.Result) {
        try {
            if (paymentSdk != null) {
                result.success(
                    mapOf(
                        "ok" to initialized,
                        "alreadyInitialized" to true,
                        "sdiReady" to (sdiManager != null),
                        "message" to "SDK already created; waiting for / using last status",
                    ),
                )
                return
            }
            Log.d(TAG, "Creating PaymentSdk 4.1.0-sdi…")
            paymentSdk = PaymentSdk.create(appContext)
            paymentSdk?.initialize(commerceListener)
            result.success(
                mapOf(
                    "ok" to true,
                    "alreadyInitialized" to false,
                    "sdiReady" to false,
                    "message" to "initialize() called; listen to events for SUCCESS",
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "initialize failed", e)
            result.error("PSDK_INIT_FAILED", e.message, e.javaClass.name)
        }
    }

    private fun tearDown(result: MethodChannel.Result) {
        try {
            paymentSdk?.tearDown()
            paymentSdk = null
            sdiManager = null
            initialized = false
            lastStatus = mapOf(
                "type" to "tearDown",
                "status" to StatusCode.SUCCESS,
                "message" to "torn down",
                "sdiReady" to false,
            )
            emit(lastStatus!!)
            result.success(mapOf("ok" to true))
        } catch (e: Exception) {
            Log.e(TAG, "tearDown failed", e)
            result.error("PSDK_TEARDOWN_FAILED", e.message, e.javaClass.name)
        }
    }

    private fun getStatusSnapshot(): Map<String, Any?> {
        return mapOf(
            "created" to (paymentSdk != null),
            "initialized" to initialized,
            "sdiReady" to (sdiManager != null),
            "lastStatus" to lastStatus,
        )
    }

    private fun getDeviceInfo(): Map<String, Any?> {
        val sdk = paymentSdk
            ?: return mapOf("ok" to false, "message" to "SDK not created; call initialize first")
        return try {
            val info = sdk.deviceInformation
            if (info == null) {
                mapOf("ok" to false, "message" to "deviceInformation is null")
            } else {
                mapOf(
                    "ok" to true,
                    "serialNumber" to info.serialNumber,
                    "model" to info.model,
                    "connectionType" to info.connectionType,
                    "address" to info.address,
                    "macAddress" to info.macAddress,
                    "paymentAppName" to info.paymentAppName,
                    "paymentAppVersion" to info.paymentAppVersion,
                    "paymentProtocol" to info.paymentProtocol,
                    "friendlyName" to info.friendlyName,
                    "logicalDeviceId" to info.logicalDeviceId,
                    "state" to info.state?.name,
                    "sdiReady" to (sdiManager != null),
                )
            }
        } catch (e: Exception) {
            mapOf("ok" to false, "message" to (e.message ?: e.javaClass.name))
        }
    }

    /**
     * Blocks on a worker thread until swipe or timeout.
     * Returns MSR response fields plus txn tags (often clearer when VCL obfuscates the direct fields).
     */
    /**
     * Cancela una lectura MSR en curso.
     *
     * El SDK de Verifone no expone una cancelación síncrona de `msr.read`, así
     * que esto marca un flag que el worker de [readMsr] consulta al terminar:
     * si la lectura fue cancelada, no se postea el resultado al canal (evitando
     * que Dart navegue o toque el contexto desmontado). Debe llamarse antes de
     * [tearDown] para no apagar el SDK con la lectura todavía activa.
     */
    private fun cancelReadMsr(result: MethodChannel.Result) {
        readCancelled = true
        Log.i(TAG, "MSR read cancellation requested")
        result.success(mapOf("ok" to true, "cancelled" to true))
    }

    private fun readMsr(timeoutSec: Int, result: MethodChannel.Result) {
        val sdi = sdiManager
        if (sdi == null) {
            result.error("PSDK_NOT_READY", "SDI not ready; call initialize and wait for sdiReady", null)
            return
        }

        readCancelled = false
        worker.execute {
            try {
                Log.i(TAG, "MSR read starting (timeoutSec=$timeoutSec). Swipe the card.")
                val vclDiag = readVclDiagnostics(sdi)

                val response = sdi.msr.read(timeoutSec.toByte())
                val code = response.result
                if (readCancelled) {
                    Log.i(TAG, "MSR read cancelled; discarding result")
                    return@execute
                }

                val pan = response.pan
                val msrMap = mapOf(
                    "result" to code.name,
                    "panLength" to (pan?.size ?: -1),
                    "panAscii" to bytesAsAscii(pan),
                    "panHex" to bytesAsHex(pan),
                    "name" to response.name,
                    "serviceCode" to response.service,
                    "track1" to response.track1,
                    "track2" to response.track2,
                    "trackStatusHex" to bytesAsHex(response.trackStatus),
                    "cardTokenHex" to bytesAsHex(response.cardToken),
                    "responseToString" to response.toString(),
                )

                val shouldFetchTags =
                    code == SdiResultCode.OK || code == SdiResultCode.ERR_EXECUTION
                // cleartextDate=true: ask for clear expiry when VCL allows whitelisted ranges.
                val tagsMap = if (shouldFetchTags) {
                    fetchTxnTags(sdi, cleartextDate = true)
                } else {
                    emptyMap()
                }

                val hasClearData = hasUsefulCleartext(
                    msrMap["panHex"] as? String,
                    msrMap["panAscii"] as? String,
                    msrMap["track1"] as? String,
                    msrMap["track2"] as? String,
                    tagsMap["panHex"] as? String,
                    tagsMap["pan"] as? String,
                    tagsMap["track1Hex"] as? String,
                    tagsMap["track2Hex"] as? String,
                    tagsMap["track1"] as? String,
                    tagsMap["track2"] as? String,
                )

                val payload = mapOf(
                    "ok" to (code == SdiResultCode.OK && hasClearData),
                    "swipeSeen" to (code == SdiResultCode.OK || code == SdiResultCode.ERR_EXECUTION),
                    "hasClearData" to hasClearData,
                    "timedOut" to (code == SdiResultCode.ERR_TIMEOUT),
                    "timeoutSec" to timeoutSec,
                    "msr" to msrMap,
                    "tags" to tagsMap,
                    "vcl" to vclDiag,
                    "hint" to
                        "ERR_EXECUTION + empty tracks usually means VCL/SRED is on and the " +
                        "terminal will not return clear PAN/track without a BIN whitelist " +
                        "(whitelist.json / cardranges) or a lab profile that disables VCL. " +
                        "Ask Verifone to install whitelist for your test BINs, or provide " +
                        "encrypted getEncData path.",
                )
                logPayload("MSR_READ", payload)
                mainHandler.post { result.success(payload) }
            } catch (e: Exception) {
                Log.e(TAG, "readMsr failed", e)
                mainHandler.post {
                    result.error("PSDK_MSR_FAILED", e.message, e.javaClass.name)
                }
            }
        }
    }

    /**
     * Prints an HTML ticket via [SdiManager.printer] (SDI 25-02).
     * Requires a prior successful [initialize] with sdiReady.
     */
    private fun printHtml(html: String, landscape: Boolean, result: MethodChannel.Result) {
        val sdi = sdiManager
        if (sdi == null) {
            result.error("PSDK_NOT_READY", "SDI not ready; call initialize and wait for sdiReady", null)
            return
        }

        worker.execute {
            try {
                Log.i(TAG, "printHTML starting (landscape=$landscape, chars=${html.length})")
                val code = sdi.printer.printHTML(html, landscape)
                val payload = mapOf(
                    "ok" to (code == SdiResultCode.OK),
                    "result" to code.name,
                    "landscape" to landscape,
                    "htmlLength" to html.length,
                )
                logPayload("PRINT_HTML", payload)
                mainHandler.post { result.success(payload) }
            } catch (e: Exception) {
                Log.e(TAG, "printHtml failed", e)
                mainHandler.post {
                    result.error("PSDK_PRINT_FAILED", e.message, e.javaClass.name)
                }
            }
        }
    }

    private fun readVclDiagnostics(sdi: SdiManager): Map<String, Any?> {
        return try {
            val status = sdi.vcl.statusRequest()
            val keyStatus = sdi.vcl.keyStatus
            mapOf(
                "statusResult" to status.result.name,
                "statusHex" to bytesAsHex(status.response),
                "keyStatusResult" to keyStatus.result.name,
                "keyStatusValue" to keyStatus.response,
            )
        } catch (e: Exception) {
            mapOf(
                "statusResult" to "EXCEPTION",
                "message" to (e.message ?: e.javaClass.name),
            )
        }
    }

    private fun fetchTxnTags(sdi: SdiManager, cleartextDate: Boolean): Map<String, Any?> {
        return try {
            val tagIds = arrayListOf(TAG_TRACK1, TAG_TRACK2, TAG_PAN, TAG_EXPIRY)
            val binary = sdi.data.fetchTxnTags(tagIds, 2.toShort(), cleartextDate)
            val resultCode = binary.result
            val raw = binary.response
            val out = mutableMapOf<String, Any?>(
                "fetchResult" to resultCode.name,
                "cleartextDate" to cleartextDate,
                "rawResponseHex" to bytesAsHex(raw),
                "rawLength" to (raw?.size ?: 0),
            )
            if (resultCode != SdiResultCode.OK || raw == null || raw.isEmpty()) {
                return out
            }

            val root = SdiTlv.create()
            if (!root.load(raw, false)) {
                out["parseError"] = "SdiTlv.load failed"
                return out
            }

            val message = root.obtain(TAG_MESSAGE)
            val panBytes = message.obtain(TAG_PAN.toInt()).store(false)
            val track1Bytes = message.obtain(TAG_TRACK1.toInt()).store(false)
            val track2Bytes = message.obtain(TAG_TRACK2.toInt()).store(false)
            val expiryBytes = message.obtain(TAG_EXPIRY.toInt()).store(false)

            val panHex = bytesAsHex(panBytes)
            val track1Ascii = bytesAsAscii(track1Bytes)
            val track2Hex = bytesAsHex(track2Bytes)
            val track2Ascii = bytesAsBcdAscii(track2Bytes)
            val expiryHex = bytesAsHex(expiryBytes)

            out["panHex"] = panHex
            out["pan"] = panHex.trimEnd('F', 'f')
            out["track1Hex"] = bytesAsHex(track1Bytes)
            out["track1"] = track1Ascii
            out["track2Hex"] = track2Hex
            out["track2"] = track2Ascii.ifBlank { track2Hex }
            out["expiryHex"] = expiryHex
            out["expiry"] = expiryHex
            out

        } catch (e: Exception) {
            Log.e(TAG, "fetchTxnTags failed", e)
            mapOf(
                "fetchResult" to "EXCEPTION",
                "message" to (e.message ?: e.javaClass.name),
            )
        }
    }

    private fun statusToMap(status: Status): Map<String, Any?> {
        return mapOf(
            "type" to status.type,
            "status" to status.status,
            "message" to status.message,
            "sessionId" to status.sessionId,
            "success" to (status.status == StatusCode.SUCCESS),
            "sdiReady" to (paymentSdk?.sdiManager != null && status.status == StatusCode.SUCCESS),
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    /**
     * Dump del payload a logcat (filter: adb logcat -s PsdkBridge), con los
     * campos sensibles (PAN, tracks, token) enmascarados para no exponer datos
     * de tarjeta en claro en los logs.
     */
    private fun logPayload(label: String, payload: Map<String, Any?>) {
        try {
            val json = gson.toJson(redactSensitive(payload))
            Log.i(TAG, "===== $label BEGIN =====")
            json.lineSequence().forEach { line -> Log.i(TAG, line) }
            Log.i(TAG, "===== $label END =====")
        } catch (e: Exception) {
            Log.i(TAG, "===== $label ===== [redacted]")
        }
    }

    /** Devuelve una copia del payload con los campos sensibles enmascarados. */
    private fun redactSensitive(value: Any?): Any? {
        return when (value) {
            is Map<*, *> -> value.entries.associate { (k, v) ->
                val key = k.toString()
                val redacted = if (key in SENSITIVE_KEYS) "[REDACTED]" else redactSensitive(v)
                key to redacted
            }
            is List<*> -> value.map { redactSensitive(it) }
            else -> value
        }
    }


    private fun bytesAsHex(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return ""
        return bytes.joinToString("") { "%02X".format(it) }
    }

    private fun bytesAsAscii(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return ""
        return bytes.toString(Charset.forName("US-ASCII"))
    }

    /**
     * Decodes a BCD-encoded track2 into its ASCII representation.
     *
     * Track2 in BCD packs two decimal digits per byte. Special nibbles:
     * - 0xB → ';' (start sentinel)
     * - 0xD → '=' (field separator)
     * - 0xF → '?' (end sentinel) or filler (dropped)
     * - 0xA → ':' (alternate separator)
     * - 0xC → '<' , 0xE → '>' (rare)
     *
     * Example: `B6063007014007403D3012F8` → `;6063007014007403=3012F8?`
     */
    private fun bytesAsBcdAscii(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return ""
        val sb = StringBuilder()
        for (b in bytes) {
            val hi = (b.toInt() shr 4) and 0x0F
            val lo = b.toInt() and 0x0F
            sb.append(bcdNibbleToChar(hi))
            sb.append(bcdNibbleToChar(lo))
        }
        return sb.toString()
    }

    private fun bcdNibbleToChar(nibble: Int): Char {
        return when (nibble) {
            in 0..9 -> '0' + nibble
            0xA -> ':'
            0xB -> ';'
            0xC -> '<'
            0xD -> '='
            0xE -> '>'
            0xF -> '?'
            else -> '?'
        }
    }

    /** True only if at least one field looks like real card data (not blank / not all FFs). */

    private fun hasUsefulCleartext(vararg values: String?): Boolean {
        return values.any { value ->
            val v = value?.trim().orEmpty()
            if (v.isEmpty()) return@any false
            val hexOnly = v.replace(" ", "").uppercase()
            if (hexOnly.matches(Regex("^[0-9A-F]+$"))) {
                // Reject all-F / all-0 placeholders from VCL redaction.
                if (hexOnly.all { it == 'F' } || hexOnly.all { it == '0' }) return@any false
                return@any hexOnly.any { it.isDigit() }
            }
            // ASCII track/PAN: need digits, not only replacement chars.
            v.any { it.isDigit() }
        }
    }
}
