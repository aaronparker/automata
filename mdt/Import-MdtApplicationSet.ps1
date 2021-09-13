#Requires -RunAsAdministrator
<# 
    .SYNOPSIS
        Download applications for import into an MDT share
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $False)]    
    [System.String] $DeploymentShare = "E:\Deployment\Automata",

    [Parameter(Mandatory = $False)]
    [System.String] $RepoPath = "C:\Projects\automata",

    [Parameter(Mandatory = $False)]
    [System.String] $Definition = $(Join-Path -Path $RepoPath -ChildPath "Applications.json"),

    [Parameter(Mandatory = $False)]
    [System.String] $DownloadPath = (Get-Location).Path,

    [Parameter(Mandatory = $False)]
    [System.String] $Drive = "DS002"
)

#region Import the MDT PowerShell module
try {
    Write-Host -ForegroundColor "Cyan" -Object "Import module: MicrosoftDeploymentToolkit"
    $VerbosePref = $VerbosePreference
    $VerbosePreference = "SilentlyContinue"
    $MdtReg = Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Deployment 4" -ErrorAction "SilentlyContinue"
    Import-Module $([System.IO.Path]::Combine($MdtReg.Install_Dir, "bin", "MicrosoftDeploymentToolkit.psd1"))
    $VerbosePreference = $VerbosePref
}
catch {
    Throw $_
}
#endregion

#region Update modules
$Repository = "PSGallery"
If (Get-PSRepository | Where-Object { $_.Name -eq $Repository -and $_.InstallationPolicy -ne "Trusted" }) {
    try {
        Write-Host -ForegroundColor "Cyan" -Object "Trust repository: PSGallery"
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force
        Set-PSRepository -Name $Repository -InstallationPolicy "Trusted"
    }
    catch {
        Throw $_
    }
}

$Modules = "Evergreen", "VcRedist"
ForEach ($module in $Modules) {
    try {
        $installedModule = Get-Module -Name $module -ListAvailable | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } | `
            Select-Object -First 1
        $publishedModule = Find-Module -Name $module -ErrorAction "SilentlyContinue"
        If (($Null -eq $installedModule) -or ([System.Version]$publishedModule.Version -gt [System.Version]$installedModule.Version)) {
            Write-Host -ForegroundColor "Cyan" -Object "Install module: $module"
            $params = @{
                Name               = $module
                SkipPublisherCheck = $true
                Force              = $true
                ErrorAction        = "Stop"
            }
            Install-Module @params
            Import-Module -Name $module -Force
        }
    }
    catch {
        Throw $_
    }
}
#endregion

#region Mount the Deployment Share
Restore-MdtPersistentDrive
$psDrive = Get-MdtPersistentDrive | Where-Object { $_.Path -eq $DeploymentShare } | Select-Object -First 1
If ($Null -eq $psDrive) {
    try {
        Write-Host -ForegroundColor "Cyan" -Object "Connect to MDT deployment share"
        $params = @{
            Name       = $Drive
            PSProvider = "MDTProvider"
            Root       = $DeploymentShare
        }
        New-PSDrive @params | Add-MDTPersistentDrive
        $psDrive = Get-MdtPersistentDrive | Where-Object { $_.Path -eq $DeploymentShare -and $_.Name -eq $Drive } | Select-Object -First 1
        Restore-MdtPersistentDrive
    }
    catch [System.Exception] {
        Write-Warning -Message "$($MyInvocation.MyCommand): Failed to create MDT drive at: [$DeploymentShare]."
        Throw $_.Exception.Message
    }
}
#endregion


#region Read the application definition manifest JSON file
try {
    $Applications = Get-Content -Path $Definition | ConvertFrom-Json
}
catch {
    Throw $_
}
#endregion

#region Walk through JSON and import applications
ForEach ($Publisher in $Applications.Publishers | Get-Member -MemberType "NoteProperty") {
    ForEach ($App in $Applications.Publishers.($Publisher.Name) | Get-Member -MemberType "NoteProperty") {

        $Properties = $Applications.Publishers.($Publisher.Name).($App.Name)
        Write-Host -ForegroundColor "Cyan" -Object "Search: $($App.Name)."
        $AppUpdate = Invoke-Expression -Command $Properties.Filter
        $ExistingApp = Get-ChildItem -Path "$($psDrive.Name):\Applications" | Where-Object { $_.ShortName -eq $Properties.ShortName -and $_.Version -eq $AppUpdate.Version }

        If ([System.Version] $AppUpdate.Version -lt [System.Version] $ExistingApp.Version) {
            Write-Host -ForegroundColor "Cyan" -Object "Application: $($App.Name) $($AppUpdate.Version) is lower than existing: $($ExistingApp.Name) $($ExistingApp.Version)."
        }
        ElseIf ([System.Version] $AppUpdate.Version -eq [System.Version] $ExistingApp.Version) {
            Write-Host -ForegroundColor "Cyan" -Object "Application exists: $($App.Name) $($AppUpdate.Version)."
        }
        Else {
            Write-Host -ForegroundColor "Cyan" -Object "Importing application: $($App.Name) $($AppUpdate.Version)."
            New-Item -Path $(Join-Path -Path $DownloadPath -ChildPath $($App.Name)) -ItemType "Directory" -ErrorAction "SilentlyContinue" > $Null
            $Download = Save-EvergreenApp -Path $(Join-Path -Path $DownloadPath -ChildPath $($App.Name)) -InputObject $AppUpdate
            Get-ChildItem -Path $Download.DirectoryName -Recurse | Unblock-File

            #region Import the app
            try {
                $params = @{
                    Path                  = "$($psDrive.Name):\Applications"
                    Enable                = "True"
                    Reboot                = $False
                    Name                  = "$($Publisher.Name) $($Properties.ShortName) $($AppUpdate.Version)"
                    ShortName             = $Properties.ShortName
                    Version               = $AppUpdate.Version
                    Publisher             = $Publisher.Name
                    Language              = $Properties.Language
                    CommandLine           = $($Properties.Command -replace "#Installer", $Download.Name )
                    WorkingDirectory      = ".\Applications\$($Publisher.Name)\$($Properties.ShortName -replace " ")\$($AppUpdate.Version)"
                    ApplicationSourcePath = $Download.DirectoryName
                    DestinationFolder     = "$($Publisher.Name)\$($Properties.ShortName -replace " ")\$($AppUpdate.Version)"
                }
                Import-MDTApplication @params
            }
            catch {
                Throw $_
            }
            #endregion

            #region Copy additional files
            $Source = $([System.IO.Path]::Combine($RepoPath, "automata", "Applications", $App.Name))
            $Destination = $([System.IO.Path]::Combine($DeploymentShare, "Applications", $Publisher.Name, $($Properties.ShortName -replace " "), $AppUpdate.Version))
            If (Test-Path -Path $Source) {
                If (Test-Path -Path $Destination) {
                    try {
                        Write-Host -ForegroundColor "Cyan" -Object "Copy: $Source to $Destination."
                        $params = @{
                            Path        = $Source
                            Destination = $Destination
                            Filter      = "*"
                            Container   = $False
                            Recurse     = $True
                            Force       = $True
                        }
                        Copy-Item @params
                    }
                    catch {
                        Write-Warning -Message "Failed to copy from: $Source."
                    }
                }
                Else {
                    Write-Warning -Message "Skip copy. Folder does not exist: $Destination."
                }
            }
            #endregion

            #region Run a process
            If ($Properties.PostImport) {
                Push-Location -Path $Destination
                $params = @{
                    FilePath     = $Properties.PostImport.FilePath
                    ArgumentList = $Properties.PostImport.ArgumentList
                    NoNewWindow  = $True
                    Wait         = $True
                    Verbose      = $True
                }
                Start-Process @params
                Pop-Location
            }
            #endregion
        }

        # Remove the variable so that next run we don't inadvertently compare with the previous app
        Remove-Variable -Name "ExistingApp" -ErrorAction "SilentlyContinue"
    }
}
#endregion


#region VcRedists; Download the VcRedists & add to the deployment share
Write-Host -ForegroundColor "Cyan" -Object "Importing Microsoft Visual C++ Redistributables."
$VcPath = Join-Path -Path $DownloadPath -ChildPath "VcRedists"
New-Item -Path $VcPath -ItemType "Directory" -ErrorAction "SilentlyContinue" > $Null
$SaveVc = Save-VcRedist -VcList (Get-VcList) -Path $VcPath
$AppVc = Import-VcMdtApplication -VcList (Get-VcList) -Path $VcPath -MdtPath $DeploymentShare -Silent
$BundleVc = New-VcMdtBundle -MdtPath $DeploymentShare
#endregion

Write-Host -ForegroundColor "Cyan" -Object "Import complete."
