# Dépannage — problèmes rencontrés et solutions

Ce document recense les problèmes **réellement rencontrés** pendant la construction du labo,
avec le message d'erreur, la cause identifiée, la solution appliquée et la leçon retenue.

## Vue d'ensemble

| # | Phase | Symptôme | Cause | Leçon |
|---|---|---|---|---|
| 1 | 1 | `The boot loader failed` au démarrage de la VM | Touche « Press any key » non captée | Envoyer la touche par WMI |
| 2 | 1 | Le ping échoue, mais Internet fonctionne | ICMP bloqué, TCP autorisé | Tester le port, pas seulement le ping |
| 3 | 1 | `Instance MSFT_NetIPAddress already exists` | L'adresse était déjà configurée | Lire le message avant de corriger |
| 4 | 1-3 | `Checkpoint-VM`/`Stop-VM` non reconnues | Commande lancée dans la VM au lieu de l'hôte | Vérifier `hostname` |
| 5 | 2 | `dcdiag` : test DFSREvent en échec | Avertissements enregistrés pendant la promotion | Vérifier SYSVOL/NETLOGON |
| 6 | 2 | Nombre de membres affiché `{}` | `.Count` sur un objet AD unique | Forcer un tableau avec `@()` |
| 7 | 2 | GPO « Not Configured » dans l'éditeur | Éditeur ouvert avant la commande / réglage absent | Vérifier avec `Get-GPRegistryValue` |
| 8 | 2 | `git` non reconnu après installation | PATH non rechargé | Rouvrir le terminal |
| 9 | 2 | Une capture n'était pas envoyée sur GitHub | Règle `.gitignore` trop large | `git check-ignore -v` |
| 10 | 2 | Faux positifs de `Select-String` sur des PNG | Recherche texte dans des fichiers binaires | Vérifier les images à l'œil |
| 11 | 3 | `Impossible d'allouer 4096 Mo de mémoire RAM` | PC à 16 Go, pas 32 | Mémoire dynamique Hyper-V |
| 12 | 3 | Pas d'écran « Name your device » sous Windows 11 | Étape absente de l'assistant | `Add-Computer -NewName` |
| 13 | 3 | Connexion refusée : droit Remote Desktop Services | La session améliorée passe par RDP | Session de base ou groupe RDP |
| 14 | 3 | `gpresult` : Access Denied, `auditpol` : privilège manquant | Terminal non élevé | Exécuter en administrateur |
| 15 | 3 | `Update-LapsADSchema` non reconnue | Windows Server 2022 non mis à jour (ISO 2021) | Patcher avant mise en service |
| 16 | 3 | Impossible de se connecter à la VM pendant les mises à jour | RDP indisponible pendant le redémarrage | Passer en session de base |
| 17 | 3 | `Expression manquante après l'opérateur unaire « + »` | Texte d'erreur collé dans le terminal | Copier uniquement les commandes |

---

## 1. La VM ne démarre pas sur l'ISO : « The boot loader failed »

**Phase** : 1 — création de DC01
**Capture** : [`01-04-erreur-boot-loader.png`](../screenshots/phase-01/01-04-erreur-boot-loader.png)

**Symptôme** — L'écran *Virtual Machine Boot Summary* affiche :
```
1. SCSI DVD (0,1)          The boot loader failed.
2. Network Adapter         A boot image was not found.
3. SCSI Disk (0,0)         The boot loader did not load an operating system.
```

**Cause** — Le programme d'installation de Windows sur l'ISO affiche *« Press any key to boot from CD or DVD »*
pendant quelques secondes seulement. La console Hyper-V ne captait pas le clavier à ce moment-là :
la touche n'était jamais reçue.

**Solution** — Envoyer la touche Entrée **directement au clavier virtuel de la VM**, par l'interface WMI d'Hyper-V,
depuis l'hôte :
```powershell
$vm = Get-VM -Name "DC01"
Start-VM -VM $vm
Start-Sleep -Seconds 2
$clavier = Get-CimInstance -Namespace "root\virtualization\v2" -ClassName "Msvm_Keyboard" |
  Where-Object { $_.SystemName -eq $vm.Id.ToString() }
1..20 | ForEach-Object {
  Invoke-CimMethod -InputObject $clavier -MethodName "TypeKey" -Arguments @{ keyCode = 13 } | Out-Null
  Start-Sleep -Milliseconds 500
}
```

**Leçon** — Hyper-V expose ses VM par WMI : on peut piloter une VM (clavier compris) par script,
ce qui ouvre la voie à l'automatisation des installations.

---

## 2. Le ping échoue, mais la connexion Internet fonctionne

**Phase** : 1 — configuration réseau de DC01

**Symptôme** — Depuis DC01, `ping 192.168.50.1` et `ping 1.1.1.1` renvoient `Request timed out`.
Pourtant :
```
Test-NetConnection 1.1.1.1 -Port 443
PingSucceeded    : False
TcpTestSucceeded : True
```

**Cause** — Le pare-feu Windows de l'hôte bloque les requêtes ICMP entrantes, et le NAT Hyper-V
laisse mal passer l'ICMP. Le trafic TCP/UDP, lui, passe normalement.

**Solution** — Aucune correction nécessaire : tous les services du labo (DNS, LDAP, Kerberos, HTTPS) utilisent TCP/UDP.
Pour autoriser le ping depuis le labo uniquement, une règle ciblée suffit :
```powershell
New-NetFirewallRule -DisplayName "LAB - Ping depuis le labo" -Direction Inbound -Protocol ICMPv4 `
  -IcmpType 8 -RemoteAddress 192.168.50.0/24 -Action Allow
```

**Leçon** — Le ping (ICMP, couche 3) teste la joignabilité d'une machine, pas d'un service.
Un ping qui échoue ne prouve pas une panne : on teste le **port du service** avec `Test-NetConnection -Port`.

---

## 3. « Instance MSFT_NetIPAddress already exists »

**Phase** : 1 — vérification de la passerelle sur l'hôte

**Symptôme** — `New-NetIPAddress -IPAddress 192.168.50.1 ...` renvoie
`Instance MSFT_NetIPAddress already exists` (Windows System Error 87).

**Cause** — L'adresse 192.168.50.1 était déjà configurée sur `vEthernet (LAB-NAT)`.
La commande n'était pas nécessaire.

**Solution** — Vérifier l'existant avant de reconfigurer :
```powershell
Get-NetIPAddress -IPAddress 192.168.50.1 | Select InterfaceAlias, IPAddress, PrefixLength
```

**Leçon** — Une erreur n'est pas toujours un problème : ici, elle confirmait que la configuration était déjà correcte.

---

## 4. Commande lancée sur la mauvaise machine

**Phases** : 1 à 3

**Symptômes** — Plusieurs variantes :
- `Checkpoint-VM : The term 'Checkpoint-VM' is not recognized` (lancée **dans** DC01) ;
- `Stop-VM`, `Set-VMMemory` non reconnues (lancées **dans** CLIENT01) ;
- `ipconfig /all` affichant `Nom de l'hôte : rody` au lieu de CLIENT01 (lancée **sur l'hôte**) ;
- résultats d'`auditpol` correspondant aux valeurs par défaut d'un DC (lancée **sur DC01** au lieu de CLIENT01).

**Cause** — Plusieurs fenêtres ouvertes en parallèle : l'hôte Hyper-V et trois VM.
Les commandes Hyper-V n'existent que sur l'hôte ; les vérifications d'un poste se font sur le poste.
Dans un terminal administrateur, l'invite `C:\WINDOWS\system32>` est identique partout.

**Solution** — Vérifier systématiquement la machine avant une série de commandes :
```powershell
hostname
```
Indice supplémentaire dans ce labo : l'hôte est en **français**, les VM en **anglais**.

**Leçon** — En administration, savoir **où** on exécute une commande est aussi important que la commande elle-même.

---

## 5. dcdiag : test DFSREvent en échec après la promotion

**Phase** : 2 — vérification de DC01

**Symptôme** — `dcdiag /q` signale un échec du test `DFSREvent` sur DC01.

**Cause** — Le test remonte les avertissements DFS-R des dernières 24 heures, enregistrés pendant
la promotion du contrôleur de domaine. Sur un DC neuf, c'est fréquent et sans gravité.

**Solution** — Vérifier que les partages du domaine sont bien en place :
```powershell
net share
```
`SYSVOL` et `NETLOGON` (*Logon server share*) sont présents : la réplication SYSVOL fonctionne.
Relancer `dcdiag` après 24 heures.

**Leçon** — Interpréter un résultat de diagnostic dans son contexte, et confirmer par un second test.

---

## 6. Le nombre de membres d'un groupe s'affiche `{}`

**Phase** : 2 — vérification des groupes AGDLP
**Capture** : [`02-10-groupes-agdlp.png`](../screenshots/phase-02/02-10-groupes-agdlp.png) (version corrigée)

**Symptôme** — Les groupes globaux affichent leur nombre de membres, mais les groupes `DL_Partage_*` affichent `{}`.

**Cause** — Un groupe DL n'a qu'**un seul membre** (son groupe GG). `Get-ADGroupMember` renvoie alors un objet unique,
et non une liste. Sur un objet Active Directory, `.Count` est interprété comme un attribut inexistant.

**Solution** — Forcer le résultat dans un tableau avec `@( )` :
```powershell
Get-ADGroup -Filter * -SearchBase $grp | ForEach-Object {
  [pscustomobject]@{ Groupe = $_.Name; Membres = @(Get-ADGroupMember $_).Count }
}
```

**Leçon** — En PowerShell, toujours encadrer avec `@()` un résultat qui peut contenir un seul élément avant de le compter.

---

## 7. La GPO affiche « Not Configured » après la commande PowerShell

**Phase** : 2 — GPO `SEC_Postes_Baseline`

**Symptôme** — Après `Set-GPRegistryValue` (désactivation de LLMNR), l'éditeur de GPO affiche
*Turn off multicast name resolution* : **Not Configured**.

**Cause** — L'éditeur de stratégie de groupe lit la GPO **à son ouverture** : ouvert avant la commande,
il n'affiche pas la modification. (Autres causes possibles vérifiées : commande non exécutée, mauvaise GPO ouverte.)

**Solution** — Vérifier le contenu réel de la GPO, puis rouvrir l'éditeur ou appliquer le réglage à la souris :
```powershell
Get-GPRegistryValue -Name "SEC_Postes_Baseline" -Key "HKLM\Software\Policies\Microsoft\Windows NT\DNSClient"
```

**Leçon** — PowerShell et la console donnent le même résultat, mais il faut savoir lequel fait foi et quand l'affichage est à jour.

---

## 8. `git` n'est pas reconnu après son installation

**Phase** : 2 — publication sur GitHub

**Symptôme** — `winget` indique que Git est déjà installé, mais `git --version` renvoie
`Le terme «git» n'est pas reconnu`.

**Cause** — PowerShell lit la variable `PATH` à son ouverture. La fenêtre avait été ouverte avant l'installation.

**Solution** — Fermer et rouvrir le terminal, ou recharger le PATH dans la session :
```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
```

**Leçon** — Après l'installation d'un outil en ligne de commande, rouvrir le terminal.

---

## 9. Une capture n'était pas envoyée sur GitHub

**Phase** : 2 — publication sur GitHub

**Symptôme** — Risque détecté avant le premier push : `02-12-strategie-mdp-domaine.png` aurait été ignorée.

**Cause** — La règle `*mdp*` du `.gitignore`, prévue pour bloquer des fichiers de mots de passe,
excluait **tout fichier dont le nom contient « mdp »**.

**Solution** — Remplacer la règle par des motifs précis (`*.secret`, `secrets/`, `motsdepasse*`), puis vérifier :
```powershell
git check-ignore -v screenshots\phase-02\02-12-strategie-mdp-domaine.png
```
(aucun résultat = le fichier n'est pas ignoré)

**Leçon** — Une règle d'exclusion trop large cache des fichiers sans prévenir. Toujours relire `git status` avant un commit.

---

## 10. Faux positifs lors de la recherche de secrets

**Phase** : 2 — contrôle avant publication

**Symptôme** — La recherche de mots sensibles signale deux captures PNG :
```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern "password|mot de passe|mdp|secret" -List
```

**Cause** — `Select-String` lit les octets bruts des images : certaines séquences ressemblent par hasard aux mots recherchés.

**Solution** — Contrôler les images visuellement. Les scripts signalés (`Import-Users.ps1`) contiennent le mot
« mot de passe » mais **demandent** le mot de passe (`Read-Host -AsSecureString`) sans jamais le stocker.

**Leçon** — Un outil de recherche texte n'est fiable que sur du texte. Les captures se vérifient à l'œil.

---

## 11. « Impossible d'allouer 4096 Mo de mémoire RAM »

**Phase** : 3 — démarrage de SYNC01

**Symptôme** —
```
Start-VM : Échec du démarrage de 'SYNC01'.
Impossible d'allouer 4096Mo de mémoire RAM: Ressources système insuffisantes (0x800705AA).
```
suivi de nombreuses erreurs `Invoke-CimMethod : ... la valeur Null`.

**Cause** — L'hôte dispose de **16 Go** de RAM (et non 32 comme prévu initialement) :
seuls 3,7 Go étaient libres avec DC01 démarré. Les erreurs suivantes n'étaient que la conséquence
du premier échec (VM non démarrée, donc pas de clavier virtuel).

**Solution** — Passer les VM en **mémoire dynamique** et démarrer uniquement les VM nécessaires :
```powershell
Set-VMMemory -VMName "DC01"   -DynamicMemoryEnabled $true -StartupBytes 2GB -MinimumBytes 1536MB -MaximumBytes 4GB
Set-VMMemory -VMName "SYNC01" -DynamicMemoryEnabled $true -StartupBytes 2GB -MinimumBytes 1GB    -MaximumBytes 3GB
```
CLIENT01 garde 4 Go fixes pendant l'installation (exigence de Windows 11), puis passe en dynamique (2 à 4 Go).

**Leçon** — Toujours lire la **première** erreur : les suivantes en découlent souvent.
Dimensionner un labo, c'est aussi une compétence d'administration.

---

## 12. Windows 11 ne propose pas de nommer l'ordinateur

**Phase** : 3 — installation de CLIENT01

**Symptôme** — L'assistant d'installation saute l'écran *Name your device* : le poste reçoit un nom automatique.

**Solution** — Renommer au moment de la jonction au domaine, en une seule opération :
```powershell
Add-Computer -DomainName "ad.rodylabo.be" -NewName "CLIENT01" -Credential "LABO\Administrator" -Restart
```
À noter : pour créer un compte local sans compte Microsoft, choisir *Sign-in options → Domain join instead*.

**Leçon** — `Add-Computer -NewName` renomme et joint au domaine avec un seul redémarrage.

---

## 13. « To sign in remotely, you need the right to sign in through Remote Desktop Services »

**Phase** : 3 — première connexion d'Arthur Martin sur CLIENT01

**Cause** — La **session améliorée** d'Hyper-V repose sur le protocole RDP. Seuls les administrateurs et le groupe local
*Remote Desktop Users* ont le droit de se connecter par RDP. Le message confirme au passage que la jonction au domaine a réussi.

**Solutions** —
- Passer en **session de base** (*Affichage → Session améliorée* décoché) : connexion console, sans RDP ;
- ou, pour le labo uniquement, autoriser les utilisateurs du domaine :
```powershell
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "LABO\Domain Users"
```

**Leçon** — En entreprise, le droit RDP se donne à un groupe restreint (support), et de préférence par GPO.
Accorder RDP à tous élargit la surface d'attaque.

---

## 14. `gpresult` : Access Denied — `auditpol` : privilège manquant

**Phase** : 3 — vérification de la GPO sur CLIENT01

**Symptôme** —
```
gpresult /r /scope computer      → ERROR: Access Denied.
auditpol /get /subcategory:...   → Error 0x00000522: A required privilege is not held by the client.
```

**Cause** — Terminal ouvert avec le compte d'Arthur, utilisateur standard. La lecture de la configuration de sécurité
de l'ordinateur est réservée aux administrateurs.

**Solution** — Ouvrir *Terminal (Admin)* avec `LABO\Administrator`. La lecture de la clé de registre, elle,
était possible et confirmait déjà l'application de la GPO (`EnableMulticast = 0`).

**Leçon** — C'est le comportement attendu : un utilisateur ne doit ni voir ni modifier la sécurité de son poste.
Illustration concrète de la séparation des comptes utilisateur et administrateur.

---

## 15. `Update-LapsADSchema` n'est pas reconnue

**Phase** : 3 — mise en place de Windows LAPS

**Symptôme** — `Update-LapsADSchema : The term 'Update-LapsADSchema' is not recognized`.

**Cause** — L'ISO d'évaluation de Windows Server 2022 date de 2021 (build 20348.169).
**Windows LAPS** n'a été intégré qu'avec la mise à jour cumulative d'avril 2023 (build 20348.1668 minimum).

**Diagnostic** —
```powershell
$v = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
"Build : $($v.CurrentBuild).$($v.UBR)"
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 HotFixID, InstalledOn
```

**Solution** — Point de contrôle, puis Windows Update sur DC01 et SYNC01. Plusieurs passages sont nécessaires :
Windows installe d'abord les mises à jour de la pile de maintenance (le « programme qui installe les mises à jour »),
puis la mise à jour cumulative.

**Leçon** — Un serveur installé depuis un ancien média doit être **mis à jour avant sa mise en service**.
Un contrôleur de domaine non patché depuis 2021 expose des dizaines de vulnérabilités connues.

---

## 16. Impossible de se connecter à la VM pendant les mises à jour

**Phase** : 3

**Symptôme** — *« Impossible de se connecter à l'ordinateur virtuel. Réessayez de vous connecter. »*
alors que la VM est à l'état *Exécution*.

**Cause** — La session améliorée dépend du service RDP de la VM, arrêté pendant l'installation des mises à jour et le redémarrage.

**Solution** — *Affichage → Session améliorée* décoché : la session de base affiche l'écran
*Working on updates*. Ne jamais forcer l'arrêt d'une VM pendant une mise à jour.

---

## 17. « Expression manquante après l'opérateur unaire « + » »

**Phase** : 3

**Cause** — Le texte d'une **erreur précédente** (lignes commençant par `+`, `~~~~`, `CategoryInfo`) a été collé
dans le terminal à la place des commandes. PowerShell tente de l'exécuter.

**Solution** — Copier uniquement les blocs de commandes, une commande à la fois en cas de doute.

**Leçon** — Distinguer ce que l'on exécute de ce que le système affiche.
