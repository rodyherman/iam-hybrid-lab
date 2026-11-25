# New-SyncAdmin.ps1 - Compte cloud pour l'installation de l'agent Cloud Sync
# Role unique : Hybrid Identity Administrator (pas de Global Admin)
# Rody - labo IAM RODy, phase 4

$tenant = "rody.onmicrosoft.com"
$upn    = "admin-sync@$tenant"

Install-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.Governance -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

# Mot de passe temporaire, a changer a la premiere connexion
$car = (48..57) + (65..90) + (97..122) + (33,35,36,37,42,43,45,61,63,64)
$mdp = -join ($car | Get-Random -Count 20 | ForEach-Object { [char]$_ })

$user = New-MgUser -DisplayName "Admin Synchronisation (Cloud Sync)" `
  -UserPrincipalName $upn -MailNickname "admin-sync" -AccountEnabled -UsageLocation "BE" `
  -PasswordProfile @{ Password = $mdp; ForceChangePasswordNextSignIn = $true }
"Compte cree : $upn"
"Mot de passe temporaire : $mdp"

$role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Hybrid Identity Administrator'"
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $user.Id -RoleDefinitionId $role.Id -DirectoryScopeId "/"

# Controle (AccountEnabled n'est pas renvoye sans -Property)
Get-MgUser -UserId $upn -Property DisplayName, UserPrincipalName, AccountEnabled |
  Select-Object DisplayName, UserPrincipalName, AccountEnabled
Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($user.Id)'" |
  Select-Object @{n="Role";e={$role.DisplayName}}, DirectoryScopeId

Disconnect-MgGraph | Out-Null
