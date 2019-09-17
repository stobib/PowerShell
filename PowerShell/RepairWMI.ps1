Clear-History;Clear-Host
Set-Variable -Name WMI_Path -Value "$env:SystemRoot\System32\wbem\repository"
Set-Variable -Name WMI_Path_Old -Value $WMI_Path-old
Set-Variable -Name SCCM_ARDC_Server -Value w16asccmdb01.inf.utshare.local
Set-Variable -Name SCCM_UDCC_Server -Value w16bsccmdb01.inf.utshare.local
Set-Variable -Name SCCM_ARDC_Share -Value SMS_DFW
Set-Variable -Name SCCM_UDCC_Share -Value SMS_AUS
Set-Variable -Name SCCM_Client -Value Client\ccmsetup.exe
Set-Variable -Name IP_Address -Value $null
Set-Variable -Name Octet_1 -Value $null
Set-Variable -Name Octet_2 -Value $null
Set-Variable -Name Octet_3 -Value $null
Set-Variable -Name Octet_4 -Value $null
Set-Variable -Name Primary_Site -Value $null
Set-Variable -Name SCCM_Client_Install -Value $null
Stop-Service -Name "Winmgmt" -Force
If(Test-Path $WMI_Path_Old){Remove-Item $WMI_Path_Old -Recurse -Force}
Rename-Item -Path $WMI_Path -NewName $WMI_Path_Old
Start-Service -Name "Winmgmt"
$IP_Address=Get-NetIpAddress|Where-Object{$_.AddressFamily-eq"IPv4"}
ForEach($IPv4 In $IP_Address.IPAddress){
    $Parser=$IPv4.Split(".")
    For($O=0;$O-le3;$O++){
        Switch($O){
            0{$Octet_1=$Parser[$O];Break}
            1{$Octet_2=$Parser[$O];Break}
            2{$Octet_3=$Parser[$O];Break}
            3{$Octet_4=$Parser[$O];Break}
        }
    }
    If($Octet_1-eq10){
        If(($Octet_2-eq118)-or($Octet_2-eq119)){
            $Primary_Site="\\$SCCM_ARDC_Server\$SCCM_ARDC_Share"
        }
        If(($Octet_2-eq126)-or($Octet_2-eq127)){
            $Primary_Site="\\$SCCM_UDCC_Server\$SCCM_UDCC_Share"
        }
        $SCCM_Client_Install="$Primary_Site\$SCCM_CLient";Break
    }
}
Set-Location -Path "$env:SystemRoot\System32"
If(!(Test-Path "$env:SystemRoot\System32\cmtrace.exe")){
    Copy-Item -Path "\\dca01.utshare.local\admin$\System32\cmtrace.exe"
}
If(!(Test-Path "$env:SystemRoot\System32\reboot.cmd")){
    Copy-Item -Path "\\dca01.utshare.local\admin$\System32\reboot.cmd"
}
If(!($Primary_Site-eq$null)){
    Start-Process -FilePath $SCCM_Client_Install -ArgumentList "/uninstall"
    $ccmsetup=(Get-Process -Name "ccmsetup").Id
    Wait-Process -Id $ccmsetup
    Remove-Item "$env:systemroot\ccm*" -Recurse -Force
    Start-Process -FilePath $SCCM_Client_Install
}