$MBXServers = get-mailboxserver | select name
$CASServers = get-clientAccessServer | select name
$SrvrList = $MBXServers + $CASServers

foreach ($I in $SrvrList) {
    $Server = $I.Name
    $ServerDisks = Get-WmiObject -ComputerName $Server win32_volume | select name,freespace,capacity
    foreach ($D in $ServerDisks) {
        $Disk = $D.Name
        $Cap = $D.Capacity
        $Free = $D.FreeSpace
        $dif = $Cap-$Free
        if ($dif -ge "1"){
            $per = $dif/$Cap*100
            $per =  "{0:N2}" -f $per
            if ($per -ge "75") {
                $mesage = $Server + "partition :" + $Disk + "is running low on disk space. - " + $per + "% used."
                $emailFrom = "EX-Disk-chk@alamo.edu" 
                $emailTo = "evs0@alamo.edu" 
                $subject = "Drive Space usage above 75%" 
                $body = "$mesage" 
                $smtpServer = "mail.alamo.edu" 
                $smtp = new-object Net.Mail.SmtpClient($smtpServer) 
                $smtp.Send($emailFrom, $emailTo, $subject, $body) 
                }
            }
        }
    }