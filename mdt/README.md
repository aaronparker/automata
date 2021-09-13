# Project Automata

A standardised Microsoft Deployment Toolkit deployment share.

* `New-MdtDeploymentShare.ps1` - create a new MDT deployment share and import Project Automata settings
* `Import-MdtApplicationSet.ps1` - import a set of applications defined in `Applications.json`. Skips import if the applications exists.

## New-MdtDeploymentShare example

```powershell
@params = @{
    DeploymentShare = "E:\Deployment\Automata"
    NetworkPath     = "\\server\Automata"
    SmbShare        = "Automata"
    RepoPath        = "C:\Projects\automata"
    IsoPath         = "C:\ISOs\en_windows_10_business_editions_version_21h1_x64_dvd_ec5a76c1.iso"
    Configuration   = "C:\Projects\automata\mdt\Windows10Enterprise.json"
}
.\New-MdtDeploymentShare.ps1 @params
```

## Import-MdtApplicationSet example

```powershell
@params = @{
    DeploymentShare = "E:\Deployment\Automata"
    RepoPath        = "C:\Projects\automata"
    DownloadPath    = "C:\Apps\Download"
    Verbose         = $True
    Definition      = "C:\Projects\automata\mdt\Applications.json"
}
.\Import-MdtApplicationSet.ps1 @params
```
