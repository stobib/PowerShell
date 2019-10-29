function Get-HostToIP($hostname) {     
    $result = [system.Net.Dns]::GetHostByName($hostname)     
    $result.AddressList | ForEach-Object {$_.IPAddressToString } 
} 
 
Get-Content "C:\pwscriptinputs\dianesdenyhosts10242016.txt" | ForEach-Object {(Get-HostToIP($_)) >> c:\pw\Addresses.txt}