param (
    $LibraryList = "app-libraries.txt",
    $FtpHost = $null,
    $FtpUser = $null,
    $FtpPassword = $null,
    $FtpPath = $null
)
$Script:thisDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# Prepare working directory
$workDir = "$Script:thisDir\tmp"
if (Test-Path $workDir)
{
    del $workDir -Recurse
}
mkdir $workDir | Out-Null
cd $workDir

# Discover latest Bench release
$apiUrl = "https://api.github.com/repos/winbench/bench/releases/latest"
$data = Invoke-WebRequest $apiUrl -UseBasicParsing | ConvertFrom-Json
if (!$data.assets)
{
    Write-Error "Downloading the latest release info failed."
    exit 1
}
$archiveUrl = $data.assets `
    | ? { $_.name -eq "Bench.zip" } `
    | % { $_.browser_download_url }
if (!$archiveUrl)
{
    Write-Error "Failed to retrieve URL of Bench.zip"
    exit 1
}

# Download Bench.zip
Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile "$workDir\Bench.zip"
[string]$benchDir = mkdir .\bench

# Extract Bench.zip
try
{
    $ws = New-Object -ComObject Shell.Application
    $zip = $ws.NameSpace("$workDir\Bench.zip")
    $trg = $ws.NameSpace("$workDir\bench")
    foreach ($item in $zip.items())
    {
        $trg.copyhere($item, 0x14)
    }
}
catch
{
    Write-Warning $_.Exception.InnerException.Message
    Write-Error "Extracting Bench.zip failed."
    exit 1
}

# Initialize Bench environment for app library download
mkdir "$benchDir\config" | Out-Null
copy "$benchDir\res\config.template.md" "$benchDir\config\config.md"
"" | Out-File "$benchDir\config\apps-activated.txt" -Encoding Default
"" | Out-File "$benchDir\config\apps-deactivated.txt" -Encoding Default

# Put Bench CLI on Path
$env:PATH = "$benchDir\auto\bin;$env:PATH"

# Download and extract app libraries
bench --verbose manage load-app-libs
if (!$?)
{
    Write-Error "Downloading the app libraries failed."
    exit 1
}

# Load Bench PowerShell API
. "$benchDir\auto\lib\bench.lib.ps1"

# Load Bench configuration
$cfg = New-Object Mastersign.Bench.BenchConfiguration ($benchDir, $true, $true, $false)

# Enumerate all apps
$no = 0
foreach ($app in $cfg.Apps)
{
    $no++
    if (!$app.AppLibrary) { continue }
    Write-Host "$($no.ToString("0000")) $($app.ID)"
}
