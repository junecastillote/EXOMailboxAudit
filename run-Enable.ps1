$params = @{
    #outputDirectory = ''
    #logDirectory = ''
    adminCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    senderAddress = 'june@poshlab.ml'
    recipientAddress = @('june.castillote@gmail.com')
    removeOldFiles = 10
    sendEmail = $false
    smtpServer = 'smtp.office365.com'
    smtpPort = 587
    smtpCredential = (Import-Clixml (($env:temp) + "\ExoMailboxAudit\adminCredential.xml"))
    smtpSSL = $true
    AuditLogAgeLimit = 180
    # exclusionList = @()
    skipConnect = $true
    testMode = $false
    Verbose = $true
    forceupdate = $false
    includegroupmailbox = $true
}

Remove-Module EXOMailboxAudit -ErrorAction SilentlyContinue
Import-Module .\EXOMailboxAudit.psd1
Enable-MailboxAuditLog @params
# Get-PSSession -Name ExchangeOnline* | ForEach-Object {$null = Disconnect-ExchangeOnline -Confirm:$false}