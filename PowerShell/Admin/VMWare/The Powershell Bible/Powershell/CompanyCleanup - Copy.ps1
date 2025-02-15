Add-PSSnapin VMWare.VIMAutomation.Core
Connect-VIServer -server 172.26.116.82 -user sa_dev_tidal -password Aec@dallas


$Company = Get-Folder -Location "Customer VMs" | where {$_.Name -notlike "ACS ITO"} | where {$_.Name -notlike "McDonalds"} | select Name

foreach ($Com in $Company) {
    $CO = $Com.Name
    $list = Get-VirtualPortGroup |  where {$_.Name -like "*$CO*"} | select Name
    $List
    $file = "F:\DEV Cleanup_$CO.CSV"
    echo "Company,VMName,VMPath,DataStore,PortGroup,AvailablePorts" > $file
    
    foreach ($pg in $list) {
         $Ports = Get-View -VIObject $pg.Name | Select PortKeys
          $PortsNum = $Ports.PortKeys | Measure-object
          $Used = Get-View -VIObject $pg.Name | Select VM 
          $UsedNum = $Used.VM | Measure-Object
         $AVG = $PortsNum.count-$UsedNum.count

         foreach ($Guest in $Used.vm) {
               $VM = Get-VM -ID $Guest | Select Name,Folder
               $VMView = Get-View -VIObject $VM.Name
              $VMDAtastore = Get-Datastore -ID $VMView.Datastore | select name
              $VMFolder = $VM.Folder

              If ($vmfolder.Name -eq "Templates") {
                     $folder = Get-Folder -name $vmfolder.Name | select Name,Parent | Where {$_.Parent -like $CO.Name}
                      $CO + $VM.Name + "," + "daldev/Customer VMs/" + $folder.Parent + "/" + $folder.Name + "," + $VMDatastore.Name + "," + $pg.name + "," + "$AVG" >> $file
                      }

             Else {
                   $CO + $VM.Name + "," + "daldev/Customer VMs/" + "$CO" + "," + $VMDatastore.Name + "," + $pg.name + "," + "$AVG" >> $file
                  }
             }
    }
    }