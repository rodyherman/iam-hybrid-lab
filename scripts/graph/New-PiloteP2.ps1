# New-PiloteP2.ps1 - Groupe pilote GRP_Pilote_EntraP2 + licence Entra ID P2 par groupe
# 25 licences d'essai : mon compte admin + 24 employes (les 5 responsables inclus)
# Rody - labo IAM RODy, phase 5

Install-Module Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "LicenseAssignment.ReadWrite.All", "Organization.Read.All"

$domaine = "rodylabo.be"
$pilote = @(
  "lucas.peeters", "emma.janssens", "noah.maes", "louise.jacobs",                      # Direction
  "olivia.willems", "arthur.claes", "mila.goossens", "jules.wouters", "alice.dubois",  # RH
  "elena.peeters", "arthur.martin", "hugo.janssens", "zoe.maes", "nathan.jacobs",      # Finance
  "adam.janssens", "lina.maes", "louis.jacobs", "juliette.mertens", "victor.willems",  # IT
  "olivia.maes", "arthur.jacobs", "mila.mertens", "jules.willems", "alice.claes"       # Commercial
) | ForEach-Object { "$_@$domaine" }

$membres = $pilote + (Get-MgContext).Account
"Membres prevus : $($membres.Count)"

# Pas de licence possible sans UsageLocation (vide sur les comptes synchronises)
foreach ($upn in $membres) { Update-MgUser -UserId $upn -UsageLocation "BE" }

# Groupe de securite cloud (pas dans l'AD : l'OU Groupes est synchronisee)
$nom = "GRP_Pilote_EntraP2"
$groupe = Get-MgGroup -Filter "displayName eq '$nom'"
if (-not $groupe) {
  $groupe = New-MgGroup -DisplayName $nom -MailNickname $nom -MailEnabled:$false -SecurityEnabled `
    -Description "Pilote Entra ID P2 : MFA, acces conditionnel, PIM"
}

$deja = (Get-MgGroupMember -GroupId $groupe.Id -All).Id
foreach ($upn in $membres) {
  $u = Get-MgUser -UserId $upn
  if ($deja -notcontains $u.Id) { New-MgGroupMember -GroupId $groupe.Id -DirectoryObjectId $u.Id }
}

$sku = Get-MgSubscribedSku | Where-Object SkuPartNumber -eq "AAD_PREMIUM_P2"
Set-MgGroupLicense -GroupId $groupe.Id -AddLicenses @(@{ SkuId = $sku.SkuId }) -RemoveLicenses @()

# Controle apres quelques minutes (attendu : 25 / 25)
"Membres du groupe : " + (Get-MgGroupMember -GroupId $groupe.Id -All).Count
(Get-MgGroup -GroupId $groupe.Id -Property AssignedLicenses).AssignedLicenses | Format-Table SkuId
Get-MgSubscribedSku | Where-Object SkuPartNumber -eq "AAD_PREMIUM_P2" |
  Format-Table SkuPartNumber, @{n="Total";e={$_.PrepaidUnits.Enabled}}, ConsumedUnits

Disconnect-MgGraph | Out-Null
