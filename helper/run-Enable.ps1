$params = @{
    # outputDirectory = ''
    # logDirectory = ''
    adminCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    senderAddress = 'june@poshlab.ml'
    recipientAddress = @('june.castillote@gmail.com')
    removeOldFiles = 10
    sendEmail = $false
    smtpServer = 'smtp.office365.com'
    smtpPort = 587
    smtpCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    smtpSSL = $true
    AuditLogAgeLimit = 60
    # exclusionList = @()
    skipConnect = $false
    testMode = $true
    Verbose = $true
    forceupdate = $false
    includegroupmailbox = $true
}

Remove-Module EXOMailboxAudit -ErrorAction SilentlyContinue
Import-Module EXOMailboxAudit
Enable-DefaultMailboxAuditLogSet @params
Get-PSSession -Name ExchangeOnline* | ForEach-Object {$null = Disconnect-ExchangeOnline -Confirm:$false}