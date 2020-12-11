[CmdletBinding()]

param (
    [parameter()]
    [string]$ModulePath = $($env:PSModulePath -split ';')[1],
    [parameter()]
    [switch]$ForceInstall
)
$moduleManifest = Get-ChildItem -Path $PSScriptRoot -Filter *.psd1
$Moduleinfo = Test-ModuleManifest -Path ($moduleManifest.FullName)

Remove-Module ($Moduleinfo.Name) -ErrorAction SilentlyContinue

if (!$ModulePath) {
    # Get all PSModulePath
    $paths = ($env:PSModulePath -split ";")

    do {
        # Clear-Host
        # Display selection menu
        Write-Output "====== Module Install Location ======"
        Write-Output ""
        $i = 1
        $paths | ForEach-Object {
            Write-Output "$($i): $_"
            $i = $i + 1
        }
        Write-Output "Q: QUIT"
        Write-Output ""
        # ASK for input
        $userInput = Read-Host "Select the installation path"
    }
    until ($userInput -eq 'Q' -or ($userInput -lt ($paths.count + 1) -and $userInput -gt 0))

    if ($userInput -eq 'Q') {
        Write-Output ""
        Write-Output "QUIT"
        Write-Output ""
        return $null
    }
    $ModulePath = $paths[($userInput - 1)]
}
$ModulePath = $ModulePath + "\$($Moduleinfo.Name.ToString())\$($Moduleinfo.Version.ToString())"

## Check if the installation folder (version) exists
if (Test-Path $ModulePath) {
    if ($ForceInstall) {
        ## Delete the version subfolder if the same version exists
        Remove-Item -Path $ModulePath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $ModulePath -ItemType Directory | Out-Null
    }
    else {
        return "The module could not be installed because the folder $ModulePath already exists. If you want to force the installation of this module, use the -ForceInstall parameter."
    }
}

else {
    ## Create the folder if it does not exist
    New-Item -Path $ModulePath -ItemType Directory | Out-Null
}

try {
    Copy-Item -Path $PSScriptRoot\* -Include *.psd1, *.psm1 -Destination $ModulePath -Force -Confirm:$false -ErrorAction Stop
    Copy-Item -Path $PSScriptRoot\source -recurse -Destination $ModulePath -Force -Confirm:$false -ErrorAction Stop
    Write-Output ""
    Write-Output "Success. Installed to $ModulePath"
    Write-Output ""
    Import-Module ($Moduleinfo.Name) -RequiredVersion $Moduleinfo.Version
}
catch {
    Write-Output ""
    Write-Output "Failed"
    Write-Output $_.Exception.Message
    Write-Output ""
}