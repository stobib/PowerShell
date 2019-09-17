Clear-Host;Clear-History
(get-winevent -listprovider microsoft-windows-printservice).events | format-table id, description -auto