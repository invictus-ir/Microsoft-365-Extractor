function Get-Users {
<#
    .SYNOPSIS
    Retrieves the creation time and date of the last password change for all users.
    Script inspired by: https://github.com/tomwechsler/Microsoft_Graph/blob/main/Entra_ID/Create_time_last_password.ps1

    .DESCRIPTION
    Retrieves the creation time and date of the last password change for all users.

    .PARAMETER OutputDir
    OutputDir is the parameter specifying the output directory.
    Default: Output\Users

    .PARAMETER Encoding
    Encoding is the parameter specifying the encoding of the CSV output file.
    Default: UTF8

    .PARAMETER LogLevel
    Specifies the level of logging:
    None: No logging
    Minimal: Critical errors only
    Standard: Normal operational logging
    Default: Standard
    
    .EXAMPLE
    Get-Users
    Retrieves the creation time and date of the last password change for all users.

    .EXAMPLE
    Get-Users -Encoding utf32
    Retrieves the creation time and date of the last password change for all users and exports the output to a CSV file with UTF-32 encoding.
        
    .EXAMPLE
    Get-Users -OutputDir C:\Windows\Temp
    Retrieves the creation time and date of the last password change for all users and saves the output to the C:\Windows\Temp folder.	
#>
    [CmdletBinding()]
    param(
        [string]$OutputDir = "Output\Users",
        [string]$Encoding = "UTF8",
        [ValidateSet('None', 'Minimal', 'Standard')]
        [string]$LogLevel = 'Standard'
    )

    Set-LogLevel -Level ([LogLevel]::$LogLevel)
    $requiredScopes = @("User.Read.All")
    $graphAuth = Get-GraphAuthType -RequiredScopes $RequiredScopes


    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Force -Path $OutputDir > $null
    } 
    else {
        if (!(Test-Path -Path $OutputDir)) {
            Write-Error "[Error] Custom directory invalid: $OutputDir exiting script" -ErrorAction Stop
            Write-LogFile -Message "[Error] Custom directory invalid: $OutputDir exiting script" -Level Minimal
        }
    }    

    Write-LogFile -Message "=== Starting Users Collection ===" -Color "Cyan" -Level Minimal

    try {
        $selectobjects = "UserPrincipalName","DisplayName","Id","CompanyName","Department","JobTitle","City","Country","Identities","UserType","LastPasswordChangeDateTime","AccountEnabled","CreatedDateTime","CreationType","ExternalUserState","ExternalUserStateChangeDateTime","SignInActivity","OnPremisesSyncEnabled"
        $mgUsers = Get-MgUser -All -Select $selectobjects 

        $formattedUsers = $mgUsers | ForEach-Object {
            [PSCustomObject]@{
                UserPrincipalName = $_.UserPrincipalName
                DisplayName = $_.DisplayName
                Id = $_.Id
                Department = $_.Department
                JobTitle = $_.JobTitle
                AccountEnabled = $_.AccountEnabled
                CreatedDateTime = $_.CreatedDateTime
                LastPasswordChangeDateTime = $_.LastPasswordChangeDateTime
                UserType = $_.UserType
                OnPremisesSyncEnabled = $_.OnPremisesSyncEnabled
                Mail = $_.Mail
                LastSignInDateTime = $_.SignInActivity.LastSignInDateTime
                LastNonInteractiveSignInDateTime = $_.SignInActivity.LastNonInteractiveSignInDateTime
                IdentityProvider = ($_.Identities | Where-Object { $_.SignInType -eq "federated" }).Issuer
                City = $_.City
                Country = $_.Country
                UsageLocation = $_.UsageLocation
            }
        }

        $date = (Get-Date).AddDays(-7)
        $oneweekold = $mgUsers | Where-Object {
            $_.CreatedDateTime -gt $date
        }

        $date = (Get-Date).AddDays(-30)
        $onemonthold = $mgUsers | Where-Object {
            $_.CreatedDateTime -gt $date
        }

        $date = (Get-Date).AddDays(-90)
        $threemonthold = $mgUsers | Where-Object {
            $_.CreatedDateTime -gt $date
        }

        $date = (Get-Date).AddDays(-180)
        $sixmonthold = $mgUsers | Where-Object {
            $_.CreatedDateTime -gt $date
        }

        $date = (Get-Date).AddDays(-360)
        $OneYear = $mgUsers | Where-Object {
            $_.CreatedDateTime -gt $date
        }

        Get-MgUser | Get-Member > $null
        $date = Get-Date -Format "yyyyMMddHHmm"
        $filePath = "$OutputDir\$($date)-Users.csv"
        $formattedUsers  | Export-Csv -Path $filePath -NoTypeInformation -Encoding $Encoding

        $userSummary = [PSCustomObject]@{
            TotalUsers = $mgUsers.Count
            EnabledUsers = ($mgUsers | Where-Object { $_.AccountEnabled }).Count
            DisabledUsers = ($mgUsers | Where-Object { -not $_.AccountEnabled }).Count
            SyncedUsers = ($mgUsers | Where-Object { $_.OnPremisesSyncEnabled }).Count
            GuestUsers = ($mgUsers | Where-Object { $_.UserType -eq "Guest" }).Count
            LastSevenDays = $oneweekold.Count
            LastThirtyDays = $onemonthold.Count
            LastNinetyDays = $threemonthold.Count
            Onehundredeighty = $sixmonthold.Count
            OneYear = $OneYear.Count
        }

        Write-LogFile -Message "User Analysis Results:" -Color "Cyan" -Level Standard
        Write-LogFile -Message "Total Users: $($userSummary.TotalUsers)" -Level Standard
        Write-LogFile -Message "  - Enabled: $($userSummary.EnabledUsers)" -Level Standard
        Write-LogFile -Message "  - Disabled: $($userSummary.DisabledUsers)" -Level Standard
        Write-LogFile -Message "  - Synced from On-Premises: $($userSummary.SyncedUsers)" -Level Standard
        Write-LogFile -Message "  - Guest Users: $($userSummary.GuestUsers)" -Level Standard

        Write-LogFile -Message "`nRecent Account Creation:" -Color "Cyan" -Level Standard
        Write-LogFile -Message "  - Last 7 days: $($userSummary.LastSevenDays)" -Level Standard
        Write-LogFile -Message "  - Last 30 days: $($userSummary.LastThirtyDays)" -Level Standard
        Write-LogFile -Message "  - Last 90 days: $($userSummary.LastNinetyDays)" -Level Standard
        Write-LogFile -Message "  - Last 6 months: $($userSummary.Onehundredeighty)" -Level Standard
        Write-LogFile -Message "  - Last 1 year $($userSummary.OneYear)" -Level Standard

        Write-LogFile -Message "`nExported File:" -Color "Cyan" -Level Standard
        Write-LogFile -Message "  - File: $filePath" -Level Standard
    }
    catch {
        Write-logFile -Message "[ERROR] An error occurred: $($_.Exception.Message)" -Color "Red" -Level Minimal
        throw
    }    
}

Function Get-AdminUsers {
<#
    .SYNOPSIS
    Retrieves all Administrator directory roles.

    .DESCRIPTION
    Retrieves Administrator directory roles, including the identification of users associated with each specific role.

    .PARAMETER OutputDir
    OutputDir is the parameter specifying the output directory.
    Default: Output\Admins

    .PARAMETER Encoding
    Encoding is the parameter specifying the encoding of the CSV output file.
    Default: UTF8

    .PARAMETER LogLevel
    Specifies the level of logging:
    None: No logging
    Minimal: Critical errors only
    Standard: Normal operational logging
    Default: Standard
    
    .EXAMPLE
    Get-AdminUsers
    Retrieves Administrator directory roles, including the identification of users associated with each specific role.
    
    .EXAMPLE
    Get-AdminUsers -Encoding utf32
    Retrieves Administrator directory roles, including the identification of users associated with each specific role and exports the output to a CSV file with UTF-32 encoding.
        
    .EXAMPLE
    Get-AdminUsers -OutputDir C:\Windows\Temp
    Retrieves Administrator directory roles, including the identification of users associated with each specific role and saves the output to the C:\Windows\Temp folder.	
#>    

    [CmdletBinding()]
    param(
        [string]$outputDir = "Output\Admins",
        [string]$Encoding = "UTF8",
        [ValidateSet('None', 'Minimal', 'Standard')]
        [string]$LogLevel = 'Standard'
    )

    Set-LogLevel -Level ([LogLevel]::$LogLevel)
    $date = Get-Date -Format "yyyyMMddHHmm"

    Write-LogFile -Message "=== Starting Admin Users Collection ===" -Color "Cyan" -Level Minimal

    $requiredScopes = @("User.Read.All", "Directory.Read.All")
    $graphAuth = Get-GraphAuthType -RequiredScopes $RequiredScopes
        
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Force -Path $OutputDir > $null
    } 
    else {
        if (!(Test-Path -Path $OutputDir)) {
            Write-Error "[Error] Custom directory invalid: $OutputDir exiting script" -ErrorAction Stop
            Write-LogFile -Message "[Error] Custom directory invalid: $OutputDir exiting script" -Level Minimal
        }
    }    

    Write-LogFile -Message "[INFO] Analyzing administrator roles..." -Level Standard

    $rolesWithUsers = @()
    $rolesWithoutUsers = @()
    $exportedFiles = @()
    $totalAdminCount = 0

    try {
        $getRoles = Get-MgDirectoryRole -all
        foreach ($role in $getRoles) {
            $roleId = $role.Id
            $roleName = $role.DisplayName

            if ($roleName -like "*Admin*") {
                $areThereUsers = Get-MgDirectoryRoleMember -DirectoryRoleId $roleId

                if ($null -eq $areThereUsers) {
                    $rolesWithoutUsers += $roleName
                    continue
                }

                $results = @()
                $count = 0
                foreach ($user in $areThereUsers) {
                    $userid = $user.Id
                    if ($userid -eq ".") {
                        continue
                    }

                    $count++
                    try {
                        try {
                            $getUserName = Get-MgUser -Filter ("Id eq '$userid'") -ErrorAction Stop
                        } catch {
                            if ($_.Exception.Response.StatusCode -eq 429) {
                                Start-Sleep -Seconds 5
                                $getUserName = Get-MgUser -Filter ("Id eq '$userid'") -ErrorAction Stop
                            } else {
                                throw
                            }
                        }
                    
                        $userName = $getUserName.UserPrincipalName
                        $results += [PSCustomObject]@{
                            UserName = $userName
                            UserId = $userid
                            Role = $roleName
                            DisplayName = $getUserName.DisplayName
                            Department = $getUserName.Department
                            JobTitle = $getUserName.JobTitle
                            AccountEnabled = $getUserName.AccountEnabled
                            CreatedDateTime = $getUserName.CreatedDateTime
                        }
                    }
                    catch {}
                }

                if ($results.Count -gt 0) {
                    $totalAdminCount += $results.Count
                    $rolesWithUsers += "$roleName ($($results.Count) users)"
                    
                    $filePath = "$OutputDir\$($date)-$($roleName.Replace(' ','_')).csv"
                    $results | Export-Csv -Path $filePath -NoTypeInformation -Encoding $Encoding
                    $exportedFiles += $filePath
                }
                else {
                    $rolesWithoutUsers += $roleName
                }
            }
        }

        $outputDirMerged = "$OutputDir\Merged\"
        If (!(test-path $outputDirMerged)) {
            New-Item -ItemType Directory -Force -Path $outputDirMerged > $null
        }

        $mergedFile = "$outputDirMerged$($date)-All-Administrators.csv"
        Get-ChildItem $OutputDir -Filter "*Administrator.csv" | 
            Select-Object -ExpandProperty FullName | 
            Import-Csv | 
            Export-Csv $mergedFile -NoTypeInformation -Append

        Write-LogFile -Message "`nRoles with users:" -Color "Green" -Level Standard
        foreach ($role in $rolesWithUsers) {
            Write-LogFile -Message "  + $role" -Level Standard
        }

        Write-LogFile -Message "`nEmpty roles:" -Color "Yellow" -Level Standard
        foreach ($role in $rolesWithoutUsers) {
            Write-LogFile -Message "  - $role" -Level Standard
        }

        Write-LogFile -Message "`nSummary:" -Level Standard -Color "Cyan"
        Write-LogFile -Message "  Total admin roles: $($rolesWithUsers.Count + $rolesWithoutUsers.Count)" -Level Standard
        Write-LogFile -Message "  Roles with users: $($rolesWithUsers.Count)" -Level Standard
        Write-LogFile -Message "  Empty roles: $($rolesWithoutUsers.Count)" -Level Standard
        Write-LogFile -Message "  Total administrators: $totalAdminCount" -Level Standard

        Write-LogFile -Message "`nExported files:" -Level Standard -Color "Cyan"
        Write-LogFile -Message "  Individual role files: $OutputDir" -Level Standard
        Write-LogFile -Message "  Merged file: $mergedFile" -Level Standard
    }
    catch {
        Write-logFile -Message "[ERROR] An error occurred: $($_.Exception.Message)" -Color "Red" -Level Minimal
        throw
    }
}