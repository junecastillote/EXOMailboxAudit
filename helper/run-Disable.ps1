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
Import-Module EXOMailboxAudit
Disable-DefaultMailboxAuditLogSet @params
Get-PSSession -Name ExchangeOnline* | ForEach-Object {$null = Disconnect-ExchangeOnline -Confirm:$false}