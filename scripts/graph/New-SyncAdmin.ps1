# New-SyncAdmin.ps1
# Crée le compte cloud dédié à Entra Cloud Sync, avec le seul rôle Hybrid Identity Administrator.
# Projet : labo IAM hybride RODy — Phase 4

$tenant = "rody.onmicrosoft.com"
$upn    = "admin-sync@$tenant"

# --- 1. Installer les modules nécessaires (une seule fois) ---
Install-Module Microsoft.Graph.Users, Microsoft.Graph.Identity.Governance -Scope CurrentUser

# --- 2. Se connecter avec les droits nécessaires ---
Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

# --- 3. Créer le compte avec un mot de passe temporaire aléatoire ---
$caracteres = (48..57) + (65..90) + (97..122) + (33, 35, 36, 37, 42, 43, 45, 61, 63, 64)
$mdp = -join ($caracteres | Get-Random -Count 20 | ForEach-Object { [char]$_ })

$user = New-MgUser -DisplayName "Admin Synchronisation (Cloud Sync)" `
  -UserPrincipalName $upn -MailNickname "admin-sync" -AccountEnabled -UsageLocation "BE" `
  -PasswordProfile @{ Password = $mdp; ForceChangePasswordNextSignIn = $true }

"Compte créé : $upn"
"Mot de passe temporaire : $mdp"

# --- 4. Attribuer le rôle Hybrid Identity Administrator ---
$role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Hybrid Identity Administrator'"
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $user.Id -RoleDefinitionId $role.Id -DirectoryScopeId "/"

# --- 5. Vérifier ---
Get-MgUser -UserId $upn | Select-Object DisplayName, UserPrincipalName, AccountEnabled
Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($user.Id)'" |
  Select-Object @{n = "Role"; e = { $role.DisplayName }}, DirectoryScopeId

# --- 6. Se déconnecter ---
Disconnect-MgGraph