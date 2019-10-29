

function add-host([string]$filename)
{  
   $addip = "10.10.10.100"
   $addhostnames = "casarray.domain.local"
   foreach ($addhostname in $addhostnames)
       {
       $HostEntries = Get-Content $filename
       $Count = 0
       foreach ($line in $HostEntries)
           {
           $bits = [regex]::Split($line, "\t+")
           if ($bits.count -eq 2)
               {
               if ($bits[1] -eq $addhostname) {$Count+=1}                
               }
           }
       if($Count -eq 0)
           {
           Write-Host "Adding Host Entry" $addip "`t`t" $addhostname
           $addip + "`t`t" + $addhostname | Out-File -encoding ASCII -append $filename
           }
       else
           {
           Write-Host "Host Entries already exists"
           }
   }
}
function add-list([string]$ComputerList,[string]$ComputerName)
{
$ComputerNames = Get-Content $ComputerList
$count = 0
foreach($computer in $ComputerNames)
   {
   if ($computer -eq $ComputerName){$count+=1}
   }
if($count -eq 0)
   {
   $ComputerName | Add-Content $ComputerList
   Write-Host "Computer Name," $ComputerName "added in the list"
   }
   cmd /c pause
}
$date = Get-Date -Format "dd_MM_yyyy_hh_mm"
$computers = Get-Content "c:\Script\ComputerList.txt"
$ModifiedComputerNames = "C:\Script\ModifiedComputerNames.txt"
foreach ($computer in $computers)
{
$file = “\\”+ $computer + "\C$\Windows\System32\drivers\etc\hosts"
$fileCopy = “\\”+ $computer + "\C$\Windows\System32\drivers\etc\hosts.bak." + $date
cpi $file $fileCopy
add-host $file
add-list $ModifiedComputerNames $computer
}
You need to enter the list of computers for which the hosts file needs to be edited in the file c:\Script\ComputerList.txt. You may use a different path and file name, but remember to amend the script accordingly.

Script for Removing Entries to Hosts file

Following script will help you remove the temporarily added hosts entries for list of computers.
function remove-host([string]$filename )
{
$rmhostnames = "casarray.domain.local"
foreach ($rmhostname in $rmhostnames)
{
$c = Get-Content $filename
$newLines = @()
foreach ($line in $c)
{
$bits = [regex]::Split($line, "\t+")
if ($bits.count -eq 2)
   {
   if ($bits[1] -ne $rmhostname)
       {
       $newLines += $line
       }
   }
else
   {
   $newLines += $line
   }
}
# Write file
Clear-Content $filename
foreach ($line in $newLines)
   {
   $line | Out-File -encoding ASCII -append $filename
   Start-Sleep -m 100
   }
}
}
$computers = Get-Content "C:\Script\ModifiedComputerNames.txt"
foreach ($computer in $computers)
{
Write-Host $computer
$file = “\\”+ $computer + "\C$\Windows\System32\drivers\etc\hosts"
remove-host $file
}