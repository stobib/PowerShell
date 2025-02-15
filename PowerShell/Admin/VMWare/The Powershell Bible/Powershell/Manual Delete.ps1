#Add-PSSnapin VMWare.VIMAutomation.Core
#Connect-VIServer -server 172.26.116.82 -user sa_dev_tidal -password Aec@dallas

$date = Get-Date | select date,hour
$day = $date | select date
$hour = $date | select Hour


$events =  Get-VIEvent -maxsamples 10000 | where {$_.Gettype().Name -eq "VmRemovedEvent"} | Sort CreatedTime -Descending | Select CreatedTime, UserName, FullformattedMessage 
$deletedVM = @()
foreach ($e in $events) {
    $CD = $e.CreatedTime | select hour
    if ($CD -like $hour) {
        $e.FullFormattedMessage
        }
    }