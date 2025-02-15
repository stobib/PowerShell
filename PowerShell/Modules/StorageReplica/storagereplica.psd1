        @{
            GUID = 'F04004D8-804D-4427-8311-92FA44BCE42C'
            Author="Microsoft Corporation"
            CompanyName="Microsoft Corporation"
            Copyright="� Microsoft Corporation. All rights reserved."
            PowerShellVersion = '3.0'
            CLRVersion="4.0"
            HelpInfoUri="http://go.microsoft.com/fwlink/?linkid=397379"
            ModuleVersion = '1.0'
            
            TypesToProcess = 'wvr.types.ps1xml'
            NestedModules = @("MSFT_WvrAdminTasks.cdxml","Microsoft.FileServices.SR.Powershell.dll","StorageReplica.psm1")
            RequiredAssemblies="Microsoft.FileServices.SR.Powershell.dll"
            CmdletsToExport = @('Test-SRTopology')
            FunctionsToExport = @('New-SRGroup',
                                  'Remove-SRGroup',
                                  'Set-SRGroup',
                                  'Get-SRGroup',
                                  'Suspend-SRGroup',
                                  'Sync-SRGroup',
                                  'Get-SRPartnership',
                                  'Remove-SRPartnership',
                                  'New-SRPartnership',
                                  'Set-SRPartnership',
                                  'Clear-SRMetadata',
                                  'Grant-SRAccess',
                                  'Revoke-SRAccess',
                                  'Get-SRAccess',
                                  'Grant-SRDelegation',
                                  'Get-SRDelegation',
                                  'Revoke-SRDelegation',
                                  'Export-SRConfiguration',
                                  'Set-SRNetworkConstraint',
                                  'Get-SRNetworkConstraint',
                                  'Remove-SRNetworkConstraint')

        }
