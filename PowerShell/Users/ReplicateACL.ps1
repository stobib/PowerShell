Clear-History;Clear-Host
Set-Variable -Name Domain -Value $env:USERDNSDOMAIN.ToLower()
Set-Variable -Name SourceACL -Value ("w16adfs01."+$Domain)
Set-Variable -Name TargetACL -Value ("w19adfs01."+$Domain)
Set-Variable -Name PathACL -Value @("developers","iso","profiles","stat-projects","stat-shared","sysadmins","users")
Set-Variable -Name FolderACL -Value ""
Set-Variable -Name TreeACL -Value ""
ForEach($Shares In $PathACL){
    $FolderACL=(Get-ChildItem -Path ("\\"+$SourceACL+"\"+$Shares) -Directory).Name
    Echo ("\\"+$SourceACL+"\"+$Shares)
    Get-Acl ("\\"+$SourceACL+"\"+$Shares)|Set-Acl ("\\"+$TargetACL+"\"+$Shares)
    ForEach($SubFolder In $FolderACL){
        Echo ("\\"+$SourceACL+"\"+$Shares+"\"+$SubFolder)
        Get-Acl ("\\"+$SourceACL+"\"+$Shares+"\"+$SubFolder)|Set-Acl ("\\"+$TargetACL+"\"+$Shares+"\"+$SubFolder)
        If(!(($Shares-eq"iso")-or($Shares-eq"profiles"))){
            $TreeACL=(Get-ChildItem -Path ("\\"+$SourceACL+"\"+$Shares+"\"+$SubFolder) -Directory).Name
            ForEach($SubFolders In $TreeACL){
                Echo ("\\"+$SourceACL+"\"+$Shares+"\"+$SubFolder+"\"+$SubFolders)
                Get-Acl ("\\"+$SourceACL+"\"+$Shares+"\"+$SubFolder+"\"+$SubFolders)|Set-Acl ("\\"+$TargetACL+"\"+$Shares+"\"+$SubFolder+"\"+$SubFolders)
            }
        }
    }
}