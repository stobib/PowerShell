Param(
[Parameter(Position=0)]
[ValidateSet("Logon","Logoff","Unknown")]
[string]$Status="Unknown"
)
Clear-History;Clear-Host

#no spaces in the filter
[adsisearcher]$searcher="samaccountname=$env:username"
#find the current user
$find = $searcher.FindOne()
#get the user object
[adsi]$user = $find.Path
#define a string to indicate status
$note = "{0} {1} to {2}" -f (Get-Date),$status.ToUpper(),$env:computername
#update the Info user property
$user.Info=$note
#commit the change
$user.SetInfo()