# Next collection # 67
#Collection  


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 #Collection  Template
<#
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={""}},@{L="Query"
; E={@("")}},@{L="RuleName"
; E={@("")}},@{L="CollectionQueries"
; E={0}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={""}},@{L="Folder"
; E={"root"}}
#>
 #Collection  Template

#Collection  64
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"$($SiteName) Workstations (No Client)"}},@{L="Query"
; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where (SMS_R_System.Client = 0 or SMS_R_System.Client is null ) and SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Workstation%""")}},@{L="RuleName"
; E={@("$($SiteName) - Client Workstations")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Systems assigned to $($SiteName) without SCCM Client"}},@{L="Comment"
; E={"Collection for identifying workstations without SCCM Client"}},@{L="Folder"
; E={"Sites"}}

#Collection  65
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"$($SiteName) Servers (No Client)"}},@{L="Query"
; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where (SMS_R_System.Client = 0 or SMS_R_System.Client is null ) and SMS_R_System.OperatingSystemNameandVersion like ""%Windows%Server%""")}},@{L="RuleName"
; E={@("$($SiteName) - Client Servers")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Systems assigned to $($SiteName) without SCCM Client"}},@{L="Comment"
; E={"Collection for identifying servers without SCCM Client"}},@{L="Folder"
; E={"Sites"}}

#Collection  66
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"$($SiteName) (Assigned Site)"}},@{L="Query"
; E={@("select distinct SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.SystemOUName = ""API.UTSHARE.LOCAL/ALLSERVERS"" or SMS_R_System.SystemOUName = ""API.UTSHARE.LOCAL/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""UAT.UTSHARE.LOCAL/ALLSERVERS"" or SMS_R_System.SystemOUName = ""UAT.UTSHARE.LOCAL/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""PRD.UTSHARE.LOCAL/ALLSERVERS"" or SMS_R_System.SystemOUName = ""PRD.UTSHARE.LOCAL/DOMAIN CONTROLLERS"" or SMS_R_System.SystemOUName = ""UTSHARE.LOCAL/ALLWRKSTNS"" or SMS_R_System.SystemOUName = ""UTSHARE.LOCAL/ALLSERVERS"" or SMS_R_System.SystemOUName = ""UTSHARE.LOCAL/DOMAIN CONTROLLERS""")}},@{L="RuleName"
; E={@("$($SiteName) - Client systems")}},@{L="CollectionQueries"
; E={1}},@{L="IncludeExcludeCollectionsCount"
; E={0}},@{L="IncludeCollections"
; E={@("")}},@{L="ExcludeCollections"
; E={@("")}},@{L="LimitingCollection"
; E={"All Systems assigned to $($SiteName)"}},@{L="Comment"
; E={"Collection for identifying systems with SCCM Client"}},@{L="Folder"
; E={"Sites"}}
