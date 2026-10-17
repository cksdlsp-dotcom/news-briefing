param([Parameter(Mandatory = $true)][string]$Root)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Root).Path
$main = Join-Path $root 'app/src/main/java/com/simonbrs/autoscreenshot/MainActivity.kt'
$svc = Join-Path $root 'app/src/main/java/com/simonbrs/autoscreenshot/service/ScreenshotService.kt'
$manifest = Join-Path $root 'app/src/main/AndroidManifest.xml'
$appgradle = Join-Path $root 'app/build.gradle.kts'
function PatchExact([string]$file,[string]$before,[string]$after) {
  $txt=[System.IO.File]::ReadAllText($file,[System.Text.Encoding]::UTF8)
  $txt=$txt.Replace("`r`n","`n")
  $before=$before.Replace("`r`n","`n")
  $after=$after.Replace("`r`n","`n")
  if (-not $txt.Contains($before)) { throw "Missing patch anchor: $file :: $($before.Substring(0,[Math]::Min(50,$before.Length)))" }
  $first=$txt.IndexOf($before,[System.StringComparison]::Ordinal)
  if ($txt.IndexOf($before,$first+$before.Length,[System.StringComparison]::Ordinal) -ge 0) {throw "Ambiguous patch anchor: $file"}
  $txt=$txt.Replace($before,$after)
  [System.IO.File]::WriteAllText($file,$txt,([System.Text.UTF8Encoding]::new($false)))
}
function PatchBlock([string]$file,[string]$start,[string]$end,[string]$body) {
  $txt=[System.IO.File]::ReadAllText($file,[System.Text.Encoding]::UTF8)
  $txt=$txt.Replace("`r`n","`n")
  $start=$start.Replace("`r`n","`n")
  $end=$end.Replace("`r`n","`n")
  $body=$body.Replace("`r`n","`n")
  $a=$txt.IndexOf($start,[System.StringComparison]::Ordinal)
  if ($a -lt 0) {throw "Missing block start: $file"}
  $b=$txt.IndexOf($end,$a+$start.Length,[System.StringComparison]::Ordinal)
  if ($b -lt 0) {throw "Missing block end: $file"}
  $txt=$txt.Substring(0,$a)+$body+$txt.Substring($b)
  [System.IO.File]::WriteAllText($file,$txt,([System.Text.UTF8Encoding]::new($false)))
}

$before = @'
private var shouldAutoStart = false
'@
$after = @'
private var shouldAutoStart = false
    private var captureIntervalMs = 1000L
'@
PatchExact $main $before $after
$before = @'
private var isServiceRunning = false
'@
$after = @'
private var isServiceRunning by mutableStateOf(false)
'@
PatchExact $main $before $after
$before = @'
serviceIntent.putExtra(ScreenshotService.EXTRA_RESULT_DATA, result.data)
'@
$after = @'
serviceIntent.putExtra(ScreenshotService.EXTRA_RESULT_DATA, result.data)
                serviceIntent.putExtra(ScreenshotService.EXTRA_INTERVAL_MS, captureIntervalMs)
'@
PatchExact $main $before $after
$before = @'
onStartService = { startScreenshotCapture() },
'@
$after = @'
onStartService = { startScreenshotCapture(1000L) },
                        onStartSlowService = { startScreenshotCapture(2000L) },
'@
PatchExact $main $before $after
$before = @'
onStartService: () -> Unit,
    onStopService: () -> Unit
'@
$after = @'
onStartService: () -> Unit,
    onStartSlowService: () -> Unit,
    onStopService: () -> Unit
'@
PatchExact $main $before $after
$before = @'
This app will take screenshots every 10 seconds and organize them by date. Identical screenshots are automatically removed.
'@
$after = @'
Save up to 10 different PNG pages. Select a 1 or 2 second interval and turn pages manually.
'@
PatchExact $main $before $after
$before = @'
Button(onClick = onStartService) {
                    Text("Start Screenshot Service")
                }
'@
$after = @'
Button(onClick = onStartService) {
                    Text("Start · 1 second · 10 pages")
                }


                Spacer(modifier = Modifier.height(12.dp))
                Button(onClick = onStartSlowService) {
                    Text("Start · 2 seconds · 10 pages")
                }
'@
PatchExact $main $before $after
$before = @'
onStartService = {},
            onStopService = {}
'@
$after = @'
onStartService = {},
            onStartSlowService = {},
            onStopService = {}
'@
PatchExact $main $before $after
$before = @'
Screenshot service started - saving to /storage/emulated/0/Screenshot/YYYY/MM/DD/
'@
$after = @'
Capture started. Saves 10 PNG images in Pictures/CHAIGIDA_Test10
'@
PatchExact $main $before $after
$before = @'
private const val SCREENSHOT_INTERVAL_MS = 10000L // 10 seconds
'@
$after = @'
private const val MAX_SHOTS = 10
        const val EXTRA_INTERVAL_MS = "extra_interval_ms"
'@
PatchExact $svc $before $after
$before = @'
private val mainHandler = Handler(Looper.getMainLooper())
'@
$after = @'
private val mainHandler = Handler(Looper.getMainLooper())
    private var screenshotIntervalMs = 1000L
    private var previousPngHash: ByteArray? = null
    private val sessionName = java.text.SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(java.util.Date())
'@
PatchExact $svc $before $after
$before = @'
if (intent != null && intent.hasExtra(EXTRA_RESULT_DATA)) {
'@
$after = @'
if (intent != null && intent.hasExtra(EXTRA_RESULT_DATA)) {
                screenshotIntervalMs = intent.getLongExtra(EXTRA_INTERVAL_MS, 1000L).coerceIn(1000L, 2000L)
'@
PatchExact $svc $before $after
$before = @'
}, SCREENSHOT_INTERVAL_MS, SCREENSHOT_INTERVAL_MS, TimeUnit.MILLISECONDS)
'@
$after = @'
}, screenshotIntervalMs, screenshotIntervalMs, TimeUnit.MILLISECONDS)
'@
PatchExact $svc $before $after
$before = @'
Screenshot scheduler started with interval: $SCREENSHOT_INTERVAL_MS ms
'@
$after = @'
Screenshot scheduler started with interval: $screenshotIntervalMs ms
'@
PatchExact $svc $before $after
$before = @'
Taking screenshots every 10 seconds (Total: ${screenshotCount.get()})
'@
$after = @'
Saved ${screenshotCount.get()}/$MAX_SHOTS pages
'@
PatchExact $svc $before $after
$before = @'
val bitmapCopy = bitmap.copy(Bitmap.Config.ARGB_8888, false)
'@
$after = @'
val bitmapCopy = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
'@
PatchExact $svc $before $after
$before = @'
isServiceRunning = false
        
        // Shut down executor
'@
$after = @'
isServiceRunning = false
        getSharedPreferences("AutoScreenshotPrefs", Context.MODE_PRIVATE)
            .edit().putBoolean("service_running", false).apply()
        
        // Shut down executor
'@
PatchExact $svc $before $after
$before = @'
        <receiver
            android:name=".receiver.BootReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
'@
$after = @'
        <!-- Deliberately no auto-start: user grants each screen-capture session. -->
'@
PatchExact $manifest $before $after
$before = @'
applicationId = "com.simonbrs.autoscreenshot"
'@
$after = @'
applicationId = "com.chaigida.capture10"
'@
PatchExact $appgradle $before $after
$start = @'
    private fun startScreenshotCapture() {
'@
$end = @'
    private fun stopScreenshotService() {
'@
$body = @'
    private fun startScreenshotCapture(intervalMs: Long = 1000L) {
        captureIntervalMs = intervalMs
        requestMediaProjection()
    }




'@
PatchBlock $main $start $end $body
$start = @'
    private fun requestMediaProjection() {
'@
$end = @'
    private fun requestOverlayPermission() {
'@
$body = @'
    private fun requestMediaProjection() {
        mediaProjectionLauncher.launch(mediaProjectionManager.createScreenCaptureIntent())
    }




'@
PatchBlock $main $start $end $body
$start = @'
    private fun saveBitmapToFile(bitmap: Bitmap) {
'@
$end = @'
    private fun areFilesIdentical(file1: File, file2: File): Boolean {
'@
$body = @'
    private fun saveBitmapToFile(bitmap: Bitmap) {
        if (screenshotCount.get() >= MAX_SHOTS) return
        try {
            val buffer = java.io.ByteArrayOutputStream()
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, buffer)) return
            val png = buffer.toByteArray()
            val hash = java.security.MessageDigest.getInstance("SHA-256").digest(png)
            if (previousPngHash?.contentEquals(hash) == true) return


            val number = screenshotCount.get() + 1
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Images.Media.DISPLAY_NAME,
                    String.format(Locale.US, "%04d.png", number))
                put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(android.provider.MediaStore.Images.Media.RELATIVE_PATH,
                    "Pictures/CHAIGIDA_Test10/$sessionName")
                put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
            ) ?: throw IOException("MediaStore insert failed")
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(png) }
                    ?: throw IOException("Could not open image output")
                values.clear()
                values.put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } catch (e: Exception) {
                contentResolver.delete(uri, null, null)
                throw e
            }


            previousPngHash = hash
            val saved = screenshotCount.incrementAndGet()
            mainHandler.post {
                updateNotification()
                if (saved >= MAX_SHOTS) stopSelf()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save PNG", e)
        }
    }




'@
PatchBlock $svc $start $end $body
# Important: allow time to switch from the capture app to the reading app.
$before = @'
                            takeScreenshot()
                            
                            // Schedule the rest at fixed intervals
'@
$after = @'
                            // Wait for the user to switch to the intended screen.
                            // Schedule the rest at fixed intervals
'@
PatchExact $svc $before $after
$before = @'
}, screenshotIntervalMs, screenshotIntervalMs, TimeUnit.MILLISECONDS)
'@
$after = @'
}, 5000L, screenshotIntervalMs, TimeUnit.MILLISECONDS)
'@
PatchExact $svc $before $after
$before = @'
Taking first screenshot immediately
'@
$after = @'
Capturing begins after 5 seconds
'@
PatchExact $svc $before $after
$before = @'
override fun onResume() {
        super.onResume()
'@
$after = @'
override fun onResume() {
        super.onResume()
        isServiceRunning = prefs.getBoolean(KEY_SERVICE_RUNNING, false)
'@
PatchExact $main $before $after
$before = @'
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
                     tools:ignore="ScopedStorage" />
'@
$after = @'
    <!-- Scoped storage via MediaStore only; no all-files permission. -->
'@
PatchExact $manifest $before $after
$before = @'
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
'@
$after = @'
    <!-- No overlay permission required. -->
'@
PatchExact $manifest $before $after
$before = @'
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
'@
$after = @'
    <!-- No automatic capture on boot. -->
'@
PatchExact $manifest $before $after



# Avoid false "new pages" caused by clock, battery and navigation bar changes:
$before = @'
val hash = java.security.MessageDigest.getInstance("SHA-256").digest(png)
'@
$after = @'
val cropTop = (bitmap.height * 0.12f).toInt()
            val cropHeight = (bitmap.height * 0.76f).toInt()
            val body = Bitmap.createBitmap(bitmap, 0, cropTop, bitmap.width, cropHeight)
            val bodyStream = java.io.ByteArrayOutputStream()
            body.compress(Bitmap.CompressFormat.PNG, 100, bodyStream)
            body.recycle()
            val hash = java.security.MessageDigest.getInstance("SHA-256").digest(bodyStream.toByteArray())
'@
PatchExact $svc $before $after
$stringsPath = Join-Path $root 'app/src/main/res/values/strings.xml'
PatchExact $stringsPath 'AutoScreenshot' 'CHAIGIDA Capture10'
Write-Host 'Verified source patches applied.' -ForegroundColor Green
