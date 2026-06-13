param(
    [string]$OutputDir = (Join-Path (Split-Path $PSScriptRoot -Parent) "sounds")
)

# ============================================================
# Sound Generator — creates WAV files with pure PowerShell
# Generates simple chime/notification sounds using sine waves
# ============================================================

$ErrorActionPreference = "Stop"
$null = New-Item -ItemType Directory -Path $OutputDir -Force

function New-WavFile {
    param(
        [string]$FilePath,
        [double[]]$Samples,
        [int]$SampleRate = 44100
    )

    $bitsPerSample = 16
    $channels = 1
    $byteRate = $SampleRate * $channels * ($bitsPerSample / 8)
    $blockAlign = $channels * ($bitsPerSample / 8)
    $dataSize = $Samples.Length * ($bitsPerSample / 8)
    $fileSize = 36 + $dataSize

    $fs = [System.IO.File]::Create($FilePath)
    $writer = [System.IO.BinaryWriter]::new($fs)

    try {
        # RIFF header
        $writer.Write([char[]]'RIFF')
        $writer.Write([int]$fileSize)
        $writer.Write([char[]]'WAVE')

        # fmt chunk
        $writer.Write([char[]]'fmt ')
        $writer.Write([int]16)           # chunk size
        $writer.Write([int16]1)          # PCM
        $writer.Write([int16]$channels)
        $writer.Write([int]$SampleRate)
        $writer.Write([int]$byteRate)
        $writer.Write([int16]$blockAlign)
        $writer.Write([int16]$bitsPerSample)

        # data chunk
        $writer.Write([char[]]'data')
        $writer.Write([int]$dataSize)

        # clamp and write samples
        foreach ($s in $Samples) {
            $clamped = [math]::Max(-1.0, [math]::Min(1.0, $s))
            $writer.Write([int16]([math]::Round($clamped * 32767)))
        }
    }
    finally {
        $writer.Close()
        $fs.Close()
    }
}

function Generate-Tone {
    param(
        [double]$Frequency,
        [double]$Duration,         # seconds
        [double]$SampleRate = 44100,
        [double]$Volume = 0.5,
        [double]$FadeIn = 0.02,
        [double]$FadeOut = 0.05
    )
    $n = [int]($SampleRate * $Duration)
    $samples = [double[]]::new($n)
    $fadeInSamples = [int]($SampleRate * $FadeIn)
    $fadeOutSamples = [int]($SampleRate * $FadeOut)

    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $SampleRate
        $envelope = 1.0
        if ($i -lt $fadeInSamples) {
            $envelope = $i / $fadeInSamples
        }
        if ($i -ge ($n - $fadeOutSamples)) {
            $envelope = ($n - $i) / $fadeOutSamples
        }
        $samples[$i] = $Volume * $envelope * [math]::Sin(2 * [math]::PI * $Frequency * $t)
    }
    return $samples
}

function Generate-MultiTone {
    param(
        [double[]]$Frequencies,
        [double]$NoteDuration,
        [double]$SampleRate = 44100,
        [double]$Volume = 0.5,
        [double]$FadeOut = 0.08
    )
    $totalSamples = 0
    foreach ($f in $Frequencies) {
        $totalSamples += [int]($SampleRate * $NoteDuration)
    }
    $samples = [double[]]::new($totalSamples)
    $offset = 0
    $fadeIn = 0.01
    $fadeOutSamples = [int]($SampleRate * $FadeOut)

    foreach ($freq in $Frequencies) {
        $n = [int]($SampleRate * $NoteDuration)
        for ($i = 0; $i -lt $n; $i++) {
            $t = $i / $SampleRate
            $env = 1.0
            if ($i -lt [int]($SampleRate * $fadeIn)) {
                $env = $i / [int]($SampleRate * $fadeIn)
            }
            if ($i -ge ($n - $fadeOutSamples)) {
                $env = ($n - $i) / $fadeOutSamples
            }
            $samples[$offset + $i] = $Volume * $env * [math]::Sin(2 * [math]::PI * $freq * $t)
        }
        $offset += $n
    }
    return $samples
}

function Generate-SoftNoise {
    param(
        [double]$Duration,
        [double]$SampleRate = 44100,
        [double]$Volume = 0.15
    )
    $n = [int]($SampleRate * $Duration)
    $samples = [double[]]::new($n)
    $fadeSamples = [int]($SampleRate * 0.01)
    $rng = [System.Random]::new()

    for ($i = 0; $i -lt $n; $i++) {
        $env = 1.0
        if ($i -lt $fadeSamples) { $env = $i / $fadeSamples }
        if ($i -ge ($n - $fadeSamples)) { $env = ($n - $i) / $fadeSamples }
        $samples[$i] = $Volume * $env * ($rng.NextDouble() * 2 - 1)
    }
    return $samples
}

# ---- Generate sounds ----

Write-Host "Generating sounds..." -ForegroundColor Cyan

# === Stop / Task Complete Sounds ===

# Classic Chime: ascending C5 → E5
$samples = Generate-MultiTone -Frequencies @(523.25, 659.25) -NoteDuration 0.2 -Volume 0.4
New-WavFile -FilePath (Join-Path $OutputDir "done-classic.wav") -Samples $samples

# Soft Done: single gentle A4
$samples = Generate-Tone -Frequency 440.0 -Duration 0.35 -Volume 0.35 -FadeOut 0.1
New-WavFile -FilePath (Join-Path $OutputDir "done-soft.wav") -Samples $samples

# Fanfare: C5 → E5 → G5 (ascending triad)
$samples = Generate-MultiTone -Frequencies @(523.25, 659.25, 783.99) -NoteDuration 0.15 -Volume 0.4
New-WavFile -FilePath (Join-Path $OutputDir "done-fanfare.wav") -Samples $samples

# Pop: short burst with noise
$samples = Generate-Tone -Frequency 800.0 -Duration 0.08 -Volume 0.5 -FadeIn 0.001 -FadeOut 0.04
New-WavFile -FilePath (Join-Path $OutputDir "pop.wav") -Samples $samples

# === Notification Sounds ===

# Ding: high clear tone
$samples = Generate-Tone -Frequency 1046.50 -Duration 0.2 -Volume 0.3 -FadeOut 0.08
New-WavFile -FilePath (Join-Path $OutputDir "ding.wav") -Samples $samples

# Soft Beep
$samples = Generate-Tone -Frequency 880.0 -Duration 0.12 -Volume 0.25 -FadeIn 0.005 -FadeOut 0.06
New-WavFile -FilePath (Join-Path $OutputDir "beep-soft.wav") -Samples $samples

# Two-tone notification: descending G5 → E5
$samples = Generate-MultiTone -Frequencies @(783.99, 659.25) -NoteDuration 0.1 -Volume 0.3
New-WavFile -FilePath (Join-Path $OutputDir "notify-descend.wav") -Samples $samples

# === Alert / Permission Sounds ===

# Attention: medium frequency with emphasis
$samples = Generate-Tone -Frequency 660.0 -Duration 0.3 -Volume 0.45 -FadeIn 0.005 -FadeOut 0.1
New-WavFile -FilePath (Join-Path $OutputDir "alert.wav") -Samples $samples

# Warning: descending minor, slightly unsettling
$samples = Generate-MultiTone -Frequencies @(440.0, 349.23) -NoteDuration 0.25 -Volume 0.4
New-WavFile -FilePath (Join-Path $OutputDir "warning.wav") -Samples $samples

# Error: two staccato low tones
$samples = Generate-MultiTone -Frequencies @(300.0, 250.0) -NoteDuration 0.15 -Volume 0.5 -FadeOut 0.05
New-WavFile -FilePath (Join-Path $OutputDir "error.wav") -Samples $samples

# === Question / Elicitation Sounds ===

# Rising tone (question feel)
$sweepSamples = [double[]]::new([int](44100 * 0.3))
for ($i = 0; $i -lt $sweepSamples.Length; $i++) {
    $t = $i / 44100
    $freq = 400.0 + (800.0 * $t / 0.3)
    $env = if ($i -lt [int](44100 * 0.01)) { $i / [int](44100 * 0.01) }
           elseif ($i -ge ($sweepSamples.Length - [int](44100 * 0.08))) { ($sweepSamples.Length - $i) / [int](44100 * 0.08) }
           else { 1.0 }
    $sweepSamples[$i] = 0.35 * $env * [math]::Sin(2 * [math]::PI * $freq * $t)
}
New-WavFile -FilePath (Join-Path $OutputDir "question-rising.wav") -Samples $sweepSamples

# Double tone for clarification needed
$samples = Generate-MultiTone -Frequencies @(660.0, 880.0) -NoteDuration 0.12 -Volume 0.35
New-WavFile -FilePath (Join-Path $OutputDir "question-double.wav") -Samples $samples

Write-Host "Done! Generated sounds in: $OutputDir" -ForegroundColor Green
Write-Host "Files:" -ForegroundColor Cyan
Get-ChildItem $OutputDir -Filter "*.wav" | ForEach-Object { "  - $($_.Name) ($( [math]::Round($_.Length / 1KB, 1) ) KB)" }
