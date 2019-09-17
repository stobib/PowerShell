Clear-Host
Set-Variable -Name ProcessList -Value "LPD Service","Print Spooler","Troy Port Monitor Service"
ForEach($Proces In $ProcessList){
    If($Proces -eq "svchost"){
        Set-Variable -Name Found -Value $false
        Set-Variable -Name ServiceName -Value "LPD Service"
        Set-Variable -Name OutputFile -Value "$env:TEMP\Output.txt"
        Set-Variable -Name RunningSvcs -Value "/SVC /FI ""imagename eq svchost.exe"""
        Start-Process tasklist -ArgumentList $RunningSvcs -RedirectStandardOutput $OutputFile -WindowStyle Hidden
        ForEach($line In Get-Content $OutputFile){
            If($line -match $ServiceName){
                $Found=$true;Break
            }
        }
        If($Found-eq$false){
            Echo "'$ServiceName' is not running."
            Start-Process $ServiceName -ErrorAction SilentlyContinue
        }
        If(Test-Path -Path $OutputFile){
            sleep -Milliseconds 350
            Remove-Item -Path $OutputFile -Force
        }
        $Found=$null
        $ServiceName=$null
        $OutputFile=$null
        $RunningSvcs=$null
    }
    If((Get-Process -Name "$Proces" -ErrorAction SilentlyContinue) -eq $null){
        Echo "'$Proces' is not running."
        Start-Process $Proces -ErrorAction SilentlyContinue
    }
}
$ProcessList=$null