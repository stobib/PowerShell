Clear-History;Clear-Host
Set-Variable -Name Devices -Value @("1","3","4","5","6","7","8")
Set-Variable -Name Chassis -Value @("1","2","3","4","5","6","9")
Set-Variable -Name Sites -Value @("10.118.2.","10.126.2.")
Set-Variable -Name IPAddress -Value @()
Set-Variable -Name Loops -Value 5000
Set-Variable -Name Start -Value 101
Set-Variable -Name ResolveIP -Value $null
Set-Variable -Name ChassisName -Value $null
Set-Variable -Name CmcIPAddress -Value $null
Set-Variable -Name DType -Value $null
Set-Variable -Name SC -Value $null
$Global:CType="cmc1ke"
$Global:LServer=($env:LOGONSERVER)
$Global:UDomain=($env:USERDNSDOMAIN)
Set-Variable -Name DNSHost -Value (($LServer+"."+$UDomain).ToLower()).Replace("\\","")
ForEach($S In $Sites){
    $Start=101;$N=$null;$NetIPAddress=0
    ForEach($C In $Chassis){
        Switch(($S).Split(".")[1]){
            "118"{
                If($C-eq"9"){
                    $N="6"
                }Else{
                    $N=$C
                }
                $ResolveIP=($($S)+$($C)+"1")
                $ChassisName=($CType+$N+"a1.mgt."+$UDomain).ToLower();Break}
            "126"{
                If($C-eq"6"){
                    $N="7"
                }Else{
                    $N=$C
                }
                $ResolveIP=($($S)+$($N)+"1")
                $ChassisName=($CType+$C+"b1.mgt."+$UDomain).ToLower();Break}
        }
        $CmcIPAddress=(Resolve-DnsName -Name $ChassisName -ErrorAction SilentlyContinue).IPAddress
        If($CmcIPAddress-eq$ResolveIP){
            $R=$null;$HC=0
            Switch(($S).Split(".")[1]){
                "118"{
                    $R=$C
                    $HC=16
                    $SC="a"
                    Break}
                "126"{
                    $R=$N
                    If($R-eq7){
                        $HC=12
                        $Start+=16
                    }Else{
                        $HC=16
                    }
                    $SC="b"
                    Break}
            }
            ForEach($D In $Devices){
                $NetIPAddress=($S+$R+$D)
                $IPAddress+=$NetIPAddress
                $FQDN=(Resolve-DnsName $NetIPAddress -ErrorAction SilentlyContinue).NameHost
                If(($FQDN-eq$null)-and!($FQDN-eq$ChassisName)){
                    $DN=1;$DType=$null
                    Switch($D){
                        {($_-eq3)-or($_-eq8)}{
                            If($_-eq8){
                                $DN=2
                            }
                            $DType=("pem10"+$SC+$C+"a"+$DN+".mgt."+$UDomain).ToLower()
                            Break
                        }
                        {($_-eq4)-or($_-eq7)}{
                            If($_-eq7){
                                $DN=2
                            }
                            $DType=("pem10"+$SC+$C+"b"+$DN+".mgt."+$UDomain).ToLower()
                            Break
                        }
                        {($_-eq5)-or($_-eq6)}{
                            If($_-eq6){
                                $DN=2
                            }
                            $DType=("bc6505"+$SC+$C+"c"+$DN+".mgt."+$UDomain).ToLower()
                            Break
                        }
                    }
                    $FQDN=(Resolve-DnsName -Name $DType -ErrorAction SilentlyContinue).Name
                    If($FQDN-eq$null){
                        $NetBIOS=($DType).Split(".")[0]
                        Add-DnsServerResourceRecordA -Name $NetBIOS -ZoneName ("mgt."+$UDomain).ToLower() -AllowUpdateAny -IPv4Address $NetIPAddress -TimeToLive 01:00:00
                    }
                    $SO=($S).Split(".")[1]
                    Add-DnsServerResourceRecordPtr -Name ($R+$D) -ZoneName ("2."+$SO+".10.in-addr.arpa") -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord -PtrDomainName $DType
                }
            }
            For($h=1;$h-le$HC;$h++){
                $NetIPAddress=($S+$Start)
                $IPAddress+=$NetIPAddress
                $FQDN=(Resolve-DnsName $NetIPAddress -ErrorAction SilentlyContinue).NameHost
                If($FQDN-eq$null){
                    $SN=0;$DType=$null
                    If($h-le9){
                        $SN=($C+"0"+$h)
                    }Else{
                        $SN=($C+$h)
                    }
                    $DType=("m630"+$SC+$SN+".mgt."+$UDomain).ToLower()
                    $FQDN=(Resolve-DnsName -Name $DType -ErrorAction SilentlyContinue).Name
                    If($FQDN-eq$null){
                        $NetBIOS=($DType).Split(".")[0]
                        Add-DnsServerResourceRecordA -ComputerName $DNSHost -Name $NetBIOS -ZoneName ("mgt."+$UDomain).ToLower() -AllowUpdateAny -IPv4Address $NetIPAddress -TimeToLive 01:00:00
                    }
                    $SO=($S).Split(".")[1]
                    $SN=($NetIPAddress.Split(".")[3])
                    Add-DnsServerResourceRecordPtr -ComputerName $DNSHost -Name $SN -ZoneName ("2."+$SO+".10.in-addr.arpa") -AllowUpdateAny -TimeToLive 01:00:00 -AgeRecord -PtrDomainName $DType
                }
                $Start++
            }
        }
    }
}
Set-Variable -Name Count -Value 0
For($l=0;$l-lt$Loops;$l++){
    ForEach($IP In $IPAddress){
        ping -a -n 3 -w 50 $($IP)
    }
    $Count++
    $Msg=("The current loop count is: "+$Count+" of "+$Loops+" loops")
    Clear;Write-Host $Msg
}