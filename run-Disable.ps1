$params = @{
    #outputDirectory = ''
    #logDirectory = ''
    adminCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    removeOldFiles = 10
    # exclusionList = @('Fred@poshlab.ml')
    skipConnect = $true
    testMode = $false
    Verbose = $true
    forceupdate = $false
    includegroupmailbox = $true
}

Remove-Module EXOMailboxAudit -ErrorAction SilentlyContinue
Import-Module .\EXOMailboxAudit.psd1
Disable-MailboxAuditLog @params
# Get-PSSession -Name ExchangeOnline* | ForEach-Object {$null = Disconnect-ExchangeOnline -Confirm:$false}