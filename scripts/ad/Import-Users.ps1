# Import-Users.ps1 - Cree les comptes AD a partir de users.csv
Import-Module ActiveDirectory
$base  = "OU=Utilisateurs,OU=LABO,DC=ad,DC=rodylabo,DC=be"
$mdp   = Read-Host "Mot de passe initial des comptes" -AsSecureString
$users = Import-Csv C:\Scripts\users.csv

foreach ($u in $users) {
  New-ADUser -Name "$($u.Prenom) $($u.Nom)" -DisplayName "$($u.Prenom) $($u.Nom)" `
    -GivenName $u.Prenom -Surname $u.Nom -SamAccountName $u.Sam `
    -UserPrincipalName $u.UPN -EmailAddress $u.UPN `
    -Department $u.Service -Title $u.Fonction -Company "RODy" `
    -Path "OU=$($u.Service),$base" -AccountPassword $mdp -Enabled $true
}
# Deuxieme passage : les managers doivent exister avant d'etre references
foreach ($u in $users | Where-Object { $_.Manager }) {
  Set-ADUser -Identity $u.Sam -Manager $u.Manager
}
"Comptes crees : $((Get-ADUser -Filter * -SearchBase $base).Count)"