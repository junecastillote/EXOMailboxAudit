Function Disable-MailboxAuditLog {
    [cmdletbinding()]
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
			
        #path to the log directory (eg. c:\scripts\logs)
        [Parameter()]
        [string]$LogDirectory = (($env:temp) + "\ExoMailboxAudit\Logs"),

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

    # $scriptInfo = Get-Module EXOMailboxAudit

    #Set Paths-------------------------------------------------------------------------------------------
    $Today = Get-Date
    [string]$fileSuffix = '{0:dd-MMM-yyyy_hh-mm_tt}' -f $Today
    $logFile = "$($logDirectory)\Disable_Log_$($fileSuffix).txt"

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
            return $null
        }
    }

    # Check if EXO Session works
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'STOP'
    try {
        $null = Get-OrganizationConfig
        # $tenantName = ($orgData).DisplayName
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
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Get all mailbox with audit enabled")
        $mailboxes = @()
        $mailboxes += Get-Mailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $true } | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        if ($IncludeGroupMailbox) {
            $mailboxes += Get-Mailbox -GroupMailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $true } | Select-Object PrimarySMTPAddress,RecipientTypeDetails
        }
    }

    $mailboxCount = ($mailboxes | Measure-Object).Count
    Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($mailboxCount) mailbox")
    if ($exclusionList) {
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($exclusionList.count) from the Exclusion List")
    }

    $includedMailbox = 0
    if ($mailboxes) {

        $outputFile = "$($outputDirectory)\disable_output_$($fileSuffix).txt"
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Saving Mailbox List to $($outputFile)")
        Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Disable Mailbox Auditing")

        foreach ($mailbox in $mailboxes) {
            if ($exclusionList -and $exclusionList -contains "$($mailbox.PrimarySMTPAddress)") {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress) -- EXCLUDE")
            }
            else {
                Write-Verbose ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ":          -->> $($mailbox.PrimarySMTPAddress)")

                if (!$testMode) {
                    if ($mailbox.RecipientTypeDetails -eq 'GroupMailbox') {
                        Set-Mailbox $mailbox.PrimarySMTPAddress -GroupMailbox -AuditEnabled $false -AuditAdmin None -AuditOwner None -AuditDelegate None
                    }
                    else {
                        Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $false -AuditAdmin None -AuditOwner None -AuditDelegate None
                    }
                }
                $mailbox.PrimarySMTPAddress | Out-File $outputFile -Append
                $includedMailbox = $includedMailbox + 1
            }
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