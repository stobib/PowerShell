function New-HgsGuardian
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [Parameter(ValueFromPipeline=$true, Mandatory=$true, Position=1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory=$true, Position=2, ParameterSetName="AcceptCertificates")]
        [ValidateNotNullOrEmpty()]
        [String]
        $SigningCertificate,

        [Parameter(Mandatory=$true, Position=3, ParameterSetName="AcceptCertificates")]
        [ValidateNotNullOrEmpty()]
        [SecureString]
        $SigningCertificatePassword,

        [Parameter(Mandatory=$true, Position=4, ParameterSetName="AcceptCertificates")]
        [ValidateNotNullOrEmpty()]
        [String]
        $EncryptionCertificate,

        [Parameter(Mandatory=$true, Position=5, ParameterSetName="AcceptCertificates")]
        [ValidateNotNullOrEmpty()]
        [SecureString]
        $EncryptionCertificatePassword,

        [Parameter(Position=6, ParameterSetName="AcceptCertificates")]
        [Parameter(Position=4, ParameterSetName="ByThumbprints")]
        [ValidateNotNullOrEmpty()]
        [Switch]
        $AllowExpired,

        [Parameter(Position=7, ParameterSetName="AcceptCertificates")]
        [Parameter(Position=5, ParameterSetName="ByThumbprints")]
        [ValidateNotNullOrEmpty()]
        [Switch]
        $AllowUntrustedRoot,

        [Parameter(Mandatory=$true, Position=2, ParameterSetName="GenerateCertificates")]
        [ValidateNotNullOrEmpty()]
        [Switch]
        $GenerateCertificates,

        [Parameter(Mandatory=$true, Position=2, ParameterSetName="ByThumbprints")]
        [ValidateNotNullOrEmpty()]
        [String]
        $SigningCertificateThumbprint,

        [Parameter(Mandatory=$true, Position=3, ParameterSetName="ByThumbprints")]
        [ValidateNotNullOrEmpty()]
        [String]
        $EncryptionCertificateThumbprint
    )

    Process
    {
        if ($PSCmdlet.ShouldProcess($Name))
        {
            if ($PSCmdlet.ParameterSetName -eq "AcceptCertificates")
            {
                $SigningCertificate = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($SigningCertificate)
                $EncryptionCertificate = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($EncryptionCertificate)

                $DecryptedSigningCertificatePassword = $null
                $DecryptedEncryptionCertificatePassword = $null

                if ($SigningCertificatePassword -ne $null)
                {
                    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SigningCertificatePassword)
                    $DecryptedSigningCertificatePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
                }

                if ($EncryptionCertificatePassword -ne $null)
                {
                    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($EncryptionCertificatePassword)
                    $DecryptedEncryptionCertificatePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)
                }

                $args = @{
                    Name                          = $Name;
                    SigningCertificate            = $SigningCertificate;
                    SigningCertificatePassword    = $DecryptedSigningCertificatePassword;
                    EncryptionCertificate         = $EncryptionCertificate;
                    EncryptionCertificatePassword = $DecryptedEncryptionCertificatePassword;
                    AllowExpired                  = $AllowExpired.IsPresent;
                    AllowUntrustedRoot            = $AllowUntrustedRoot.IsPresent;
                }

                (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName NewByAcceptCertificates -Arguments $args -Confirm:$false).CmdletOutput
            }
            elseif ($PSCmdlet.ParameterSetName -eq "ByThumbprints")
            {
                $args = @{
                    Name                            = $Name;
                    SigningCertificateThumbprint    = $SigningCertificateThumbprint;
                    EncryptionCertificateThumbprint = $EncryptionCertificateThumbprint;
                    AllowExpired                    = $AllowExpired.IsPresent;
                    AllowUntrustedRoot              = $AllowUntrustedRoot.IsPresent;
                }

                (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName NewByCertificateThumbprints -Arguments $args -Confirm:$false).CmdletOutput
            }
            elseif ($PSCmdlet.ParameterSetName -eq "GenerateCertificates")
            {
                $args = @{Name=$Name;GenerateCertificates=$GenerateCertificates.IsPresent}
                (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName NewByGenerateCertificates -Arguments $args -Confirm:$false).CmdletOutput
            }
        }
    }
}

function Export-HgsGuardian
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    [OutputType([void])]
    param(
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsGuardian")]
        [Parameter(ValueFromPipeline=$true, Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName=$true, Position=2, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("FilePath")]
        [System.String]
        $Path
    )

    Process
    {
        $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
        $args = @{InputObject=$InputObject;Path=$Path}
        Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName Export -Arguments $args | Out-Null
    }
}

function Import-HgsGuardian
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [Parameter(ValueFromPipeline=$true, Position=1, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("FilePath")]
        [System.String]
        $Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Switch]
        $AllowExpired,

        [Switch]
        $AllowUntrustedRoot
    )

    Process
    {
        if($PSCmdlet.ShouldProcess($Name))
        {
            $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)

            if($Name)
            {
                $args = @{AllowExpired=$AllowExpired.IsPresent;AllowUntrustedRoot=$AllowUntrustedRoot.IsPresent;Name=$Name;Path=$Path}
            }
            else
            {
                $args = @{AllowExpired=$AllowExpired.IsPresent;AllowUntrustedRoot=$AllowUntrustedRoot.IsPresent;Path=$Path}
            }

            (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName Import -Arguments $args -Confirm:$false).CmdletOutput
        }
    }
}

function Remove-HgsGuardian
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    [OutputType([System.Int32])]
    param(
        [Parameter(ValueFromPipeline=$true, Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    )

    Process
    {
        if($PSCmdlet.ShouldProcess($Name))
        {
            $args = @{Name = $Name}
            (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsGuardian -MethodName Remove -Arguments $args -Confirm:$false).CmdletOutput
        }
    }
}

function Grant-HgsKeyProtectorAccess
{
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsKeyProtector")]
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $KeyProtector,

        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsGuardian")]
        [Parameter(ValueFromPipeline=$true, Mandatory=$true, ParameterSetName="InputObject")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Guardian,

        [Parameter(Mandatory=$true, ParameterSetName="FriendlyName")]
        [ValidateNotNullOrEmpty()]
        [String]
        $GuardianFriendlyName,

        # Specifies whether allow untrusted root certificate
        [Switch]
        $AllowUntrustedRoot,

        # Specifies whether allow expired certificate
        [Switch]
        $AllowExpired
    )

    Process
    {

        if ($GuardianFriendlyName)
        {
            $Guardian = Get-HgsGuardian $GuardianFriendlyName
        }

        if($Guardian)
        {
            $args = @{KeyProtector=$KeyProtector; Guardian=$Guardian; AllowUntrustedRoot=$AllowUntrustedRoot.IsPresent; AllowExpired=$AllowExpired.IsPresent}

            (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsKeyProtector -MethodName Grant -Arguments $args).CmdletOutput
        }
    }
}

function Revoke-HgsKeyProtectorAccess
{
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsKeyProtector")]
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $KeyProtector,

        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsGuardian")]
        [Parameter(ValueFromPipeline=$true, Mandatory=$true, ParameterSetName="InputObject")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Guardian,

        [Parameter(Mandatory=$true, ParameterSetName="FriendlyName")]
        [ValidateNotNullOrEmpty()]
        [String]
        $GuardianFriendlyName
    )

    Process
    {
        if ($GuardianFriendlyName)
        {
            $Guardian = Get-HgsGuardian $GuardianFriendlyName
        }

        if($Guardian)
        {
            $args = @{KeyProtector=$KeyProtector; Guardian=$Guardian}

            (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsKeyProtector -MethodName Revoke -Arguments $args).CmdletOutput
        }
    }
}

function New-HgsKeyProtector
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsGuardian")]
        [Parameter(ValueFromPipeline=$true, Mandatory=$true, Position=1)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Owner,

        [PSTypeName("Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Hgs/MSFT_HgsGuardian")]
        [Parameter(ValueFromPipeline=$true, Position=2)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Guardian,

        [Parameter(Position=3)]
        [ValidateNotNullOrEmpty()]
        [Switch]
        $AllowExpired,

        [Parameter(Position=4)]
        [ValidateNotNullOrEmpty()]
        [Switch]
        $AllowUntrustedRoot
    )

    Process
    {
        $args = @{
            Owner                         = $Owner;
            Guardian                      = $Guardian;
            AllowExpired                  = $AllowExpired.IsPresent;
            AllowUntrustedRoot            = $AllowUntrustedRoot.IsPresent;
        }

        (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsKeyProtector -MethodName NewByGuardians -Arguments $args).CmdletOutput
    }
}

function Set-HgsClientConfiguration
{
    [CmdletBinding(SupportsShouldProcess=$true,
                   ConfirmImpact='Medium')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param(
        [Parameter(ParameterSetName="ChangeToLocalMode")]
        [Switch]
        $EnableLocalMode,

        [Parameter(ParameterSetName="SecureHostingServiceMode", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [System.String]
        $KeyProtectionServerUrl,

        [Parameter(ParameterSetName="SecureHostingServiceMode", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [System.String]
        $AttestationServerUrl
    )

    Process
    {
        if ($PSCmdlet.ShouldProcess((HOSTNAME)))
        {
            if($PSCmdlet.ParameterSetName -eq "ChangeToLocalMode")
            {
                (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsClientConfiguration -MethodName SetByChangeToLocalMode -Confirm:$false).CmdletOutput
            }
            elseif($PSCmdlet.ParameterSetName -eq "SecureHostingServiceMode")
            {
                $args = @{
                    KeyProtectionServerUrl         = $KeyProtectionServerUrl;
                    AttestationServerUrl           = $AttestationServerUrl;
                }

                (Invoke-CimMethod -Namespace Root\Microsoft\Windows\Hgs -Class MSFT_HgsClientConfiguration -MethodName SetBySecureHostingServiceMode -Arguments $args -Confirm:$false).CmdletOutput
            }
        }
    }
}
