Function Enable-MailboxAuditLog {
    [cmdletbinding()]
    Param(
        # office 365 admin credential
        # you can pass the credential using variable ($adminCredential = Get-Credential)
        # then use parameter like so: -adminCredential $adminCredential
        # OR created an encrypted XML (Get-Credential | export-clixml <file.xml>)
        # then use parameter like so: -adminCredential (import-clixml <file.xml>)
        [Parameter()]
        [pscredential]$adminCredential,

        #path to the output directory (eg. c:\scripts\output)
        [Parameter()]
        [string]$outputDirectory = (($env:temp) + "\ExoMailboxAudit\Output"),
			
        [Parameter()]
        $AuditLogAgeLimit = 180,

        #path to the log directory (eg. c:\scripts\logs)
        [Parameter()]
        [string]$logDirectory = (($env:temp) + "\ExoMailboxAudit\Logs"),

        #Switch to enable email report
        [Parameter()]
        [switch]$sendEmail,
        
        #Sender Email Address
        [Parameter()]
        [string]$senderAddress,

        #Recipient Email Addresses - separate with comma
        [Parameter()]
        [string[]]$recipientAddress,

        #SMTP Server
        [Parameter()]
        [string]$smtpServer,

        #SMTP Server Port
        [Parameter()]
        [string]$smtpPort = 25,

        # SMTP Server relay credential (if required)
        # you can pass the credential using variable ($smtpCredential = Get-Credential)
        # then use parameter like so: -smtpCredential $smtpCredential
        # OR created an encrypted XML (Get-Credential | export-clixml <file.xml>)
        # then use parameter like so: -smtpCredential (import-clixml <file.xml>)
        [Parameter()]
        [pscredential]$smtpCredential,

        #SMTP Server credential
        [Parameter()]
        [switch]$smtpSSL,

        #Delete older files (in days)
        [Parameter()]
        [int]$removeOldFiles,
		
        #Exclusion List
        [Parameter()]
        [string[]]$exclusionList,

        #Test Mode
        [Parameter()]
        [switch]$testMode,

        #Use if you want to skip connecting to Exchange PowerShell (if already connected)
        [Parameter()]
        [switch]$skipConnect
    )

    # $script_root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    # #Import Functions
    # . "$script_root\Functions.ps1"

    Stop-TxnLogging
    Clear-Host
    # $scriptInfo = Test-ScriptFileInfo -Path $MyInvocation.MyCommand.Definition
    $scriptInfo = Get-Module EXOMailboxAudit

    #Set Paths-------------------------------------------------------------------------------------------
    $Today = Get-Date
    [string]$fileSuffix = '{0:dd-MMM-yyyy_hh-mm_tt}' -f $Today
    $logFile = "$($logDirectory)\Log_$($fileSuffix).txt"

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
                Connect-ExchangeOnline -Credential $adminCredential
            }
            catch {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": There was an error connecting to Exchange Online. Terminating Script")
                Stop-TxnLogging
                return $null
            }
        }
        else {
            Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': The administrator credential is not provided. Use the -adminCredential parameter to specify the administrator login')
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
    # Write-Verbose 'Hello'

    # Get all mailboxes with disabled auditing
    Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': Retrieving Mailbox List... ')
    $mailboxes = Get-Mailbox -Filter { (RecipientTypeDetails -eq "UserMailbox" -or RecipientTypeDetails -eq "SharedMailbox" -or RecipientTypeDetails -eq "RoomMailbox" -or RecipientTypeDetails -eq "DiscoveryMailbox") -and (AuditEnabled -eq $false) } | Select-Object PrimarySMTPAddress | Sort-Object PrimarySMTPAddress
    $mailboxCount = ($mailboxes | Measure-Object).Count
    Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($mailboxCount) with audit logs disabled")
    if ($exclusionList) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($exclusionList.count) from the Exclusion List")
    }

    $includedMailbox = 0
    if ($mailboxes) {

        $outputFile = "$($outputDirectory)\output_$($fileSuffix).txt"
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Saving Mailbox List to $($outputFile)")
        #$mailboxes | Select-Object PrimarySMTPAddress | export-csv -nti $outputFile

        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Enable Mailbox Auditing")

        foreach ($mailbox in $mailboxes) {
            if ($exclusionList -and $exclusionList -contains "$($mailbox.PrimarySMTPAddress)") {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress) -- EXCLUDE")
            }
            else {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress)")

                if (!$testMode) {
                    Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $true -AuditLogAgeLimit $AuditLogAgeLimit -AuditAdmin Update, MoveToDeletedItems, SoftDelete, HardDelete, SendAs, SendOnBehalf, Create, UpdateFolderPermission -AuditDelegate Update, SoftDelete, HardDelete, SendAs, Create, UpdateFolderPermissions, MoveToDeletedItems, SendOnBehalf -AuditOwner UpdateFolderPermission, MailboxLogin, Create, SoftDelete, HardDelete, Update, MoveToDeletedItems
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