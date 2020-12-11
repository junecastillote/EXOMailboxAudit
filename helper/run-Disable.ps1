$params = @{
    # outputDirectory = ''
    # logDirectory = ''
    adminCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    removeOldFiles = 10
    # exclusionList = @('Fred@poshlab.ml')
    skipConnect = $false
    testMode = $true
    Verbose = $true
    forceupdate = $false
    includegroupmailbox = $true
}

Remove-Module EXOMailboxAudit -ErrorAction SilentlyContinue
# $moduleRoot = (resolve-path $PSScriptRoot\..).Path
# & $moduleRoot\install.ps1 -ForceInstall
Import-Module EXOMailboxAudit
Disable-DefaultMailboxAuditLogSet @params
Get-PSSession -Name ExchangeOnline* | ForEach-Object {$null = Disconnect-ExchangeOnline -Confirm:$false}