param (
    $LibraryList = "app-libraries.txt",
    $FtpHost = $null,
    $FtpUser = $null,
    $FtpPassword = $null,
    $FtpPath = $null
)

$Script:thisDir = Split-Path $MyInvocation.MyCommand.Path -Parent

echo $thisDir
echo "OK"
