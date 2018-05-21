param (
    $BenchRoot = $(Get-Location),
    $TargetFile = "$(Get-Location)\bench-apps.json"
)

# Load Bench PowerShell API
. "$BenchRoot\auto\lib\bench.lib.ps1"

# Load Bench configuration
$cfg = New-Object Mastersign.Bench.BenchConfiguration ($BenchRoot, $true, $true, $false)

# Write new database as JSON
function AppLibUrl ($appLib)
{
    [string]$url = $appLib.Url;
    if ($url.StartsWith("https://github.com/") -and $url.EndsWith("/archive/master.zip"))
    {
        $url = $url.Substring(0, $url.Length - 18)
    }
    return $url
}
function AppLibInfo ()
{
    begin
    {
        $no = 0
    }
    process
    {
        $no++
        @{
            "Index" = $no
            "ID" = $_.ID
            "Url" = $(AppLibUrl $_)
        }
    }
}
function ToHashtable ($dict) {
    return New-Object System.Collections.Hashtable ($dict)
}
function AppCustomization ($app) {
    $names = @("extract", "setup", "env", "pre-run", "post-run", "test", "remove")
    return [string[]]($names | ? { $app.GetCustomScript($_) })
}
function AppInfo ()
{
    begin
    {
        $no = 0
    }
    process
    {
        $no++
        $info = @{
            "Index" = $no
            "ID" = $_.ID
            "AppLibrary" = $_.AppLibrary.ID
            "Namespace" = $_.Namespace
            "Label" = $_.Label
            "Category" = $_.Category
            "Typ" = $_.Typ
            "IsManagedPackage" = $_.IsManagedPackage
            "PackageName" = $_.PackageName
            "Version" = $(if ($_.IsVersioned) {$_.Version} else {$null})
            "Website" = $_.Website
            "License" = $_.License
            "LicenseUrl" = $_.LicenseUrl
            "Dependencies" = $_.Dependencies
            "Responsibilities" = $_.Responsibilities
            "Url32Bit" = $_.Url32Bit
            "Url64Bit" = $_.Url64Bit
            "Only64Bit" = $_.Only64Bit
            "Register" = $_.Register
            "RegistryKeys" = $_.RegistryKeys
            "IsAdornmentRequired" = $_.IsAdornmentRequired
            "Launcher" = $_.Launcher
            "MarkdownDocumentation" = $_.MarkdownDocumentation
        }
        $info.Docs = [Collections.Hashtable]::new($_.Docs)
        $info.Environment = $_.Environment.Keys
        $info.Customization = @()
        foreach ($n in @("extract", "setup", "env", "pre-run", "post-run", "test", "remove"))
        {
            if ($_.GetCustomScript($n)) { $info.Customization += $n }
        }
        return $info
    }
}
$db = @{
    "LastUpdate" = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    "AppLibraries" = $($cfg.AppLibraries | AppLibInfo)
    "Apps" = $($cfg.Apps | AppInfo)
}

$utf8 = New-Object System.Text.UTF8Encoding ($false)
$jsonText = $db | ConvertTo-Json -Depth 3 -Compress

Write-Output "Writing new app database to $TargetFile ..."
[IO.File]::WriteAllText($TargetFile, $jsonText, $utf8)
