# New-BreakGlass.ps1 - Comptes d'urgence bg-admin01 / bg-admin02
# Cloud uniquement, Global Admin permanent, exclus de toutes les regles CA
# Les mots de passe s'affichent une seule fois : a noter hors ligne
# Rody - labo IAM RODy, phase 5

Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "RoleManagement.ReadWrite.Directory"

function New-MotDePasse([int]$longueur = 32) {
  # sans 0/O, 1/l/I pour pouvoir le recopier sur papier
  $jeu = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#$%*+-=?@'
  $octets = New-Object byte[] $longueur
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($octets)
  -join ($octets | ForEach-Object { $jeu[$_ % $jeu.Length] })
}

$tenant  = "rody.onmicrosoft.com"
$comptes = @()
foreach ($n in "01", "02") {
  $mdp = New-MotDePasse
  $comptes += New-MgUser -DisplayName "Compte d'urgence $n" `
    -UserPrincipalName "bg-admin$n@$tenant" -MailNickname "bg-admin$n" `
    -AccountEnabled -UsageLocation "BE" -PasswordPolicies "DisablePasswordExpiration" `
    -PasswordProfile @{ Password = $mdp; ForceChangePasswordNextSignIn = $false }
  Write-Host "bg-admin$n@$tenant  ->  $mdp" -ForegroundColor Yellow
}
Remove-Variable mdp
Write-Host "Noter les mots de passe, puis Clear-Host. Pas de capture de cet ecran !" -ForegroundColor Red

# Global Admin permanent : pas de PIM, rien a activer le jour ou on en a besoin
$roleGA = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'"
foreach ($u in $comptes) {
  New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $u.Id -RoleDefinitionId $roleGA.Id -DirectoryScopeId "/" | Out-Null
}

# Groupe d'exclusion CA. IsAssignableToRole = seul un Global Admin / Privileged Role Admin
# peut changer ses membres
$groupe = New-MgGroup -DisplayName "GRP_Exclusion_CA_BreakGlass" -MailNickname "GRP_Exclusion_CA_BreakGlass" `
  -MailEnabled:$false -SecurityEnabled -IsAssignableToRole:$true `
  -Description "Comptes d'urgence exclus de toutes les regles d'acces conditionnel"
foreach ($u in $comptes) { New-MgGroupMember -GroupId $groupe.Id -DirectoryObjectId $u.Id }

# Controle (aucun mot de passe affiche ici)
Get-MgUser -Filter "startswith(userPrincipalName,'bg-admin')" -Property DisplayName, UserPrincipalName, AccountEnabled, PasswordPolicies |
  Format-Table DisplayName, UserPrincipalName, AccountEnabled, PasswordPolicies
foreach ($u in $comptes) {
  Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($u.Id)'" |
    Format-Table @{n="Compte";e={$u.UserPrincipalName}}, @{n="Role";e={$roleGA.DisplayName}}, DirectoryScopeId
}
Get-MgGroupMember -GroupId $groupe.Id | ForEach-Object { $_.AdditionalProperties.userPrincipalName }

Disconnect-MgGraph | Out-Null
