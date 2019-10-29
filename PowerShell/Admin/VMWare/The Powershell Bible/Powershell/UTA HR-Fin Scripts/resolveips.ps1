#resolve ip addresses

function Get-HostToIP($hostname) {  
    $result = [system.Net.Dns]::GetHostByName($hostname)     
    $result.AddressList | ForEach-Object {$_.IPAddressToString } 
} 
 
$date = get-date -format yyyy_MM_dd-HH-mm-ss 
Get-Content "C:\pwscriptinputs\dianesdenyhosts10242016.txt" | ForEach-Object {(Get-HostToIP($_)) >> C:\pwscriptoutputs\resolveip\resolvedips-$date.txt}