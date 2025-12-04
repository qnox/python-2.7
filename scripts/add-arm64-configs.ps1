# PowerShell script to add ARM64 platform configurations to Python 2.7 Visual Studio projects
# This enables building Python 2.7 for Windows ARM64

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDir
)

$ErrorActionPreference = "Stop"

Write-Host "Adding ARM64 platform configurations to Visual Studio projects..."
Write-Host "Source directory: $SourceDir"

$pcbuildDir = Join-Path $SourceDir "PCbuild"
$projectFiles = Get-ChildItem -Path $pcbuildDir -Filter "*.vcxproj" -File

$configurationsToAdd = @("Debug", "Release", "PGInstrument", "PGUpdate")
$addedCount = 0
$skippedCount = 0

foreach ($projectFile in $projectFiles) {
    Write-Host "`nProcessing: $($projectFile.Name)"

    $content = Get-Content -Path $projectFile.FullName -Raw

    # Check if ARM64 already exists
    if ($content -match "Platform>ARM64<") {
        Write-Host "  ARM64 already exists, skipping"
        $skippedCount++
        continue
    }

    # Find the ItemGroup with ProjectConfiguration entries
    $pattern = '(<ItemGroup Label="ProjectConfigurations">)([\s\S]*?)(</ItemGroup>)'

    if ($content -match $pattern) {
        $beforeItemGroup = $Matches[1]
        $existingConfigs = $Matches[2]
        $afterItemGroup = $Matches[3]

        # Generate ARM64 configurations based on x64 configurations
        $arm64Configs = ""
        foreach ($config in $configurationsToAdd) {
            $arm64Configs += @"

    <ProjectConfiguration Include="$config|ARM64">
      <Configuration>$config</Configuration>
      <Platform>ARM64</Platform>
    </ProjectConfiguration>
"@
        }

        # Replace the ItemGroup with the new one including ARM64
        $newItemGroup = $beforeItemGroup + $existingConfigs + $arm64Configs + "`r`n  " + $afterItemGroup
        $newContent = $content -replace $pattern, $newItemGroup

        # Write back to file
        [System.IO.File]::WriteAllText($projectFile.FullName, $newContent, [System.Text.Encoding]::UTF8)

        Write-Host "  Added ARM64 configurations: $($configurationsToAdd -join ', ')"
        $addedCount++
    }
    else {
        Write-Host "  WARNING: Could not find ProjectConfigurations ItemGroup"
    }
}

Write-Host "`n=========================================="
Write-Host "Summary:"
Write-Host "  Projects modified: $addedCount"
Write-Host "  Projects skipped: $skippedCount"
Write-Host "=========================================="
Write-Host "ARM64 configurations added successfully!"
