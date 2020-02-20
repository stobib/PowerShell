Clear-History;Clear-Host
Set-Variable -Name Domain -Value $env:USERDNSDOMAIN.ToLower()
Set-Variable -Name SourceACL -Value ("w16adfs01."+$Domain)
Set-Variable -Name TargetACL -Value ("w19adfs01."+$Domain)
#Set-Variable -Name PathACL -Value @("developers","iso","profiles","stat-projects","stat-shared","sysadmins","users")
Set-Variable -Name PathACL -Value @("AR","SY")
Set-Variable -Name FolderACL -Value ""
Set-Variable -Name TreeACL -Value ""
ForEach($Shares In $PathACL){
    $FolderACL=(Get-ChildItem -Path ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices") -Directory).Name
    Echo ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices")
    Get-Acl ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices")
    ForEach($SubFolder In $FolderACL){
        Echo ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder)
        Get-Acl ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder)|Set-Acl ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder)
        If(!(($Shares-eq"iso")-or($Shares-eq"profiles"))){
            $TreeACL=(Get-ChildItem -Path ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder) -Directory).Name
            ForEach($SubFolders In $TreeACL){
                Echo ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder+"\"+$SubFolders)
                Get-Acl ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder+"\"+$SubFolders)|Set-Acl ("\\"+$SourceACL+"\stat-shared\"+$Shares+"\SharedServices\"+$SubFolder+"\"+$SubFolders)
            }
        }
    }
}