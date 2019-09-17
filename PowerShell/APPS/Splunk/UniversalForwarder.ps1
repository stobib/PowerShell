Clear-Host;Clear-History
Set-Variable -Name ProductName -Value "Splunk"
Set-Variable -Name AppLogPath -Value "$env:SystemDrive\SCCM-AppLog\$ProductName"
Set-Variable -Name WorkingDir -Value ("$AppLogPath\temp").ToLower()
Set-Variable -Name InstDate -Value (Get-Date -Format "yyyy-MMdd")
Set-Variable -Name AppLog -Value "$AppLogPath\Install-Script_$InstDate.log"
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : Beginning new log for installation of $AppNameList from $ProductName."
$Message|Out-File -FilePath $AppLog
Set-Variable -Name ProcessID -Value $null
Set-Variable -Name ProcessInfo -Value $null
Set-Variable -Name DnsDomain -Value ("\\$env:USERDNSDOMAIN").ToLower()
If($DnsDomain-eq"\\"){$DnsDomain="\\utshare.local"}
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : DNS Domain: $DnsDomain."
$Message|Out-File -FilePath $AppLog -Append
Set-Variable -Name AppShare -Value "departments\sysadm"
Set-Variable -Name AppPath -Value "Downloads\SplunkUniversalForwarder"
Set-Variable -Name DownloadDir -Value "$DnsDomain\$AppShare\$AppPath"
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : Download location: $DownloadDir."
$Message|Out-File -FilePath $AppLog -Append
Set-Variable -Name AppNameList -Value "splunkforwarder-7.0.0-x64.msi","splunkforwarder-7.0.3-fa31da744b51-x64-release.msi"
Set-Variable -Name InstallDir -Value "$env:SystemDrive\Program Files\$ProductName"
Set-Variable -Name DeploymentServer -Value "splunkdeploya01.inf.utshare.local:8089"
Set-Variable -Name ReceivingIndexer -Value "10.118.0.19:9998"
If((Test-Path -Path $AppLogPath)-eq$false){New-Item -Path $AppLogPath -ItemType Directory > $null}
If((Test-Path -Path $WorkingDir)-eq$false){New-Item -Path $WorkingDir -ItemType Directory > $null}
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : Verifying that $env:Computername has enough free disk space available on the C: drive for processing this installation."
$Message|Out-File -FilePath $AppLog -Append
Set-Variable -Name InstOptions -Value "INSTALLDIR=""$InstallDir"" DEPLOYMENT_SERVER=""$DeploymentServer"" RECEIVING_INDEXER=""$ReceivingIndexer"" AGREETOLICENSE=yes"
Set-Variable -Name FreeDiskSpace -Value (Get-WmiObject Win32_LogicalDisk|Where-Object{$_.DriveType-eq3}|Where-Object{$_.DeviceID-eq"C:"}|Select @{Name="GB";Expression={[math]::round($_.FreeSpace/1GB,2)}}).GB
Set-Variable -Name TotalSpace -Value (Get-WmiObject Win32_LogicalDisk|Where-Object{$_.DriveType-eq3}|Where-Object{$_.DeviceID-eq"C:"}|Select @{Name="GB";Expression={[math]::round($_.Size/1GB,2)}}).GB
Set-Variable -Name Percentage -Value ([math]::Truncate(($FreeDiskSpace/$TotalSpace)*100))
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : $env:Computername has $Percentage% free disk space available on drive C:."
$Message|Out-File -FilePath $AppLog -Append
If($Percentage-gt1){
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : Verifying registry is clear of previously uninstalled versions of $ProductName."
    $Message|Out-File -FilePath $AppLog -Append
    $KeyPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Folders"
    Set-Location $KeyPath
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : Processing registry key: [$KeyPath]."
    $Message|Out-File -FilePath $AppLog -Append
    Get-ItemProperty -Path .|Out-File $WorkingDir\ReyValues.txt
    ForEach($CurrentLine In Get-Content "$WorkingDir\ReyValues.txt"){
        If($CurrentLine-like"*Splunk*"){
            (($CurrentLine).Split(":")).Trim()|Out-File $WorkingDir\ReyValues-Trim.txt -Append
        }
    }
    If(Test-Path -Path "$WorkingDir\ReyValues-Trim.txt"){
        ForEach($CurrentLine In Get-Content "$WorkingDir\ReyValues-Trim.txt"){
            If($CurrentLine-like"*Splunk*"){
                $SubkeyValue="C:$CurrentLine"
                $DateTime=(Get-Date).ToString()
                Set-Variable -Name Message -Value "$DateTime : Deleting registry subkey value: [$SubkeyValue]."
                $Message|Out-File -FilePath $AppLog -Append
                Remove-ItemProperty -Path . -Name "$SubkeyValue"
            }
        }
    }
    If(Test-Path -Path "$WorkingDir\ReyValues-Trim.txt"){Remove-Item "$WorkingDir\ReyValues-Trim.txt"}
    If(Test-Path -Path "$WorkingDir\ReyValues.txt"){Remove-Item "$WorkingDir\ReyValues.txt"}
    Set-Location -Path "$WorkingDir"
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : Continuing with the installation script because there is enough free disk space available."
    $Message|Out-File -FilePath $AppLog -Append
    $WorkingDir="$WorkingDir\$ProductName"
    If((Test-Path -Path $WorkingDir)-eq$false){New-Item -Path $WorkingDir -ItemType Directory > $null}
    Set-Location -Path "$WorkingDir"
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : Installing $AppName in directory [$InstallDir]."
    $Message|Out-File -FilePath $AppLog -Append
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : The deployment server for this installation is [$DeploymentServer]."
    $Message|Out-File -FilePath $AppLog -Append
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : The receiving indexer for this installation is [$ReceivingIndexer]."
    $Message|Out-File -FilePath $AppLog -Append
    ForEach($AppName In $AppNameList){
        Copy-Item -Path "$DownloadDir\$AppName" -Destination $WorkingDir
        If(Test-Path -Path "$WorkingDir\$AppName"){
            $DateTime=(Get-Date).ToString()
            Set-Variable -Name Message -Value "$DateTime : Installation process using MSIEXEC for $AppName is beginning."
            $Message|Out-File -FilePath $AppLog -Append
            If(Test-Path -Path ("$WorkingDir\$ProductName.log").ToLower()){
                Remove-Item -Path ("$WorkingDir\$ProductName.log").ToLower()
            }
            Start-Process "msiexec.exe" "/i $AppName INSTALLDIR=""$InstallDir"" DEPLOYMENT_SERVER=""$DeploymentServer"" RECEIVING_INDEXER=""$ReceivingIndexer"" AGREETOLICENSE=yes /quiet" -Wait
            If(Test-Path -Path ("$env:temp\$ProductName.log").ToLower()){
                ForEach-Object{Get-Content ("$env:temp\$ProductName.log").ToLower()|Out-File -FilePath $AppLog -Append}
            }
            $DateTime=(Get-Date).ToString()
            Set-Variable -Name Message -Value "$DateTime : Installation process using MSIEXEC for $AppName has completed."
            $Message|Out-File -FilePath $AppLog -Append
        }Else{
            $DateTime=(Get-Date).ToString()
            Set-Variable -Name Message -Value "$DateTime : Failed to copy [$DownloadDir\$AppName] to $WorkingDir."
            $Message|Out-File -FilePath $AppLog -Append
        }
        Start-Sleep -Milliseconds 500
        $DateTime=(Get-Date).ToString()
        Set-Variable -Name Message -Value "$DateTime : Continuing script after pausing for 500 ms."
        $Message|Out-File -FilePath $AppLog -Append
    }
}
Set-Location -Path "$env:windir\System32"
$DateTime=(Get-Date).ToString()
Set-Variable -Name Message -Value "$DateTime : Completed processing installation script."
$Message|Out-File -FilePath $AppLog -Append
If(Test-Path -Path $WorkingDir){
    Start-Sleep -Milliseconds 500
    Remove-Item -Path $WorkingDir -Recurse -Force
    $DateTime=(Get-Date).ToString()
    Set-Variable -Name Message -Value "$DateTime : Removed working directory: [$WorkingDir] to cleanup unneeded files."
    $Message|Out-File -FilePath $AppLog -Append
}
$AppShare=$null
$AppPath=$null
$DownloadDir=$null
$AppNameList=$null
$WorkingDir=$null
$ProductName=$null
$AppLogPath=$null
$AppLog=$null
$InstallDir=$null
$InstOptions=$null
$DeploymentServer=$null
$ReceivingIndexer=$null
$FreeDiskSpace=$null
$TotalSpace=$null
$Percentage=$null
$ProcessID=$null
$ProcessInfo=$null