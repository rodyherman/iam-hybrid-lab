# Generate-Users.ps1 - Genere users.csv avec 100 collaborateurs fictifs de RODy
$prenoms = "Lucas","Emma","Noah","Louise","Liam","Olivia","Arthur","Mila","Jules","Alice",
           "Adam","Lina","Louis","Juliette","Victor","Elena","Hugo","Zoe","Nathan","Clara"
$noms    = "Peeters","Janssens","Maes","Jacobs","Mertens","Willems","Claes","Goossens",
           "Wouters","Dubois","Lambert","Dupont","Martin","Simon","Laurent"
$services = [ordered]@{ Direction=5; RH=10; Finance=15; IT=15; Commercial=55 }
$domaine  = "rodylabo.be"

$liste = @(); $i = 0; $ceo = $null
foreach ($svc in $services.Keys) {
  $responsable = $null
  for ($n = 1; $n -le $services[$svc]; $n++) {
    $p   = $prenoms[$i % 20]
    $nom = $noms[($i + [math]::Floor($i / 20)) % 15]
    $sam = ("$p.$nom").ToLower()
    if ($n -eq 1) {
      $fonction = if ($svc -eq "Direction") { "Directeur general" } else { "Responsable $svc" }
      $manager  = if ($svc -eq "Direction") { "" } else { $ceo }
      $responsable = $sam
      if ($svc -eq "Direction") { $ceo = $sam }
    } else {
      $fonction = "Collaborateur $svc"
      $manager  = $responsable
    }
    $liste += [pscustomobject]@{
      Prenom=$p; Nom=$nom; Sam=$sam; UPN="$sam@$domaine"
      Service=$svc; Fonction=$fonction; Manager=$manager }
    $i++
  }
}
$liste | Export-Csv C:\Scripts\users.csv -NoTypeInformation -Encoding UTF8
"$($liste.Count) utilisateurs generes"