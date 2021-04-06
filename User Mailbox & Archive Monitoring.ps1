Function Get-MBXInfo {
    ($Connect = #cloud server)

    #Both Plan variables specify the plans we have for the mailboxes, userinfo is where we store all the data we need for the users, Notification stores the data for the email from if statement
    $Plan1 = 'Plan1'
    $Plan2 = 'Plan2'
    $userinfo = @()
    $Notification = ""
    $count = 0

    #The Below Variables are for the Send-MailMessage
    $SMM_Params = @{
        From       = "from"
        To         = "to"
        Cc         = "cc"
        SmtpServer = "smtpserver"
        Encoding   = 'UTF8'
        BodyAsHtml = $true
    }

    $userID = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | Select-Object WindowsLiveID, ArchiveStatus, MailboxPlan, DisplayName

    foreach ($ID in $userID) {

        $count++

        try {
            $mbxinfo = Get-MailboxStatistics $ID.WindowsLiveID | 
            Select-Object @{N = 'SizeGB'; e = { [Math]::Round(($_.TotalItemSize.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1GB), 1) } };    
        }
        catch {
            $Result.Action = 'User check failed'
            Disconnect-ExchangeOnline -Confirm:$false
            $Connect
            Start-Sleep 30
            continue
        }

        $Result = [PSCustomObject]@{
            Name          = $ID.DisplayName
            Email         = $ID.WindowsLiveID
            ArchiveStatus = $ID.ArchiveStatus
            Plan          = $ID.MailboxPlan
            Size          = $mbxinfo.SizeGB
            ArchiveDate   = ""
            Action        = ""
        }

        try {
            if ($ID.ArchiveStatus -eq 'Active') {
                $Date = Get-MailboxFolderStatistics $ID.WindowsLiveID -Archive | Where-Object { $_.Name -eq 'Top of Information Store' } | Select-Object Date
                ;
                $Result.ArchiveDate = $Date.Date
            }
        }
        catch {
                $Result.Action = 'User check failed'
                Disconnect-ExchangeOnline -Confirm:$false
                $Connect
                Start-Sleep 30
                continue
        }
        
        if ($mbxinfo.SizeGB -lt 40) {
            continue
        }
        elseif ([Int]$mbxinfo.SizeGB -in 40..45 -and $ID.ArchiveStatus -eq 'None') {
            $Result.Action = "Enable Archive"
            <#$ID | Select-Object WindowsLiveID | Out-File -FilePath .\Users-ForEnableArchive.txt -Force -Encoding UTF8
            ;
            .\Enable-Archive.ps1
            ;
            $Notification = "<b>Note</b>: The script for enableing archives has been initiated, you should receive its report shortly."#>
        }
        elseif ([Int]$mbxinfo.SizeGB -in 40..45 -and $ID.ArchiveStatus -eq 'Active') {
            continue
        }
        elseif ([Int]$mbxinfo.SizeGB -in 45..50 -and $ID.MailboxPlan -eq $Plan1) {
            $Result.Action = "Enable License Plan 2"
        }
        elseif ([Int]$mbxinfo.SizeGB -in 45..50 -and $ID.MailboxPlan -eq $Plan2) {
            continue
        }
        elseif ([Int]$mbxinfo.SizeGB -in 50..90 -and $ID.MailboxPlan -eq $Plan1) {
            $Result.Action = "<b>CRITICAL!</b> Enable License Plan 2"
        }
        elseif ([Int]$mbxinfo.SizeGB -in 50..90 -and $ID.MailboxPlan -eq $Plan2) {
            continue
        }
        elseif ($mbxinfo.SizeGB -ge 90) {
            $Result.Action = "check Retention policy"
        }

        if ($ID.ArchiveStatus -eq 'Active' -and
            $mbxinfo.SizeGB -ge 40 -and
            $ID.MailboxPlan -eq $Plan1 -and
            $Date.Date -lt (Get-date).AddDays(-10)) {

            #The variables below are for the Send-MailMessage command, in case they needed modifications later on
            $subject1 = "Archiving Policy needs a check"
            $bodyuser = $ID.WindowsLiveID
            $body1 = "Archiving policy for the below user has not been triggered on the last 10 days, please check <br> $bodyuser"
    
            Send-MailMessage @SMM_Params -Subject $subject1 -Body $body1
        }

        $userinfo += $Result
    }

    foreach ($Entry in $userinfo) {
        $Name = $Entry.Name
        $Email = $Entry.Email
        $Size = $Entry.Size
        $Todo = $Entry.Action
            
        $datarow = "
            </tr>
            <td>$Name</td>
            <td>$Email</td>
            <td>$Size GB</td>
            <td>$Todo</td>
            </tr>
            "
        $tabledata += $datarow
    }    
    
    if ($userinfo.count -eq 0) {
        $table = "Hurray! No Action Required. <br> Total users checked ($count)"
    }
    else {
        $table = "<html>
        <style>
        {font-family: Arial; font-size: 12pt;}
        TABLE{border: 1px solid black; border-collapse: collapse; font-size:12pt;}
        TH{border: 1px solid black; background: #6AA9E2; padding: 5px; color: #000000;}
        TD{border: 1px solid black; padding: 5px; }
        </style>
        <h2>Users Mailboxes Report</h2>
        <body> Total users checked ($count) <br> $Notification <br> $table </body>
        <br>
        <table>
        <tr>
        <th>DisplayName</th>
        <th>Email</th>
        <th>Size</th>
        <th>Action</th>
        </tr>
        $tabledata
        </table>
        <tr>
        "
    }
    
    #The variables below are for the Send-MailMessage command, in case they needed modifications later on
    $subject = 'Users MailboxesSize Report'
    
    Send-MailMessage  @SMM_Params -Subject $subject -Body $table

    Disconnect-ExchangeOnline -Confirm:$false
}

Get-MBXInfo
