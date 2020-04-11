Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$SrvName=Get-Service|Where-Object{$_.Name-eq"RemoteRegistry"}
$RegistryPath="HKLM:\SYSTEM\CurrentControlSet\Services\RemoteRegistry"
$UserName="NT AUTHORITY\LocalService"
If(!($SrvName.Status-eq"Stopped")){
    Write-Host ("Attempting to stop service: "+$SrvName.Name)
    $StopStatus=Stop-Service -Name $SrvName.Name
}Else{
    Write-Host ("The service '"+$SrvName.DisplayName+"' is currently: "+$SrvName.Status)
}
Do{
    $UserAccount=(Get-ItemProperty -Path $RegistryPath).ObjectName
    If(!($UserAccount-eq$UserName)){
        Write-Host ("'"+$SrvName.DisplayName+"' is currently using the user: ["+$UserAccount+"]")
        Set-ItemProperty -Path $RegistryPath -Name ObjectName -Value $UserName
        Write-Host ("Attempting to change ObjectName to: ["+$UserName+"]")
    }Else{
        Write-Host ("The service '"+$SrvName.DisplayName+"' is set to use: ["+$UserAccount+"]")
    }
}Until($UserAccount-eq$UserName)
Try{
    $StartStatus=Start-Service -DisplayName $SrvName.DisplayName -ErrorAction Ignore
}Catch{
    Write-Host ("Attempt to start service '"+$SrvName.DisplayName+"' failed.")
}
$SrvName=Get-Service|Where-Object{$_.Name-eq"RemoteRegistry"}
Write-Host ("The service '"+$SrvName.DisplayName+"' is currently: "+$SrvName.Status)
If(!($SrvName.Status-eq"Running")){
    Write-Host ("Attempt to start service '"+$SrvName.DisplayName+"' failed.")
}