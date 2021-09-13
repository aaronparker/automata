#Requires -RunAsAdministrator
<#
    .SYNOPSIS
        Update applications in an MDT share
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [System.String] $DeploymentShare = "E:\Deployment\Automata",

    [Parameter()]
    [System.String] $NetworkPath = "\\APNUC1\DeploymentShare",

    [Parameter()]
    [System.String] $SmbShare = "DeploymentShare",

    [Parameter()]
    [System.String] $RepoPath = (Get-Location).Path,

    [Parameter()]
    [System.String] $Drive = "DS002",

    [Parameter()]
    [SupportsWildcards()]
    [System.String] $IsoPath = "C:\ISOs\en_windows_10_business_editions_version_21h1_x64_dvd_ec5a76c1.iso",

    [Parameter(Mandatory = $True)]
    [System.String] $Configuration
)

# Import the configuration file
try {
    $Config = Get-Content -Path $Configuration | ConvertFrom-Json
}
catch {
    Throw $_
}

# Import the MDT PowerShell module
try {
    $MdtReg = Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Deployment 4" -ErrorAction "SilentlyContinue"
    Import-Module $([System.IO.Path]::Combine($MdtReg.Install_Dir, "bin", "MicrosoftDeploymentToolkit.psd1"))
}
catch {
    Throw $_
}

# Create the share
New-Item -Path $DeploymentShare -ItemType "Directory" -ErrorAction "SilentlyContinue"
New-SmbShare -Name $SmbShare -Path $DeploymentShare -FullAccess "Administrators"

# Create the new Deployment Share
try {
    $params = @{
        Name        = $Drive
        PSProvider  = "MDTProvider"
        Root        = $DeploymentShare
        Description = $Config.Description
        NetworkPath = $NetworkPath
    }
    New-PSDrive @params | Add-MDTPersistentDrive
}
catch {
    Throw $_
}

# Mount the Windows ISO to import the OS
try {
    $Image = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $DriveLetter = (Get-Volume | Where-Object { $_.Size -eq $Image.Size }).DriveLetter
}
catch {
    Throw $_
}

# Create the folder to store the imported OS
$params = @{
    Path     = "$($Drive):\Operating Systems"
    Enable   = "True"
    Name     = "$($Config.OSLabel) $($Config.Release)"
    Comments = ""
    ItemType = "folder"
}
New-Item @params

# Import the OS source files
try {
    $params = @{
        Path              = "$($Drive):\Operating Systems\$($Config.OSLabel) $($Config.Release)"
        SourcePath        = "$($DriveLetter):\"
        DestinationFolder = "$($Config.OSLabel) $($Config.Release) $($Config.$Architecture)"
    }
    Import-MdtOperatingSystem @params
}
catch {
    Throw $_
}

# Create the folder to store the task sequences
$params = @{
    Path     = "$($Drive):\Task Sequences"
    Enable   = "True"
    Name     = "$($Config.OSLabel) $($Config.Release)"
    Comments = ""
    ItemType = "folder"
}
New-Item @params

# Create the task sequence
Switch ($Config.Edition) {
    "Pro" { $ShortEdition = "PRO" }
    "Enterprise" { $ShortEdition = "ENT" }
    "Standard" { $ShortEdition = "STD" }
    "Datacenter" { $ShortEdition = "DC" }
}
$OperatingSystemPath = "$($Drive):\Operating Systems\$($Config.OSLabel) $($Config.Release)\$($Config.OSLabel) $($Config.Edition) in $($Config.OSLabel) $($Config.Release) $($Config.Architecture) install.wim"
$params = @{
    Path                = "$($Drive):\Task Sequences\$($Config.OSLabel) $($Config.Release)"
    Name                = "$($Config.OSLabel) $($Config.Edition) $($Config.Architecture) $($Config.Release)"
    Template            = $Config.TsTemplate
    Comments            = $Config.Comments
    ID                  = "$($Config.Release)-$ShortEdition"
    Version             = $Config.Version
    OperatingSystemPath = $OperatingSystemPath
    FullName            = $Config.$Organisation
    OrgName             = $Config.$Organisation
    HomePage            = "about:blank"
}
Import-MdtTaskSequence @params

# Create the OS catalog file
try {
    $OperatingSystem = Get-ItemProperty -Path $OperatingSystemPath
    $params = @{
        ImageFile = $(Join-Path -Path $DeploymentShare -ChildPath $OperatingSystem.ImageFile.TrimStart("."))
        Index     = $OperatingSystem.ImageIndex
    }
    Get-MDTOperatingSystemCatalog @params
}
catch {
    Write-Error -Message "Failed to create the catalog file for image."
}

# Copy Control items
$Source = [System.IO.Path]::Combine($RepoPath, "automata", "Control")
$params = @{
    Path        = $Source
    Destination = $(Join-Path -Path $DeploymentShare -ChildPath "Control")
    Filter      = "*.ini"
    Container   = $False
    Force       = $True
}
Copy-Item @params

# Get the target GUID
$TargetOS = "$($Drive):\Operating Systems\$($Config.OSLabel) $($Config.Release)\$($Config.OSLabel) $($Config.$Edition) in $($Config.OSLabel) $($Config.$Architecture) install.wim"
$Guid = (Get-Item -Path $TargetOS).guid
