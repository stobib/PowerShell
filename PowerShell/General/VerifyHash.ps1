# Path of Microsoft.PowerShell.Utility.psd1
$file = (Get-Module Microsoft.PowerShell.Utility).Path

$hashFromFile = Get-FileHash -Path $file -Algorithm MD5

# Open $file as a stream
$stream = [System.IO.File]::OpenRead($file)
$hashFromStream = Get-FileHash -InputStream $stream -Algorithm MD5
$stream.Close()

Write-Host '### Hash from File ###' -NoNewline
$hashFromFile | Format-List
Write-Host '### Hash from Stream ###' -NoNewline
$hashFromStream | Format-List

# Check both hashes are the same
if ($hashFromFile.Hash -eq $hashFromStream.Hash) {
	Write-Host 'Get-FileHash results are consistent' -ForegroundColor Green
} else {
	Write-Host 'Get-FileHash results are inconsistent!!' -ForegroundColor Red
}
<#
### Hash from File ###

Algorithm : MD5
Hash      : 593D6592BD9B7F9174711AB136F5E751
Path      : C:\Program Files\PowerShell\6.0.0\Modules\Microsoft.Powe
            rShell.Utility\Microsoft.PowerShell.Utility.psd1

### Hash from Stream ###

Algorithm : MD5
Hash      : 593D6592BD9B7F9174711AB136F5E751
Path      :

Get-FileHash results are consistent #>