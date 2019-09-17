Clear-Host;Clear-History
Set-Variable -Name LoopTimer -Value 500
Set-Variable -Name LoopCounter -Value 0
Set-Variable -Name ComputerName -Value ($env:COMPUTERNAME).ToLower()
Set-Variable -Name SmbShare -Value "\\utshare.local\departments\sysadm\PrintServer\Logs\$ComputerName"
If((Test-Path $SmbShare)-eq$false){
    New-Item -ItemType Directory -Force -Path $SmbShare > $null
}
Do{
    Set-Variable -Name Counter -Value 1
    Set-Variable -Name Aging -Value "-90"
    Set-Variable -Name WriteLog -Value $false
    Set-Variable -Name Extensions -Value "bak","prn","txt"
    Set-Variable -Name StartTime -Value (Get-Date).AddMinutes(-5)
    Set-Variable -Name FileName -Value (Get-Date -UFormat "%Y-%m%d_%H%M")
    Set-Variable -Name LogFile -Value "$SmbShare\PrintService_$FileName.log"
    Set-Variable -Name ProcessList -Value "svchost","spoolsv","TroyPortMonitorService"
    Set-Variable -Name FreeDiskSpace -Value (Get-WmiObject Win32_LogicalDisk|Where-Object{$_.DriveType-eq3}|Where-Object{$_.DeviceID-eq"E:"}|Select @{Name="GB";Expression={[math]::round($_.FreeSpace/1GB,2)}}).GB
    Set-Variable -Name TotalSpace -Value (Get-WmiObject Win32_LogicalDisk|Where-Object{$_.DriveType-eq3}|Where-Object{$_.DeviceID-eq"E:"}|Select @{Name="GB";Expression={[math]::round($_.Size/1GB,2)}}).GB
    Set-Variable -Name Percentage -Value ([math]::Truncate(($FreeDiskSpace/$TotalSpace)*100))
    Date;"Freespace on 'Disk [E:]' $Percentage%";
    If(($Percentage-gt30)-and($Percentage-lt40)){
        $Aging="-60"
    }ElseIf(($Percentage-gt20)-and($Percentage-lt30)){
        $Aging="-45"
    }ElseIf(($Percentage-gt10)-and($Percentage-lt20)){
        $Aging="-30"
    }
    Do{
        ForEach($Ext In $Extensions){
            If($Ext-ne"txt"){
                $SubFolder="$Counter\Backup\"
            }Else{
                $SubFolder="$Counter\"
            }
            Set-Variable -Name FilePattern -Value "E:\TROY Group\Port Monitor\PrintPort$SubFolder*.$Ext"
            Get-ChildItem -Path "$FilePattern" -Recurse -Force -ErrorAction SilentlyContinue|
            Where-Object{($_.CreationTime-le$(Get-Date).AddDays($Aging))}|
            Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue
        }
        $Counter++
        $Ext=$null
        $SubFolder=$null
        $FilePattern=$null
    }Until($Counter-gt20)
    ForEach($Proces In $ProcessList){
        If($Proces -eq "svchost"){
            Set-Variable -Name Found -Value $false
            Set-Variable -Name ServiceName -Value "LPDSVC"
            Set-Variable -Name OutputFile -Value "$env:TEMP\Output.txt"
            Set-Variable -Name RunningSvcs -Value "/SVC /FI ""imagename eq svchost.exe"""
            Start-Process tasklist -ArgumentList $RunningSvcs -RedirectStandardOutput $OutputFile -WindowStyle Hidden
            ForEach($line In Get-Content $OutputFile){
                If($line -match $ServiceName){
                    $Found=$true;Break
                }
            }
            If(Test-Path -Path $OutputFile){
                Start-Sleep -Milliseconds $LoopTimer
                Remove-Item -Path $OutputFile -Force
            }
            If($Found-eq$false){
                Set-Variable -Name ServiceName -Value "LPD Service"
                Start-Process cmd -ArgumentList "/c net start |find ""$ServiceName""" -RedirectStandardOutput $OutputFile -WindowStyle Hidden
                ForEach($line In Get-Content $OutputFile){
                    If($line -match $ServiceName){
                        Break
                    }
                    Echo "Attempting to start '$ServiceName'."
                    Start-Process svchost -ArgumentList "-k LPDService" -ErrorAction SilentlyContinue
                    $WriteLog=$true
               }
                If(Test-Path -Path $OutputFile){
                    Start-Sleep -Milliseconds $LoopTimer
                    Remove-Item -Path $OutputFile -Force
                }
            }
            $Found=$null
            $ServiceName=$null
            $OutputFile=$null
            $RunningSvcs=$null
        }ElseIf((Get-Process -Name "$Proces" -ErrorAction SilentlyContinue) -eq $null){
            Echo "Attempting to start '$Proces'."
            Start-Process $Proces -ErrorAction SilentlyContinue
            $WriteLog=$true
        }
    }
    If($WriteLog-eq$true){
        Set-Variable -Name CurrentLog -Value (Get-WinEvent -LogName Microsoft-Windows-PrintService/*|Where-Object{$_.TimeCreated-ge$Starttime}|Out-File -FilePath $LogFile)
    }
    $Aging=$null
    $Proces=$null
    $LoopCounter++
    $Counter=$null
    $LogFile=$null
    $FileName=$null
    $Starttime=$null
    $CurrentLog=$null
    $TotalSpace=$null
    $Percentage=$null
    $Extensions=$null
    $FreeDiskSpace=$null
    $Pause=$LoopTimer*598
    Start-Sleep -Milliseconds $Pause
}Until($LoopCounter-ge12)
$ComputerName=$null
$ProcessList=$null
$LoopCounter=$null
$LoopTimer=$null
$SmbShare=$null
$WriteLog=$null
$Pause=$null