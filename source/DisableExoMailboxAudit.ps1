Function Disable-DefaultMailboxAuditLogSet {
    [cmdletbinding()]
    [Alias('ddma')]
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
    $logFile = "$($logDirectory)\disable_transcript_$($fileSuffix).log"

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

    if ($PSBoundParameters.count -eq 0) {
        Write-Output "You did not specify any paramaters. Terminating script."
        Stop-TxnLogging
        return $null
    }

    if ($testMode) {
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': TEST MODE ')
    }

    # Connect to O365 Shell
    if (!$skipConnect) {
        if ($adminCredential) {
            try {
                #open new Exchange Online Session
                Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': Login to Exchange Online... ')
                Connect-ExchangeOnline -Credential $adminCredential -ShowBanner:$false
            }
            catch {
                Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": There was an error connecting to Exchange Online. Terminating Script")
                Stop-TxnLogging
                return $null
            }
        }
        else {
            Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': The administrator credential is not provided. Use the -adminCredential parameter to specify the administrator login')
            Stop-TxnLogging
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
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Make sure to connect to Exchange Online first. Terminating Script")
        Stop-TxnLogging
        $ErrorActionPreference = $eap
        return $null
    }

    # Get target mailbox
    Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ': Retrieving Mailbox List... ')
    if ($ForceUpdate) {
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Force Update all mailbox is enabled")
        $mailboxes = @()
        $mailboxes += Get-Mailbox -ResultSize Unlimited | Select-Object PrimarySMTPAddress, RecipientTypeDetails
        if ($IncludeGroupMailbox) {
            $mailboxes += Get-Mailbox -GroupMailbox -ResultSize Unlimited | Select-Object PrimarySMTPAddress, RecipientTypeDetails
        }
    }
    else {
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Get all mailbox with audit enabled")
        $mailboxes = @()
        $mailboxes += Get-Mailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $true } | Select-Object PrimarySMTPAddress, RecipientTypeDetails
        if ($IncludeGroupMailbox) {
            $mailboxes += Get-Mailbox -GroupMailbox -ResultSize Unlimited -Filter { AuditEnabled -eq $true } | Select-Object PrimarySMTPAddress, RecipientTypeDetails
        }
    }

    $mailboxCount = ($mailboxes | Measure-Object).Count
    Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($mailboxCount) mailbox")
    if ($exclusionList) {
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Found $($exclusionList.count) from the Exclusion List")
    }

    $includedMailbox = 0
    if ($mailboxes) {

        $outputFile = "$($outputDirectory)\disable_result_$($fileSuffix).csv"
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Saving Mailbox List to $($outputFile)")
        "EmailAddress`tResult`tError" | Out-File $outputFile
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Disable Mailbox Auditing")

        foreach ($mailbox in ($mailboxes | Sort-Object PrimarySMTPAddress)) {
            if ($exclusionList -and $exclusionList -contains "$($mailbox.PrimarySMTPAddress)") {
                Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": [EXCLUDE] $($mailbox.PrimarySMTPAddress)")
            }
            else {
                try {
                    Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": $($mailbox.PrimarySMTPAddress)")

                    if (!$testMode) {
                        if ($mailbox.RecipientTypeDetails -eq 'GroupMailbox') {
                            Set-Mailbox $mailbox.PrimarySMTPAddress -GroupMailbox -AuditEnabled $false -AuditAdmin None -AuditOwner None -AuditDelegate None -Confirm:$false -Force -Erroraction STOP
                            Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": [SUCCESS] $($mailbox.PrimarySMTPAddress)")
                        }
                        else {
                            Set-Mailbox $mailbox.PrimarySMTPAddress -AuditEnabled $false -AuditAdmin None -AuditOwner None -AuditDelegate None -Confirm:$false -Force -Erroraction STOP
                            Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": [SUCCESS] $($mailbox.PrimarySMTPAddress)")
                        }
                    }
                    "$($mailbox.PrimarySMTPAddress)`tSuccess`t" | Out-File $outputFile -Append
                    $includedMailbox = $includedMailbox + 1
                }
                catch {
                    Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": [FAILED] $($mailbox.PrimarySMTPAddress)) | $($_.Exception.Message)")
                    "$($mailbox.PrimarySMTPAddress)`tFailed`t$($_.Exception.Message)" | Out-File $outputFile -Append
                    $includedMailbox = $includedMailbox + 1
                }

            }
        }
    }
    #Invoke Housekeeping---------------------------------------------------------------------------------
    #if ($enableHousekeeping)
    if ($removeOldFiles) {
        Write-Output ((get-date -Format "dd-MMM-yyyy hh:mm:ss tt") + ": Deleting log files older than $($removeOldFiles) days")
        Invoke-Housekeeping -folderPath $outputDirectory -daysToKeep $removeOldFiles
        Invoke-Housekeeping -folderPath $logDirectory -daysToKeep $removeOldFiles
    }
    #-----------------------------------------------------------------------------------------------

    Stop-TxnLogging
}