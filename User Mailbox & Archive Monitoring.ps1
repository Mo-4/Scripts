Function Get-MBXInfo {
    Connect-ExchangeOnline 
    
    #Both Plan variables specify the plans we have for the mailboxes, userinfo is where we store all the data we need for the users, Notification stores the data for the email from Line#54 if statement
    $Plan1 = 'ExchangeOnline'
    $Plan2 = 'ExchangeOnlineEnterprise'
    $userinfo = @()
    $Notification = ""
    
    #The Below Variables are for the Send-MailMessage
    $from = "from.mail.com"
    $to = "to.mail.com"
    $cc = "cc.mail.com"
    $Smtp = "smtp.address.com"

    ($userID = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | Select-Object WindowsLiveID, ArchiveStatus, MailboxPlan)

    foreach ($ID in $userID) {
        $mbxinfo = Get-MailboxStatistics $ID.WindowsLiveID | Select-Object DisplayName, SystemMessageSizeWarningQuota, @{N = 'SizeGB'; e = { [Math]::Round(($_.TotalItemSize.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1GB), 2) } };
        $Result = New-Object PSCustomObject
        $Result | Add-Member -MemberType NoteProperty -Name "Name" -Value $mbxinfo.DisplayName
        $Result | Add-Member -MemberType NoteProperty -Name "Email" -Value $ID.WindowsLiveID
        $Result | Add-Member -MemberType NoteProperty -Name "ArchiveStatus" -Value $ID.ArchiveStatus
        $Result | Add-Member -MemberType NoteProperty -Name "Size" -Value $mbxinfo.SizeGB
        $Result | Add-Member -MemberType NoteProperty -Name "Plan" -Value $ID.MailboxPlan
        $Result | Add-Member -MemberType NoteProperty -Name "ArchiveDate" -Value ""
        $Result | Add-Member -MemberType NoteProperty -Name "Action" -Value ""
        
        #this will run to get the archive creation date, and will only run if the user has the archive Enabled
        if ($ID.ArchiveStatus -eq 'Active') {
            $Date = Get-MailboxFolderStatistics $ID.WindowsLiveID -Archive | Where-Object { $_.Name -eq 'Top of Information Store' } | Select-Object Date
            ;
            $Result.ArchiveDate = $Date.Date
        }
        
        if ($mbxinfo.SizeGB -lt 40) {
            continue
        }
        elseif ($mbxinfo.SizeGB -ge 40 -and $mbxinfo.SizeGB -le 45 -and $ID.ArchiveStatus -eq 'None') {
            $Result.Action = "Enable Archive"
            <#$ID | Select-Object WindowsLiveID | Out-File -FilePath .\Users-ForEnableArchive.txt -Force -Encoding UTF8
            ;
            .\Enable-Archive.ps1
            ;
            $Notification = "<b>Note</b>: The script for enableing archives has been initiated, you should receive its report shortly."#>
        }
        elseif ($mbxinfo.SizeGB -ge 40 -and $mbxinfo.SizeGB -le 45 -and $ID.ArchiveStatus -eq 'Active') {
            continue
        }
        elseif ($mbxinfo.SizeGB -gt 45 -and $mbxinfo.SizeGB -le 50 -and $ID.MailboxPlan -eq $Plan1) {
            $Result.Action = "Enable License Plan 2"
        }
        elseif ($mbxinfo.SizeGB -gt 45 -and $mbxinfo.SizeGB -le 50 -and $ID.MailboxPlan -eq $Plan2) {
            continue
        }
        elseif ($mbxinfo.SizeGB -gt 50 -and $mbxinfo.SizeGB -lt 90 -and $ID.MailboxPlan -eq $Plan1) {
            $Result.Action = "<b>CRITICAL!</b> Enable License Plan 2"
        }
        elseif ($mbxinfo.SizeGB -gt 50 -and $mbxinfo.SizeGB -lt 90 -and $ID.MailboxPlan -eq $Plan2) {
            continue
        }
        elseif ($mbxinfo.SizeGB -ge 90) {
            $Result.Action = "check Retention policy"
        }
        
        #this will check if the user already has an archive older than 10 Days & the mailbox is still bigger than 40GBs & the user plan is still Plan1 (the lowest Plan)
        if ($ID.ArchiveStatus -eq 'Active' -and $mbxinfo.SizeGB -ge 40 -and $ID.MailboxPlan -eq $Plan1 -and $Date.Date -lt (Get-date).AddDays(-10)) {
            #The variables below are for the Send-MailMessage command, in case they needed modifications later on
            $subject1 = "Archiving Policy needs a check"
            $bodyuser = $ID.WindowsLiveID
            $body1 = "Archiving policy for the below user has not been triggered on the last 10 days, please check <br> $bodyuser"
    
            Send-MailMessage -From $from -To $to -Cc $cc -Subject $subject1 -SmtpServer $Smtp -Body $body1 -BodyAsHtml -Encoding UTF8
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
        $table = "Hurray! No Action Required."
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
    $count = $userID.Count
    $subject = 'Users MailboxesSize Report'
    $body = "Total users checked ($count) <br> $Notification <br> $table"
    
    Send-MailMessage -From $from -To $to -Cc $cc -Subject $subject -SmtpServer $Smtp -Body $body -BodyAsHtml -Encoding UTF8
}

Get-MBXInfo