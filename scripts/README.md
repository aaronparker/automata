# Windows deployment configuration scripts

Various scripts for the customisation of Windows during unattended deployment. Including computer-level scripts used in desktop, RDSH and general server deployment.

## Get-AppxPackageFromStart.ps1

Returns the AppX package that correlates to the application display name on the Start menu. Returns the AppX package object that correlates to the application display name on the Start menu. Returns null if the name specified is not found or the shortcut points to a non-AppX app.

### PARAMETER

Name - specify a shortcut display name to return the AppX package for.
  
### EXAMPLE

```powershell
PS C:\> Get-AppxPackageFromStart -Name "Twitter"
```

Returns the AppX package for the shortcut 'Twitter'.

## Monitor-MDTProgress.ps1

Remotely monitor the progress of an MDT task sequence.

## New-VMWithMDTDeployment.ps1

A fully scripted approach to automating the end-to-end process of creating a VM and deploying an operating system via MDT.
