Clear-History;Clear-Host
#Load Configuration Manager PowerShell Module
Import-module($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+'\ConfigurationManager.psd1')

#Get SiteServer and SiteCode
$SiteServer=$($(Get-PSDrive -PSProvider CMSite).Root).Split(".")[0]
$SiteCode=$(Get-PSDrive -PSProvider CMSite).Name
Set-Variable -Name SiteName -Value $null
Switch($SiteCode){
    "A01"{$SiteName="ARDC";$IPSubnets=@("10.118.0.0/16","10.119.0.0/16");Break}
    "B01"{$SiteName="UDCC";$IPSubnets=@("10.126.0.0/16","10.127.0.0/16");Break}
    Default{$SiteName=$null;Break}
}

#Set location within the SCCM environment
Set-location $SiteCode":"
$SiteServerFQDN=($SiteServer+".inf."+($env:USERDNSDOMAIN).ToLower())
$SiteBoundaries=(($env:USERDNSDOMAIN).ToLower()+"/"+$($SiteName)+"/"+$($IPSubnets)[0],($env:USERDNSDOMAIN).ToLower()+"/"+$($SiteName)+"/"+$($IPSubnets)[1]).split(" ")

#Create Boundaries for SCCM Site
$BoundaryObjs=@($SiteName)
New-CMBoundary -Name $SiteName -Type ADSite -Value $SiteName|Out-Null
For($i=0;$i-le1;$i++){
    New-CMBoundary -Name $SiteBoundaries[$i] -Type IPSubnet -Value $IPSubnets[$i]|Out-Null
    $BoundaryObjs+=$SiteBoundaries[$i]
}

#Create Boundary Group
New-CMBoundaryGroup -Name $SiteName -AddSiteSystemServerName $SiteServerFQDN|Out-Null

#Assign Boundaries to the Boundary Group
ForEach($BoundaryObj In $BoundaryObjs){
    $BoundaryObj=Get-CMBoundary -BoundaryName $BoundaryObj
    Add-CMBoundaryToGroup -InputObject $BoundaryObj -BoundaryGroupName $SiteName
}

#Set location back to operating system
Set-Location "$env:Systemroot\System32"
