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
| 18 | 3 | Tous les paramètres LAPS sur « Enabled » | Activation sans comprendre chaque valeur | N'activer que ce qui est compris |
| 19 | 3 | LAPS, événement 10067 : compte désactivé | Administrator intégré désactivé sous Windows 11 | Activer le compte géré |
| 20 | 3 | LAPS, événement 10108 : attribut de schéma manquant | Client LAPS plus récent que le schéma | `Update-LapsADSchema` depuis le client |
| 21 | 3 | Le groupe Tier 2 n'est pas ajouté aux administrateurs locaux | Faute de frappe dans une préférence de GPO | Sélectionner les objets via le SID |
| 22 | 4 | OVH refuse un enregistrement TXT sans sous-domaine | Le champ ne peut pas rester vide | `@` désigne la racine du domaine |
| 23 | 4 | `Invalid value specified for property 'userPrincipalName'` | Variable `$upn` vide (ligne non exécutée) | Exécuter les variables avant les commandes |
| 24 | 4 | `AccountEnabled` affiché vide | Graph ne renvoie que les propriétés par défaut | Demander les propriétés avec `-Property` |
| 25 | 4 | `Start-VM` : « Vous n'avez pas l'autorisation » | Terminal VS Code non élevé | Terminal administrateur ou groupe Administrateurs Hyper-V |
| 26 | 4 | Copier-coller impossible dans SYNC01 | Session Hyper-V de base | Session améliorée, « Taper le texte » ou PowerShell Direct |
| 27 | 4 | PowerShell Direct : « informations d'identification non valides » | Compte `adm-t0-rody` désactivé | Lire `Enabled` et `BadLogonCount` avant de chercher ailleurs |
| 28 | 4 | Cloud Sync : `Connector registration failed` | .NET sans TLS fort (`SchUseStrongCrypto` absent) | Forcer TLS 1.2 pour .NET |
| 29 | 4 | `Restart-Computer` refusé : autres utilisateurs connectés | Session ouverte sur la VM | `-Force` ou `Restart-VM` depuis l'hôte |
| 30 | 4 | `Unable to find domain controller` | Identifiants cloud (admin-sync) repris par l'assistant | Saisir un compte du domaine |
| 31 | 4 | `Get-MgGroup` non reconnue | Module `Microsoft.Graph.Groups` non installé | Le SDK Graph est découpé en modules |
| 32 | 4 | Test à la demande : compte admin « in scope » | Le test importe l'objet par son DN | Vérifier un contrôle sur le résultat réel |

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

---

## 18. Tous les paramètres LAPS activés dans la GPO

**Phase** : 3 — GPO LAPS

**Symptôme** — Les 9 paramètres du dossier *Administrative Templates → System → LAPS* étaient sur **Enabled**.

**Risque** — Un paramètre activé avec une valeur vide modifie le comportement de LAPS. En particulier,
*Name of administrator account to manage* activé sans nom empêche LAPS de savoir quel compte gérer.

**Solution** — Ne garder que les paramètres utiles :

| Paramètre | État |
|---|---|
| Configure password backup directory (Active Directory) | Enabled |
| Password Settings (15 caractères, 30 jours, complexité maximale) | Enabled |
| Enable password encryption | Enabled |
| Do not allow password expiration time longer than required by policy | Enabled |
| Post-authentication actions | Enabled |
| DSRM, historique chiffré, déchiffreurs autorisés, nom du compte géré | Not configured |

**Leçon** — « Enabled » n'est pas synonyme de « plus sécurisé » : chaque paramètre doit être compris avant d'être activé.

---

## 19. LAPS — événement 10067 : « The configured local account is currently disabled »

**Phase** : 3 — LAPS sur CLIENT01
**Capture** : [`03-13-laps-journal-client01.png`](../screenshots/phase-03/03-13-laps-journal-client01.png)

**Cause** — Sans nom de compte configuré, LAPS gère le compte **Administrator intégré** (RID 500, `0x1F4`),
**désactivé par défaut** sous Windows 11. Un mot de passe sur un compte désactivé ne sert à rien.

**Solution** — Sur CLIENT01 :
```powershell
Enable-LocalUser -Name "Administrator"
Invoke-LapsPolicyProcessing
```
Résultat : événement **10004** *LAPS policy processing succeeded*, et mot de passe lisible depuis DC01 :
```powershell
Get-LapsADPassword -Identity CLIENT01      # Source : EncryptedPassword — AuthorizedDecryptor : LABO\Domain Admins
```

---

## 20. LAPS — événement 10108 : attribut `msLAPSCurrentPasswordVersion` absent du schéma

**Phase** : 3 — LAPS sur CLIENT01

**Cause** — Windows 11 26H2 embarque une version de LAPS plus récente que celle de Windows Server 2022.
Le schéma étendu depuis DC01 ne contenait pas ce nouvel attribut (utilisé pour détecter les restaurations d'image).
L'événement précise que les scénarios principaux fonctionnent malgré tout.

**Solution** — Étendre le schéma depuis le client le plus récent, avec un compte membre de *Schema Admins* :
```powershell
Update-LapsADSchema -Verbose
```

**Leçon** — Dans un parc hétérogène, la version la plus récente du client peut exiger une mise à jour du schéma.

---

## 21. Le groupe Tier 2 n'est pas ajouté aux administrateurs locaux

**Phase** : 3 — GPO `ADM_Postes_Tier2`
**Capture** : [`03-15-gpo-adm-postes-tier2.png`](../screenshots/phase-03/03-15-gpo-adm-postes-tier2.png) (version corrigée)

**Symptôme** — L'onglet *Settings* de la GPO affichait `LABO\GG_Admind_Tier2` dans *Add members*, sans SID.

**Cause** — Nom de groupe tapé à la main avec une faute de frappe. Une préférence de GPO n'affiche **aucune erreur** :
le groupe n'aurait simplement jamais été ajouté sur les postes.

**Solution** — Supprimer le membre, puis l'ajouter avec le bouton **…** (recherche dans l'annuaire, *Check Names*).
Le SID apparaît alors à côté du nom (`S-1-5-21-…-1217`), preuve que l'objet a été résolu.

**Vérification sur CLIENT01**, connecté avec `LABO\adm-t2-rody` :
```powershell
whoami /groups | findstr /i "Tier2 Administrators"
# BUILTIN\Administrators  …  LABO\GG_Admins_Tier2
```

**Leçon** — Toujours sélectionner un compte ou un groupe par la recherche dans l'annuaire : c'est le SID qui compte, pas le nom.

---

## 22. OVH refuse l'enregistrement TXT sans sous-domaine

**Phase** : 4 — vérification de `rodylabo.be` dans Entra ID

**Symptôme** — Le formulaire d'ajout d'un enregistrement TXT chez OVH refuse la validation si le champ *Sous-domaine* est vide.

**Cause** — Microsoft demande le TXT `MS=ms82311362` **à la racine** du domaine. OVH exige une valeur explicite pour la désigner.

**Solution** — Saisir `@` dans le champ *Sous-domaine*, puis vérifier la publication avant de valider dans Entra :
```powershell
Resolve-DnsName rodylabo.be -Type TXT
```

**Leçon** — En DNS, `@` représente l'apex (la racine) de la zone.

---

## 23. `Invalid value specified for property 'userPrincipalName'`

**Phase** : 4 — script `New-SyncAdmin.ps1`

**Cause** — La ligne `$upn = "admin-sync@$tenant"` n'avait pas été exécutée dans la session : `$upn` était vide.
Même erreur plus tard avec `$tid` vide, qui donnait le nom `.registration.msappproxy.net`.

**Solution** — Exécuter d'abord les lignes de variables, et afficher la valeur avant de l'utiliser (`"Test de : $tid..."`).

**Leçon** — Avec *Run Selection* (F8), seules les lignes sélectionnées existent. Une variable non définie ne provoque pas d'erreur en PowerShell : elle vaut simplement `$null`.

---

## 24. `AccountEnabled` affiché vide avec `Get-MgUser`

**Phase** : 4

**Cause** — Pour limiter le volume, Microsoft Graph ne renvoie qu'un jeu réduit de propriétés par défaut.
`Select-Object AccountEnabled` affiche donc une colonne vide, sans erreur.

**Solution** —
```powershell
Get-MgUser -UserId $upn -Property DisplayName,UserPrincipalName,AccountEnabled |
  Select-Object DisplayName, UserPrincipalName, AccountEnabled
```

**Leçon** — Avec Graph, une valeur vide peut signifier « non demandée » et non « absente ».

---

## 25. `Start-VM` refusé dans VS Code

**Phase** : 4

**Symptôme** — *« Vous n'avez pas l'autorisation requise pour effectuer cette tâche »* en lançant `Start-VM` depuis le terminal de VS Code.

**Cause** — Le terminal de VS Code n'est pas élevé, et l'utilisateur n'est pas membre du groupe local *Administrateurs Hyper-V*.

**Solution** — Utiliser *Terminal (administrateur)* pour les commandes Hyper-V, ou ajouter l'utilisateur au groupe (puis se déconnecter et se reconnecter) :
```powershell
Add-LocalGroupMember -Group "Administrateurs Hyper-V" -Member $env:USERNAME
```

**Leçon** — Le groupe dédié donne le droit de gérer les VM sans être administrateur complet du PC : c'est le moindre privilège.

---

## 26. Copier-coller impossible dans SYNC01

**Phase** : 4

**Cause** — La fenêtre Hyper-V était en **session de base** : le presse-papiers n'est partagé qu'en session améliorée (RDP).

**Solution** — Trois possibilités : *Affichage → Session améliorée*, *Presse-papiers → Taper le texte du Presse-papiers*,
ou **PowerShell Direct** depuis l'hôte, qui ne passe pas par le réseau :
```powershell
Enter-PSSession -VMName "SYNC01" -Credential "SYNC01\Administrator"
```

**Leçon** — L'invite `[SYNC01] : PS` indique que la commande s'exécute dans la VM. Les commandes Hyper-V (`Checkpoint-VM`) restent à lancer sur l'hôte, après `Exit-PSSession`.

---

## 27. PowerShell Direct refusé pour `LABO\adm-t0-rody`

**Phase** : 4

**Symptôme** — *« Les informations d'identification ne sont pas valides »*, trois fois de suite, alors que le compte local `SYNC01\Administrator` fonctionnait.

**Diagnostic** — Réseau validé depuis SYNC01 (`Test-NetConnection 192.168.50.10 -Port 88`, `nltest /sc_verify:ad.rodylabo.be`), puis sur DC01 :
```powershell
Get-ADUser adm-t0-rody -Properties LockedOut, BadLogonCount, Enabled
# Enabled : False — LockedOut : False — BadLogonCount : 0
```
`BadLogonCount` à 0 montrait que le mot de passe n'avait même pas été évalué.

**Cause** — Le compte était **désactivé** : `New-ADUser` crée un compte désactivé si `-Enabled $true` n'est pas précisé ou si aucun mot de passe n'est fourni.

**Solution** —
```powershell
Set-ADAccountPassword adm-t0-rody -Reset -NewPassword (Read-Host -AsSecureString "Nouveau mot de passe")
Enable-ADAccount adm-t0-rody
```

**Leçon** — Avant de soupçonner un mot de passe, lire l'état du compte. Attention aussi au verrouillage : la PSO_Admins bloque le compte après 5 essais pendant 30 minutes.

---

## 28. Cloud Sync : « Connector registration failed »

**Phase** : 4 — installation de l'agent sur SYNC01
**Capture** : [`04-07-cloudsync-agent-installe.png`](../screenshots/phase-04/04-07-cloudsync-agent-installe.png) (après correction)

**Symptôme** — À l'étape *Confirm* : *« Make sure your computer is able to connect to the Azure Active Directory Application Proxy service »*.
Le journal de l'agent indiquait *« Connector registration failed due to network connectivity issues »*.

**Diagnostic** — Tous les tests réseau réussissaient : heure synchronisée, `login.windows.net:443`,
`<tenant>.registration.msappproxy.net:443`, `crl.microsoft.com`, `ctldl.windowsupdate.com` et DigiCert sur le port 80.
Seule anomalie : la valeur `SchUseStrongCrypto` absente du registre .NET.

**Cause** — Le framework .NET de l'agent ne forçait pas TLS 1.2. La connexion TCP s'ouvrait, mais la négociation chiffrée échouait, et l'agent la présentait comme un problème réseau.

**Solution** —
```powershell
foreach ($cle in "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319",
                 "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319") {
  New-ItemProperty -Path $cle -Name SystemDefaultTlsVersions -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path $cle -Name SchUseStrongCrypto       -Value 1 -PropertyType DWord -Force | Out-Null
}
Restart-Computer -Force
```

**Leçon** — `Test-NetConnection` teste TCP, pas TLS. Un message « réseau » peut cacher un problème de chiffrement.

---

## 29. `Restart-Computer` refusé : « other users logged on »

**Phase** : 4

**Cause** — Une autre session (fenêtre Hyper-V ou ancienne session PowerShell Direct) était ouverte sur SYNC01. Par défaut, Windows ne coupe pas les sessions des autres utilisateurs.

**Solution** — `Restart-Computer -Force` dans la VM, ou `Restart-VM -Name "SYNC01" -Force` depuis l'hôte.

---

## 30. « Unable to find domain controller … using credentials of user admin-sync »

**Phase** : 4 — écran *Connect Active Directory* de l'assistant

**Cause** — L'assistant a repris les identifiants **cloud** saisis à l'écran précédent. `admin-sync@rody.onmicrosoft.com` n'existe pas dans l'AD local.

**Solution** — *Add Directory*, effacer le champ utilisateur, saisir `LABO\adm-t0-rody`.

**Leçon** — Deux annuaires, deux comptes : `admin-sync` (rôle *Hybrid Identity Administrator*) enregistre l'agent dans Entra ID, et le Domain Admin ne sert qu'une fois, pour créer le gMSA `provAgentgMSA`. L'agent ne conserve ni l'un ni l'autre.

---

## 31. `Get-MgGroup` n'est pas reconnue

**Phase** : 4 — vérification de la synchronisation

**Cause** — Le SDK Microsoft Graph PowerShell est découpé en modules. `Get-MgGroup` appartient à `Microsoft.Graph.Groups`, qui n'était pas installé.

**Solution** — `Install-Module Microsoft.Graph.Groups -Scope CurrentUser`.

---

## 32. Test à la demande : un compte admin déclaré « in scope »

**Phase** : 4 — *Provision on demand* avec `adm-t0-rody` (OU `Tier0`, hors périmètre)
**Capture** : [`04-14-cloudsync-admin-test-demande.png`](../screenshots/phase-04/04-14-cloudsync-admin-test-demande.png)

**Observation** — L'étape *Determine if object is in scope* affichait *Object is in scope*, puis *Object was skipped* (`SkipReason : JoinNotFound`).
Dans les *Provisioning logs*, l'action évaluée était **Delete**, avec le statut *Skipped* : le moteur voulait supprimer une éventuelle copie cloud, et il n'y en avait aucune.

**Vérification réelle** — Après activation de la synchronisation :
```powershell
Get-MgUser -All -Filter "startswith(userPrincipalName,'adm-')" -ConsistencyLevel eventual -CountVariable n
"Comptes admin dans Entra : $n"   # 0
```

**Leçon** — Un outil de test ne reproduit pas toujours le comportement réel. Un contrôle de sécurité se prouve sur le résultat final : 100 utilisateurs et 10 groupes synchronisés, **0 compte d'administration** dans le cloud.
