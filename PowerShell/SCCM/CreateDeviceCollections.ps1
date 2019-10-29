Clear-History;Clear-Host
Function Create-Collection($CollName){
    If(($CollName-eq$Coll_1)-or($CollName-eq$Coll_2)-or($CollName-eq$Coll_3)){
        Write-Host " (Limited to 'All Systems'). " -NoNewline
        $LmtgCollName="All Systems"
    }ElseIf(($CollName-eq$Coll_6)-or($CollName-eq$Coll_7)-or($CollName-eq$Coll_8)-or($CollName-eq$Coll_9)){
        Write-Host " (Limited to '$Coll_1'). " -NoNewline
        $LmtgCollName="$Coll_1"
    }Else{
        Write-Host " (Limited to $Coll_3'). " -NoNewline
        $LmtgCollName="$Coll_3"
    }
    New-CMDeviceCollection -Name "$CollName" -LimitingCollName "$LmtgCollName" -RefreshType Both
}
Function Create-Collections{
    Write-Host "Checking if collections exist, if not, create them." -ForegroundColor Green
    $strColls=@("$Coll_1","$Coll_2","$Coll_3","$Coll_4","$Coll_5","$Coll_6","$Coll_7","$Coll_8","$Coll_9")
    ForEach($CollName in $strColls){
        If(Get-CMDeviceCollection -Name $CollName){
            Write-Host "The collection '$CollName' already exists, skipping."
        }Else{
            Write-Host "Creating collection: '$CollName'. " -NoNewline
            Create-Collection($CollName)|Out-Null
            Write-Host "Done!" -ForegroundColor Green
        }
    }
}
Function Add-Membership-Query($TgtColl){
    Write-Host "Adding membership query to '$TgtColl'." -ForegroundColor Green
    Write-Host "...checking for existing query which matches '$RuleName'. " -NoNewline
    $check_RuleName=Get-CMDeviceCollectionQueryMembershipRule -CollName "$TgtColl" -RuleName $RuleName|Select-String -pattern "RuleName"
    Write-Host "Done!" -ForegroundColor Green
    If($check_RuleName-eq$NULL){
        Write-Host "...adding the new query. " -NoNewline
        Add-CMDeviceCollectionQueryMembershipRule -CollName "$TgtColl" -QueryExpression "$RuleNameQuery" -RuleName "$RuleName"
        Write-Host "Done!" -ForegroundColor Green 
    }Else{
        Write-output "...that query already exists, will not add it again."
    }
}
$PSPath="E:\Scripts\BIN"
$Coll_1 = "All Workstations"
$Coll_2 = "All Servers"
$Coll_3 = "OSD Limiting"
$Coll_4 = "OSD Build"
$Coll_5 = "OSD Deploy"
$Coll_6 = "SUM Windows 10 Other"
$Coll_7 = "SUM Windows 10 CB"
$Coll_8 = "SUM Windows 10 CBB"
$Coll_9 = "SUM Windows 10 LTSB"
Write-Host "Starting script..." -ForegroundColor Yellow
Import-Module $PSPath'\ConfigurationManager.psd1'
$SiteCode=Get-PSDrive -PSProvider CMSite
Write-Host "Connecting to " -ForegroundColor White -NoNewline
Write-Host $SiteCode -ForegroundColor Green -NoNewLine
cd "$($SiteCode):"
Write-Host ", done." -ForegroundColor White
Create-Collections
$TgtColl=$Coll_1
$RuleName="All Workstations"
$RuleNameQuery="select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like '%Workstation%'"
Add-Membership-Query($TgtColl)
$TgtColl=$Coll_2
$RuleName="All Servers"
$RuleNameQuery="select * from  SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like '%Server%'"
Add-Membership-Query($TgtColl)
$TgtColl=$Coll_3
$RuleName="All Workstations and Manual Imported Computers"
$RuleNameQuery="select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.OperatingSystemNameandVersion like '%Workstation%' or SMS_R_System.AgentName = 'Manual Machine Entry'"
Add-Membership-Query($TgtColl)
$IncludeCollName="All Unknown Computers"
Write-Host "...checking for Include Collection query for '$IncludeCollName'. " -NoNewline
$check_IncludeRule = Get-CMDeviceCollectionIncludeMembershipRule -CollName "$TgtColl" -IncludeCollName "$IncludeCollName"|Select-String -pattern "RuleName"
Write-Host "Done!" -ForegroundColor Green
If($check_IncludeRule-eq$NULL){
    Write-Host "...adding the new query. " -NoNewline
    Add-CMDeviceCollectionIncludeMembershipRule -CollName $TgtColl -IncludeCollName "$IncludeCollName"
    Write-Host "Done!" -ForegroundColor Green
}Else{
    Write-output "...that query already exists, will not add it again."
}
$TgtColl=$Coll_4
$RuleName="Imported Computers"
$RuleNameQuery="select *  from  SMS_R_System where SMS_R_System.AgentName = 'Manual Machine Entry'"
Add-Membership-Query($TgtColl)
$TgtColl=$Coll_5
$IncludeCollName=$Coll_3
Write-Host "Adding membership query to '$TgtColl'." -ForegroundColor Green
Write-Host "...checking for Include Collection query for '$IncludeCollName'. " -NoNewline
$check_IncludeRule=Get-CMDeviceCollectionIncludeMembershipRule -CollName "$TgtColl" -IncludeCollName "$IncludeCollName"|Select-String -pattern "RuleName"
Write-Host "Done!" -ForegroundColor Green 
If($check_IncludeRule-eq$NULL){
    Write-Host "...adding the new query. " -NoNewline
    Add-CMDeviceCollectionIncludeMembershipRule -CollName $TgtColl -IncludeCollName "$IncludeCollName"
    Write-Host "Done!" -ForegroundColor Green
}Else{
    Write-output "...that query already exists, will not add it again."
}
Write-Host "Operations completed, exiting." -ForegroundColor Green