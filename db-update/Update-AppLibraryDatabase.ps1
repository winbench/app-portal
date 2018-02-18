param (
    $LibraryList = "app-libraries.txt",
    $FtpHost = $null,
    $FtpUser = $null,
    $FtpPassword = $null,
    $FtpPath = $null
)
$Script:thisDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# Prepare download directory
$downloadDir = "$Script:thisDir\downloads"
if (!(Test-Path $downloadDir))
{
    mkdir $downloadDir | Out-Null
}

# Prepare working directory
$workDir = "$Script:thisDir\tmp"
if (Test-Path $workDir)
{
    del $workDir -Recurse
}
mkdir $workDir | Out-Null
cd $workDir

$databaseFile = "$workDir\bench-apps-db.json"

# Discover latest Bench release
$apiUrl = "https://api.github.com/repos/winbench/bench/releases/latest"
$data = Invoke-WebRequest $apiUrl -UseBasicParsing | ConvertFrom-Json
if (!$data.assets)
{
    Write-Error "Downloading the latest release info failed."
    exit 1
}

$release = $data.name
echo "Latest release: $release"

# Check cache
[string]$cachedRelease = Get-Content "$downloadDir\version.txt" -ErrorAction SilentlyContinue
if ($release -ne $cachedRelease)
{
    echo "Downloading Bench release $release"
    $archiveUrl = $data.assets `
        | ? { $_.name -eq "Bench.zip" } `
        | % { $_.browser_download_url }
    if (!$archiveUrl)
    {
        Write-Error "Failed to retrieve URL of Bench.zip"
        exit 1
    }

    # Download Bench.zip
    Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile "$downloadDir\Bench.zip"

    # Save downloaded release version
    $release | Set-Content "$downloadDir\version.txt"
}
else
{
    echo "Using Bench $release from cache"
}

# Extract Bench.zip
try
{
    $ws = New-Object -ComObject Shell.Application
    $zip = $ws.NameSpace("$downloadDir\Bench.zip")
    $trg = $ws.NameSpace("$workDir")
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
mkdir "$workDir\config" | Out-Null
copy "$workDir\res\config.template.md" "$workDir\config\config.md"
"" | Out-File "$workDir\config\apps-activated.txt" -Encoding Default
"" | Out-File "$workDir\config\apps-deactivated.txt" -Encoding Default

# Put Bench CLI on Path
$env:PATH = "$workDir\auto\bin;$env:PATH"

# Download and extract app libraries
bench --verbose manage load-app-libs
if (!$?)
{
    Write-Error "Downloading the app libraries failed."
    exit 1
}

# Load Bench PowerShell API
. "$workDir\auto\lib\bench.lib.ps1"

# Load Bench configuration
$cfg = New-Object Mastersign.Bench.BenchConfiguration ($workDir, $true, $true, $false)

# Write new database as JSON
echo "Writing database file"
function AppInfo ()
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
            "AppLibrary" = $_.AppLibrary.ID
            "AppLibraryUrl" = $_.AppLibrary.Url
            "Namespace" = $_.Namespace
            "Label" = $_.Label
            "Category" = $_.Category
            "Typ" = $_.Typ
            "IsManagedPackage" = $_.IsManagedPackage
            "PackageName" = $_.PackageName
            "Version" = $_.Version
            "Website" = $_.Website
            "Docs" = $_.Docs
            "License" = $_.License
            "LicenseUrl" = $_.LicenseUrl
            "Dependencies" = $_.Dependencies
            "Responsibilities" = $_.Responsibilities
            "Url" = $_.Url
            "Only64Bit" = $_.Only64Bit
            "Register" = $_.Register
            "Environment" = $_.Environment
            "RegistryKeys" = $_.RegistryKeys
            "IsAdornmentRequired" = $_.IsAdornmentRequired
            "Launcher" = $_.Launcher
            "MarkdownDocumentation" = $_.MarkdownDocumentation
        }
    }
}
$utf8 = New-Object System.Text.UTF8Encoding ($false)
$jsonText = $cfg.Apps | AppInfo | ConvertTo-Json -Compress
[IO.File]::WriteAllText($databaseFile, $jsonText, $utf8)
