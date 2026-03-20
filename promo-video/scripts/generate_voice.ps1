param(
  [string]$SceneFile = 'src\voice-lines.json',
  [string]$AudioDir = 'public\audio',
  [string]$VoicePattern = 'Microsoft Zira Desktop*'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$scenePath = Join-Path $root $SceneFile
$audioPath = Join-Path $root $AudioDir

New-Item -ItemType Directory -Force $audioPath | Out-Null

$voice = New-Object -ComObject SAPI.SpVoice
$selectedVoice = $voice.GetVoices() | Where-Object {
  $_.GetDescription() -like $VoicePattern
} | Select-Object -First 1

if (-not $selectedVoice) {
  throw "未找到可用语音：$VoicePattern"
}

$voice.Voice = $selectedVoice
$voice.Rate = 0
$voice.Volume = 100

$stream = New-Object -ComObject SAPI.SpFileStream
$ssfmCreateForWrite = 3

$lines = Get-Content $scenePath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($line in $lines) {
  $target = Join-Path $audioPath ($line.id + '.wav')
  $stream.Open($target, $ssfmCreateForWrite)
  $voice.AudioOutputStream = $stream
  [void]$voice.Speak($line.voice)
  $stream.Close()
}

$voice.AudioOutputStream = $null
