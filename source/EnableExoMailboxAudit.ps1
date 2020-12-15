Function Enable-DefaultMailboxAuditLogSet {
    [cmdletbinding()]
    [Alias('edma')]
    Param(
        # office 365 admin credential
        # you can pass the credential using variable ($adminCredential = Get-Credential)
        # then use parameter like so: -adminCredential $adminCredential
        # OR created an encrypted XML (Get-Credential | export-clixml <file.xml>)
        # then use parameter like so: -adminCredential (import-clixml <file.xml>)
        [Parameter()]
        [pscredential]$AdminCredential,

        #path to the output directory (eg. c:\scripts\output)
        [Parameter()]
        [string]$OutputDirectory = (($env:temp) + "\ExoMailboxAudit\Output"),
			
        [Parameter()]
        $AuditLogAgeLimit = 60,

        #path to the log directory (eg. c:\scripts\logs)
        [Parameter()]
        [string]$LogDirectory = (($env:temp) + "\ExoMailboxAudit\Logs"),

        #Switch to enable email report
        [Parameter()]
        [switch]$SendEmail,

        #Sender Email Address
        [Parameter()]
        [string]$SenderAddress,

        #Recipient Email Addresses - separate with comma
        [Parameter()]
        [string[]]$RecipientAddress,

        #SMTP Server
        [Parameter()]
        [string]$SmtpServer,

        #SMTP Server Port
        [Parameter()]
        [string]$SmtpPort = 25,

        # SMTP Server relay credential (if required)
        # you can pass the credential using variable ($smtpCredential = Get-Credential)
        # then use parameter like so: -smtpCredential $smtpCredential
        # OR created an encrypted XML (Get-Credential | export-clixml <file.xml>)
        # then use parameter like so: -smtpCredential (import-clixml <file.xml>)
        [Parameter()]
        [pscredential]$SmtpCredential,

        #SMTP Server credential
        [Parameter()]
        [switch]$SmtpSSL,

        #Delete older files (in days)
        [Parameter()]
        [int]$RemoveOldFiles,
		
        #Exclusion List
        [Parameter()]
        [string[]]$ExclusionList,

        #Test Mode
        [Parameter()]
        [switch]$TestMode,

        #Use if you want to skip connecting to Exchange PowerShell (if already connected)
        [Parameter()]
        [switch]$SkipConnect,

        #Use if you want to force update the audit set for all target mailbox
        [Parameter()]
        [switch]$ForceUpdate,

        #Use if you want to include group mailbox types
        [Parameter()]
        [switch]$IncludeGroupMailbox
    )

    Stop-TxnLogging
    Clear-Host

    $scriptInfo = Get-Module EXOMailboxAudit

    #Set Paths-------------------------------------------------------------------------------------------
    $Today = Get-Date
    [string]$fileSuffix = '{0:dd-MMM-yyyy_hh-mm_tt}' -f $Today
    $logFile = "$($logDirectory)\enable_transcript_$($fileSuffix).txt"

    #Create folders if not found
    if ($logDirectory) {
        if (!(Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
            #start transcribing----------------------------------------------------------------------------------
            Start-TxnLogging $logFile
            #----------------------------------------------------------------------------------------------------
        }
        else {
            Start-TxnLogging $logFile
        }
    }

    if (!(Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    }
    #----------------------------------------------------------------------------------------------------

    if ($PSBoundParameters.Count -eq 0) {
        Write-Output "You did not specify any paramaters. Terminating script."
        Stop-TxnLogging
        return $null
    }

    #parameter check ----------------------------------------------------------------------------------------------------
    $isAllGood = $true

    if ($sendEmail) {
        if (!$senderAddress) {
            Write-Verbose ("ERROR: A valid sender email address is not specified.")
            $isAllGood = $false
        }

        if (!$recipientAddress) {
            Write-Verbose ("ERROR: No recipients specified.")
            $isAllGood = $false
        }

        if (!$smtpServer) {
            Write-Verbose ("ERROR: No SMTP Server specified.")
            $isAllGood = $false
        }
    }

    if ($isAllGood -eq $false) {
        Stop-TxnLogging
        return $null
    }
    #----------------------------------------------------------------------------------------------------

    if ($testMode) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': TEST MODE ')
    }


    # Connect to O365 Shell
    if (!$skipConnect) {
        if ($adminCredential) {
            try {
                #open new Exchange Online Session
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': Login to Exchange Online... ')
                Connect-ExchangeOnline -Credential $adminCredential -ShowBanner:$false
            }
            catch {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": There was an error connecting to Exchange Online. Terminating Script")
                Stop-TxnLogging
                return $null
            }
        }
        else {
            Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': The administrator credential is not provided. Use the -adminCredential parameter to specify the administrator login')
            Stop-TxnLogging
            return $null
        }
    }

    # Check if EXO Session works
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'STOP'
    try {
        $orgData = Get-OrganizationConfig
        $tenantName = ($orgData).DisplayName
        $ErrorActionPreference = $eap
    }
    catch {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Make sure to connect to Exchange Online first. Terminating Script")
        Stop-TxnLogging
        $ErrorActionPreference = $eap
        return $null
    }

    # Get target mailbox
    Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': Retrieving Mailbox List... ')
    if ($ForceUpdate) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Force Update all mailbox is enabled")
        $mailboxes = @()
        $mailboxes += Get-Mailbox -ResultSize Unlimited | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        if ($IncludeGroupMailbox) {
            $mailboxes += Get-Mailbox -GroupMailbox -ResultSize Unlimited | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        }
    }
    else {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Get all mailbox with audit disabled")
        $mailboxes = @()
        $mailboxes += Get-Mailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $false } | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        if ($IncludeGroupMailbox) {
            $mailboxes += Get-Mailbox -GroupMailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $false } | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        }
    }

    $mailboxCount = ($mailboxes | Measure-Object).Count
    Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($mailboxCount) mailbox")
    if ($exclusionList) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($exclusionList.count) from the Exclusion List")
    }

    $includedMailbox = 0
    if ($mailboxes) {

        $outputFile = "$($outputDirectory)\enable_result_$($fileSuffix).txt"
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Saving Mailbox List to $($outputFile)")
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Enable Mailbox Auditing")

        foreach ($mailbox in ($mailboxes | Sort-Object PrimarySMTPAddress)) {
            if ($exclusionList -and $exclusionList -contains "$($mailbox.PrimarySMTPAddress)") {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress) -- EXCLUDE")
            }
            else {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress)")

                if (!$testMode) {
                    if ($mailbox.RecipientTypeDetails -eq 'GroupMailbox') {
                        Set-Mailbox $mailbox.PrimarySMTPAddress -GroupMailbox -AuditEnabled $true -AuditLogAgeLimit $AuditLogAgeLimit -DefaultAuditSet admin,delegate,owner -Confirm:$false -Force
                    }
                    else {
                        Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $true -AuditLogAgeLimit $AuditLogAgeLimit -DefaultAuditSet admin,delegate,owner -Confirm:$false -Force
                    }
                }
                $mailbox.PrimarySMTPAddress | Out-File $outputFile -Append
                $includedMailbox = $includedMailbox + 1
            }
        }

        if ($sendEmail -and $includedMailbox -gt 0) {
            $subject = "Enable Mailbox Audit Task"
            if ($testMode) {
                $subject = "[TEST MODE] $($subject)"
            }
            Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Sending Email Report")
            $mailBody = "Attached is the list of mailboxes whose audit log was enabled by this script <br /><a href=""$($scriptInfo.ProjectURI)"">$($scriptInfo.Name)</a> version $($scriptInfo.version)"
            $mailParams = @{
                smtpServer  = $smtpServer
                port        = $smtpPort
                to          = $recipientAddress
                from        = $senderAddress
                subject     = "[$($tenantName)] $($subject)"
                body        = $mailBody
                bodyAsHTML  = $true
                Attachments = $outputFile
            }
            if ($smtpCredential) { $mailParams += @{credential = $smtpCredential } }
            if ($smtpSSL) { $mailParams += @{useSSL = $smtpSSL } }
            Send-MailMessage @mailParams
        }
    }

    #Invoke Housekeeping---------------------------------------------------------------------------------
    #if ($enableHousekeeping)
    if ($removeOldFiles) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Deleting log files older than $($removeOldFiles) days")
        Invoke-Housekeeping -folderPath $outputDirectory -daysToKeep $removeOldFiles
        Invoke-Housekeeping -folderPath $logDirectory -daysToKeep $removeOldFiles
    }
    #-----------------------------------------------------------------------------------------------

    Stop-TxnLogging
}