function Get-Conflict {

$SMM_Params = @{
        Subject    = "Conflict Check Report"
        From       = "from@from.com"
        To         = "to@to.com"
        Cc         = "cc@cc.com"
        SmtpServer = "smtp@server.com"
        Encoding   = 'UTF8'
        BodyAsHtml = $true
    }

    $Report = @()

    #collecting Data
    Get-ADGroupMember FU_XXXNN_XXX_E1_Teams_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E1T.txt
    Get-ADGroupMember FU_XXXNN_XXX_E3_Teams_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E3T.txt

    Get-ADGroupMember FU_XXXNN_XXX_E1_Stream_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E1S.txt
    Get-ADGroupMember FU_XXXNN_XXX_E3_Stream_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E3S.txt

    Get-ADGroupMember FU_XXXNN_XXX_E1_PowerAutomate_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E1PA.txt
    Get-ADGroupMember FU_XXXNN_XXX_E3_PowerAutomate_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E3PA.txt

    Get-ADGroupMember FU_XXXNN_XXX_E1_Forms_License | Select-Object -ExpandProperty SamAccountName | Out-File .\E1F.txt
    Get-ADGroupMember FU_XXXNN_XXX_E3_Forms_License_Plan2 | Select-Object -ExpandProperty SamAccountName | Out-File .\E3F.txt

    #Comparing
    $T = Compare-Object -ReferenceObject (Get-Content -Path ".\E1T.txt") -DifferenceObject (Get-Content -Path ".\E3T.txt") -ExcludeDifferent |
    Select-Object -ExpandProperty InputObject

    $S = Compare-Object -ReferenceObject (Get-Content -Path ".\E1S.txt") -DifferenceObject (Get-Content -Path ".\E3S.txt") -ExcludeDifferent |
    Select-Object -ExpandProperty InputObject

    $F = Compare-Object -ReferenceObject (Get-Content -Path ".\E1F.txt") -DifferenceObject (Get-Content -Path ".\E3F.txt") -ExcludeDifferent |
    Select-Object -ExpandProperty InputObject

    $PA = Compare-Object -ReferenceObject (Get-Content -Path ".\E1PA.txt") -DifferenceObject (Get-Content -Path ".\E3PA.txt") -ExcludeDifferent |
    Select-Object -ExpandProperty InputObject

    $Conflict = [PSCustomObject] @{
        T  = $T
        S  = $S
        F  = $F
        PA = $PA
    }

    #Creating the table for the final mail report
    foreach ($user in $Conflict) {

        $Data = [PSCustomObject]@{
            TU  = ""
            TM  = ""
            SU  = ""
            SM  = ""
            FU  = ""
            FM  = ""
            PAU = ""
            PAM = ""
        }

            $Data.TU = $1
            $Data.TM = Get-ADUser $1 | Select-Object -ExpandProperty UserPrincipalName
    
            $Data.SU = $2
            $Data.SM = Get-ADUser $2 | Select-Object -ExpandProperty UserPrincipalName

            $Data.FU = $3
            $Data.FM = Get-ADUser $3 | Select-Object -ExpandProperty UserPrincipalName

            $Data.PAU = $4
            $Data.PAM = Get-ADUser $4 | Select-Object -ExpandProperty UserPrincipalName

        $Report += $Data
    }
    
    foreach ($Entry in $Report) {

        $MTU = $Entry.TU
        $MTM = $Entry.TM
        $MSU = $Entry.SU
        $MSM = $Entry.SM
        $MFU = $Entry.FU
        $MFM = $Entry.FM
        $MPAU = $Entry.PAU
        $MPAM = $Entry.PAM

        $datarow = "
            </tr>
            <td>$($MTU)</td>
            <td>$($MTM)</td>
            <td>$($MSU)</td>
            <td>$($MSM)</td>
            <td>$($MFU)</td>
            <td>$($MFM)</td>
            <td>$($MPAU)</td>
            <td>$($MPAM)</td>
            </tr>
            "
        $tabledata += $datarow
    }

    $table = "<html>
            <style>
            {font-family: Arial; font-size: 12pt;}
            TABLE{border: 1px solid black; border-collapse: collapse; font-size:12pt;}
            TH{border: 1px solid black; background: #6AA9E2; padding: 5px; color: #000000;}
            TD{border: 1px solid black; padding: 5px; }
            </style>
            <h2>Plans Groups Conflic Check</h2>
            <br>
            <table>
            <col>
            <colgroup span=2></colgroup>
            <colgroup span=2></colgroup>
            <tr>
              <th colspan='2' scope='colgroup'>Teams</th>
              <th colspan='2' scope='colgroup'>Stream</th>
              <th colspan='2' scope='colgroup'>Forms</th>
              <th colspan='2' scope='colgroup'>PowerAutomate</th>
            </tr>
            <tr>
              <th scope='col'>UserName</th>
              <th scope='col'>Email</th>
              <th scope='col'>UserName</th>
              <th scope='col'>Email</th>
              <th scope='col'>UserName</th>
              <th scope='col'>Email</th>
              <th scope='col'>UserName</th>
              <th scope='col'>Email</th>
            </tr>
            $tabledata
            </table>
            "

    Send-MailMessage @SMM_Params -Body $table

}

Get-Conflict
