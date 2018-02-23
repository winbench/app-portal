param (
    $TargetUrl = $null,
    $User = $null,
    $Password = $null,
    $LocalDatabaseFile = "bench-apps-db.json"
)
$Script:thisDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# Allow HTTPS connections via TLS 1.1 or TLS 1.2
$AllProtocols = [System.Net.SecurityProtocolType]'Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

$databaseFile = $LocalDatabaseFile
if (![IO.Path]::IsPathRooted($LocalDatabaseFile))
{
    $databaseFile = [IO.Path]::Combine((Get-Location), $LocalDatabaseFile)
}

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
    Remove-Item $workDir -Recurse
}
mkdir $workDir | Out-Null
Push-Location $workDir

# Discover latest Bench release
$apiUrl = "https://api.github.com/repos/winbench/bench/releases/latest"
$data = Invoke-WebRequest $apiUrl -UseBasicParsing | ConvertFrom-Json
if (!$data.assets)
{
    Write-Error "Downloading the latest release info failed."
    Pop-Location
    exit 1
}

$release = $data.name
Write-Output "Latest release: $release"

# Check cache
[string]$cachedRelease = Get-Content "$downloadDir\version.txt" -ErrorAction SilentlyContinue
if ($release -ne $cachedRelease)
{
    Write-Output "Downloading Bench release $release"
    $archiveUrl = $data.assets `
        | ? { $_.name -eq "Bench.zip" } `
        | % { $_.browser_download_url }
    if (!$archiveUrl)
    {
        Write-Error "Failed to retrieve URL of Bench.zip"
        Pop-Location
        exit 1
    }

    # Download Bench.zip
    Invoke-WebRequest $archiveUrl -UseBasicParsing -OutFile "$downloadDir\Bench.zip"

    # Save downloaded release version
    $release | Set-Content "$downloadDir\version.txt"
}
else
{
    Write-Output "Using Bench $release from cache"
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
    Pop-Location
    exit 1
}

# Initialize Bench environment for app library download
mkdir "$workDir\config" | Out-Null
Copy-Item "$workDir\res\config.template.md" "$workDir\config\config.md"
"" | Out-File "$workDir\config\apps-activated.txt" -Encoding Default
"" | Out-File "$workDir\config\apps-deactivated.txt" -Encoding Default

# Put Bench CLI on Path
$env:PATH = "$workDir\auto\bin;$env:PATH"

# Download and extract app libraries
bench --verbose manage load-app-libs
if (!$?)
{
    Write-Error "Downloading the app libraries failed."
    Pop-Location
    exit 1
}

# Create new database file
if (Test-Path $databaseFile) { Remove-Item $databaseFile }
Push-Location $Script:thisDir
Start-Process -Wait -NoNewWindow powershell "-NoLogo -ExecutionPolicy ByPass -File `".\New-AppLibraryDatabase.ps1`" -BenchRoot `"$workDir`" -TargetFile `"$databaseFile`""
Pop-Location
if (!(Test-Path $databaseFile))
{
    Write-Error "Creating the app database file failed."
    Pop-Location
    exit 1
}

# Upload new database file
if ($TargetUrl)
{
    $wc = New-Object System.Net.WebClient
    if ($User -and $Password)
    {
        $wc.Credentials = New-Object System.Net.NetworkCredential($User, $Password)
    }
    try
    {
        $wc.UploadFile($TargetUrl, $databaseFile) | Out-Null
    }
    catch
    {
        Write-Error "Uploading updated database failed."
        Pop-Location
        exit 1
    }
}

Pop-Location

Remove-Item $workDir -Recurse
