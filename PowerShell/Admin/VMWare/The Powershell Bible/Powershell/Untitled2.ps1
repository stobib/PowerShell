Add-PSSnapin VMWare.VIMAutomation.Core
Connect-VIServer -server 172.26.116.82 -user sa_dev_tidal -password Aec@dallas

$blank = ""
$file = "f:\Test.CSV"
$blank > $file
$Company = Get-Folder -Location "Customer VMs" | where {$_.Name -notlike "ACS ITO"} |  where {$_.Name -notlike "McDonalds"} |  where {$_.Name -notlike "Templates"}
foreach ($C in $Company) {
    $CO = $c.Name
    $VMObjects = Get-VM -Location $CO | select Folder,Name
    foreach ($V in $VMObjects) {
        $VMFolder = $V.Folder 
        $VMName = $V.Name
        If ($VMFolder -like "Templates")  {
            
            $folder = Get-Folder -Name $VMFolder -location "Customer VMs" | select Name,Parent | Where {$_.Parent -like $CO}
            $VMParent = $folder.Parent
            "$VMParent" + "/" + "$VMFolder" + "," + "$VMName" >> $file
        }
        Else {
            "$VMFolder" + "," + "$VMName" >> $file
        }
    }
}
