# ------------------------------------------
# DOMAIN AND POLICY INFORMATION
# ------------------------------------------

# Returns domain information
Get-ADDomain

# Displays the hostname and operating systems of all domain controllers
Get-ADDomainController -Filter * | Select-Object Hostname, OperatingSystem

# Displays the fine-grained password policy
Get-ADFineGrainedPasswordPolicy -Filter *

# Displays the default password policy for the domain
Get-ADDefaultDomainPasswordPolicy

# Displays forest information
Get-ADForest

# Displays domain functional level and trust relationships
(Get-ADDomain).DomainMode
(Get-ADDomain).TrustedDomains


# ==========================================
# === USER MANAGEMENT
# ==========================================

# Define a reusable variable for demo
$User = 'john.appleseed'

# Displays a user account and all properties
Get-ADUser $User -Properties *

# Displays a user account with specific properties
Get-ADUser $User -Properties * |
Select-Object GivenName, Surname, EmailAddress, LastLogonDate

# Displays all users within a specific OU
$OU = 'OU=Arkham UK,DC=arkham,DC=local'
Get-ADUser -SearchBase $OU -Filter *

# Displays all user accounts which are disabled
Search-ADAccount -AccountDisabled

# Disables a user account
Disable-ADAccount -Identity $User -PassThru

# Enables a user account
Enable-ADAccount -Identity $User -PassThru

# Displays all locked accounts
Search-ADAccount -LockedOut

# Unlocks a user account
Unlock-ADAccount -Identity $User

# Requests the user to change password at the next logon
Set-ADUser -Identity $User -ChangePasswordAtLogon $true

# Displays all user accounts where passwords never expire
Get-ADUser -Filter * -Properties Name, PasswordNeverExpires |
Where-Object { $_.PasswordNeverExpires -eq $true } |
Select-Object DistinguishedName, Name, Enabled

# Sets the email address for each user in a specific OU
$OU = 'OU=Test,OU=Arkham UK,DC=arkham,DC=local'
Get-ADUser -Filter * -SearchBase $OU |
ForEach-Object {
    Set-ADUser -Identity $_ -EmailAddress "$($_.GivenName).$($_.Surname)@arkham.live"
}

# Moves a user to a different OU
$User = 'John Appleseed'
$OU1 = "CN=$User,OU=Arkham UK,DC=arkham,DC=local"
$OU2 = 'OU=Test,OU=Arkham UK,DC=arkham,DC=local'
Move-ADObject -Identity $OU1 -TargetPath $OU2 -PassThru

# Displays all users who must change their password at next logon
Get-ADUser -Filter { ChangePasswordAtLogon -eq $true } -Properties *

# Displays users whose passwords expired
Search-ADAccount -PasswordExpired

# Displays inactive users (no logon in last 90 days)
Search-ADAccount -UsersOnly -AccountInactive -TimeSpan 90.00:00:00 |
Select-Object Name, LastLogonDate


# ==========================================
# === GROUP MANAGEMENT
# ==========================================

# Displays all global security groups
Get-ADGroup -Filter * |
Where-Object { $_.GroupScope -eq 'Global' -and $_.GroupCategory -eq 'Security' }

# Displays members of a specific group
$Group = 'Security'
Get-ADGroupMember -Identity $Group | Select-Object Name, SamAccountName

# Adds user to a group
Add-ADGroupMember -Identity $Group -Members $User -PassThru

# Removes user from group
Remove-ADGroupMember -Identity $Group -Members $User -Confirm:$false

# Displays all groups a user belongs to
Get-ADPrincipalGroupMembership -Identity $User

# Creates a new group
New-ADGroup -Name "Arkham-Admins" -SamAccountName "ArkhamAdmins" `
-GroupScope Global -GroupCategory Security `
-Path "OU=Groups,OU=Arkham UK,DC=arkham,DC=local"

# Modifies group description
Set-ADGroup -Identity "Arkham-Admins" -Description "Arkham Admin Team"

# Deletes a group
Remove-ADGroup -Identity "Arkham-Admins" -Confirm:$false


# ==========================================
# === COMPUTER MANAGEMENT
# ==========================================

# Displays all computers in domain
Get-ADComputer -Filter * | Select-Object Name

# Displays all Windows 10 computers
Get-ADComputer -Filter { OperatingSystem -Like '*Windows 10*' } -Property * |
Select-Object Name, OperatingSystem

# Gets computer details
$Computer = 'ARKHAM-WS01'
Get-ADComputer -Identity $Computer -Properties * |
Select-Object Name, IPv4Address, LastLogonDate, Enabled

# Creates a new computer account
New-ADComputer -Name "ARKHAM-WS02" -Path "OU=Workstations,DC=arkham,DC=local"

# Moves a computer to a new OU
Move-ADObject -Identity "CN=ARKHAM-WS02,OU=Default,DC=arkham,DC=local"
-TargetPath "OU=Workstations,DC=arkham,DC=local"

# Removes a computer
Remove-ADComputer -Identity "ARKHAM-WS02" -Confirm:$false


# ==========================================
# === ORGANIZATIONAL UNITS (OU)
# ==========================================

# Displays all OUs
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName

# Creates a new OU
New-ADOrganizationalUnit -Name "Research" -Path "DC=arkham,DC=local"

# Renames an OU
Rename-ADObject -Identity "OU=Research,DC=arkham,DC=local" -NewName "R&D"

# Moves an OU under a different parent
Move-ADObject -Identity "OU=Test,DC=arkham,DC=local" `
-TargetPath "OU=Archive,DC=arkham,DC=local"

# Deletes an OU
Remove-ADOrganizationalUnit -Identity "OU=OldOU,DC=arkham,DC=local" -Confirm:$false


# ==========================================
# === DOMAIN & REPLICATION
# ==========================================

# Displays replication partners
Get-ADReplicationPartnerMetadata -Target (Get-ADDomainController).HostName -Scope Domain

# Displays replication failures
Get-ADReplicationFailure -Scope Domain -Target (Get-ADDomain).DNSRoot

# Displays FSMO role holders
Get-ADDomain | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator

# Moves FSMO roles to another DC
Move-ADDirectoryServerOperationMasterRole -Identity "ARKHAM-DC02" `
-OperationMasterRole PDCEmulator, RIDMaster


# ==========================================
# === REPORTS & EXPORTS
# ==========================================

# Exports all users to CSV
Get-ADUser -Filter * -Properties * |
Select-Object Name, SamAccountName, EmailAddress, Enabled |
Export-Csv "C:\Reports\ADUsers.csv" -NoTypeInformation

# Exports all computers to CSV
Get-ADComputer -Filter * -Properties * |
Select-Object Name, OperatingSystem, LastLogonDate |
Export-Csv "C:\Reports\ADComputers.csv" -NoTypeInformation

# Exports all groups and their members
Get-ADGroup -Filter * |
ForEach-Object {
    $g = $_
    Get-ADGroupMember -Identity $g.Name |
        Select-Object @{Name='Group';Expression={$g.Name}}, Name, SamAccountName
} | Export-Csv "C:\Reports\ADGroupMembers.csv" -NoTypeInformation