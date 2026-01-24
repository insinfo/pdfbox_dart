Param(
  [string]$PdfDir = "test/tmp/pdfs",
  [string]$PngDir = "test/tmp/png",
  [string]$TextDir = "test/tmp/text",
  [int]$Dpi = 96
)

$ErrorActionPreference = "Stop"

function Find-PdfBoxAppJar {
  # 1) Prefer an explicit env var
  if ($env:PDFBOX_APP_JAR -and (Test-Path $env:PDFBOX_APP_JAR)) {
    return (Resolve-Path $env:PDFBOX_APP_JAR).Path
  }

  # 2) Look for a locally built jar in the reference repo
  $refRoot = Join-Path $PSScriptRoot "..\referencias\pdfbox-java"
  if (Test-Path $refRoot) {
    $candidates = Get-ChildItem -Path $refRoot -Recurse -Filter "pdfbox-app-*.jar" -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match "\\target\\" } |
      Sort-Object FullName -Descending

    if ($candidates -and $candidates.Count -gt 0) {
      return $candidates[0].FullName
    }
  }

  return $null
}

function Build-PdfBoxJava {
  $refRoot = Join-Path $PSScriptRoot "..\referencias\pdfbox-java"
  if (!(Test-Path $refRoot)) {
    throw "Reference repo not found at $refRoot"
  }

  Write-Host "Building PDFBox Java (skip tests)…" -ForegroundColor Cyan
  Push-Location $refRoot
  try {
    # Requires Maven + JDK installed.
    mvn -DskipTests package
  } finally {
    Pop-Location
  }
}

$jar = Find-PdfBoxAppJar
if (-not $jar) {
  Build-PdfBoxJava
  $jar = Find-PdfBoxAppJar
}

if (-not $jar) {
  throw "Could not locate pdfbox-app-*.jar. Set PDFBOX_APP_JAR env var or build referencias/pdfbox-java."
}

$PdfDirAbs = Resolve-Path $PdfDir
$PngDirAbs = Join-Path (Resolve-Path (Split-Path $PngDir -Parent)).Path (Split-Path $PngDir -Leaf)
$TextDirAbs = Join-Path (Resolve-Path (Split-Path $TextDir -Parent)).Path (Split-Path $TextDir -Leaf)
New-Item -ItemType Directory -Force -Path $PngDirAbs | Out-Null
New-Item -ItemType Directory -Force -Path $TextDirAbs | Out-Null

Write-Host "Using PDFBox jar: $jar" -ForegroundColor Green
Write-Host "Rendering PDFs from: $PdfDirAbs" -ForegroundColor Green
Write-Host "Writing PNGs to:   $PngDirAbs" -ForegroundColor Green
Write-Host "Writing text to:   $TextDirAbs" -ForegroundColor Green

Get-ChildItem -Path $PdfDirAbs -Filter "*.pdf" | ForEach-Object {
  $pdf = $_.FullName
  $base = $_.Name

  # Output prefix without extension. PDFBox will append -<page>.png
  $prefix = Join-Path $PngDirAbs $base

  Write-Host "Rendering $base @ ${Dpi}dpi" -ForegroundColor Cyan

  # Use the standalone PDFBox CLI jar (main: org.apache.pdfbox.tools.PDFBox)
  # Subcommand "render" maps to PDFToImage.
  # Options are defined in tools/src/main/java/org/apache/pdfbox/tools/PDFToImage.java
  java -jar $jar render -dpi $Dpi -format png -outputPrefix $prefix -i $pdf

  $textOut = Join-Path $TextDirAbs "$base.txt"
  Write-Host "Extracting text for $base" -ForegroundColor Cyan
  # Subcommand "export:text" maps to ExtractText.
  java -jar $jar export:text -encoding UTF-8 -i $pdf -o $textOut
}
