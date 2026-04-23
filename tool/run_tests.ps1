# Runs Flutter tests and writes timestamped reports to reports/tests/<timestamp>.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tool\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File .\tool\run_tests.ps1 -SkipHtmlCoverage

[CmdletBinding()]
param(
  [string]$ProjectRoot = ".",
  [switch]$SkipHtmlCoverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path $ProjectRoot).Path

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  Write-Host "==> $Name" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "Step failed: $Name (exit code $LASTEXITCODE)"
  }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDir = Join-Path "reports\tests" $timestamp
$machineReportPath = Join-Path $reportDir "flutter_test_machine.jsonl"
$consoleLogPath = Join-Path $reportDir "flutter_test_console.log"
$coveragePath = "coverage\lcov.info"
$coverageCopyPath = Join-Path $reportDir "lcov.info"
$htmlCoverageDir = Join-Path $reportDir "coverage_html"
$prioritySuiteTests = @(
  # Core
  "test/core/network/http_client_test.dart"
  "test/core/utils/display_name_test.dart"
  # Bookmarks
  "test/features/bookmarks/data/bookmark_repository_impl_test.dart"
  "test/features/bookmarks/presentation/providers/bookmark_notifier_test.dart"
  "test/features/bookmarks/presentation/screens/bookmarks_screen_test.dart"
  # Pokémon search
  "test/features/pokemon_search/data/models/pokemon_list_item_model_test.dart"
  "test/features/pokemon_search/data/models/pokemon_detail_model_test.dart"
  "test/features/pokemon_search/data/repositories/pokemon_repository_impl_test.dart"
  "test/features/pokemon_search/presentation/providers/pokemon_search_controller_test.dart"
  "test/features/pokemon_search/presentation/screens/detail_screen_test.dart"
  # Weather
  "test/features/weather/data/models/weather_models_test.dart"
  "test/features/weather/data/repositories/weather_repository_impl_test.dart"
  "test/features/weather/presentation/providers/weather_state_test.dart"
  "test/features/weather/presentation/providers/weather_controller_test.dart"
  "test/features/weather/presentation/screens/weather_pokemon_screen_test.dart"
  # App smoke
  "test/widget_test.dart"
)

Push-Location $ProjectRoot
try {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not available on PATH."
  }

  Invoke-Step -Name "Run priority regression suite (all test files)" -Action {
    & flutter test @prioritySuiteTests 1>> $consoleLogPath 2>&1
  }

  Invoke-Step -Name "Run tests with machine output" -Action {
    & flutter test --machine 1> $machineReportPath 2> $consoleLogPath
  }

  Invoke-Step -Name "Run tests with coverage" -Action {
    & flutter test --coverage 1>> $consoleLogPath 2>&1
  }

  if (-not (Test-Path $coveragePath)) {
    throw "Coverage file was not generated at: $coveragePath"
  }
  Copy-Item -Path $coveragePath -Destination $coverageCopyPath -Force

  if (-not $SkipHtmlCoverage) {
    $genhtmlCommand = Get-Command genhtml -ErrorAction SilentlyContinue
    if ($genhtmlCommand) {
      Write-Host "==> Build HTML coverage report" -ForegroundColor Cyan
      & $genhtmlCommand.Source $coverageCopyPath -o $htmlCoverageDir 1>> $consoleLogPath 2>&1
      if ($LASTEXITCODE -ne 0) {
      Write-Warning "genhtml failed. lcov report is still available at .\$coverageCopyPath"
      }
    } else {
      Write-Warning "genhtml not found on PATH. Skipping HTML coverage generation."
    }
  }

  Write-Host ""
  Write-Host "Reports generated:" -ForegroundColor Green
  Write-Host "  - Machine report: .\$machineReportPath"
  Write-Host "  - Console log:    .\$consoleLogPath"
  Write-Host "  - LCOV report:    .\$coverageCopyPath"
  if (Test-Path $htmlCoverageDir) {
    Write-Host "  - HTML coverage:  .\$htmlCoverageDir\index.html"
  }
}
catch {
  Write-Error $_
  exit 1
}
finally {
  Pop-Location
}
