#requires -Version 5.1
# Pipeline build-time; tidak menerima posisi pengguna.
[CmdletBinding()]
param(
    [string]$OsmPbf,
    [string]$OsmSha256,
    [string]$SourceUrl,
    [string]$WaterPolygonsUrl,
    [string]$Boundary,
    [string]$Output,
    [string]$Cache,
    [string]$Java = 'java',
    [string]$Python = 'python',
    [switch]$Force,
    [switch]$BoundsOnly
)
$ErrorActionPreference = 'Stop'
if (-not $Boundary) { $Boundary = Join-Path $PSScriptRoot 'campus-boundary.json' }
if (-not $Output) { $Output = Join-Path $PSScriptRoot '../../assets/map/ganesha.pmtiles' }
if (-not $Cache) { $Cache = Join-Path $PSScriptRoot '.cache' }
$arguments = @('-X', 'utf8', "$PSScriptRoot/tile_pipeline.py", '--boundary', $Boundary,
    '--output', $Output, '--cache', $Cache, '--java', $Java)
if ($OsmPbf) { $arguments += @('--osm-pbf', $OsmPbf) }
if ($OsmSha256) { $arguments += @('--osm-sha256', $OsmSha256) }
if ($SourceUrl) { $arguments += @('--source-url', $SourceUrl) }
if ($WaterPolygonsUrl) { $arguments += @('--water-polygons-url', $WaterPolygonsUrl) }
if ($Force) { $arguments += '--force' }
if ($BoundsOnly) { $arguments += '--bounds-only' }
& $Python @arguments
if ($LASTEXITCODE -ne 0) { throw "Pipeline tile gagal (exit $LASTEXITCODE)." }
