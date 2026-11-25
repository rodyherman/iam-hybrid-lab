# Add-CustomDomain.ps1 - Ajout et verification de rodylabo.be dans Entra ID
# Rody - labo IAM RODy, phase 4

$domaine = "rodylabo.be"

Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
Connect-MgGraph -Scopes "Domain.ReadWrite.All"
Get-MgContext | Select-Object Account, Scopes

# Ajout du domaine + valeur TXT a mettre chez OVH (sous-domaine "@")
New-MgDomain -Id $domaine
(Get-MgDomainVerificationDnsRecord -DomainId $domaine | Where-Object RecordType -eq "Txt").AdditionalProperties.text

# A lancer une fois le TXT visible (Resolve-DnsName rodylabo.be -Type TXT)
Confirm-MgDomain -DomainId $domaine
Get-MgDomain | Select-Object Id, IsVerified, IsDefault

Disconnect-MgGraph | Out-Null
