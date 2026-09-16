# Härdad prompt — Bash-skript för användare, grupp och delad katalog (ACL)

Den här prompten genererar ett produktionsmässigt Bash-skript som skapar en användare, en
avdelningsgrupp och en delad katalog med `setgid` + `sticky bit` samt POSIX-ACL för en läsande
revisionsgrupp. Se `skapa_nyanvandare.sh` för resultatet.

## Vad som härdades mot originalprompten

**Korrekthet (skriptet skulle annars krascha eller bryta mot specen):**
- **`revision`-gruppen säkerställs** — annars kraschar `setfacl` under `set -e`.
- **Läs-ACL på en katalog kräver `x` (traversering):** `r-x` på katalogen + `X` i default-ACL,
  så framtida underkataloger blir traverserbara medan filer förblir `r--`.
- **setgid gör inte nya filer gruppskrivbara** (umask 022 → filer 644). Default-ACL
  `d:g:ekonomi:rwX` krävs för att gruppmedlemmar ska kunna *redigera* varandras filer.
- **`set -E`** tillagt så att ERR-trappen faktiskt fångar fel *inne i funktioner*.
- **Idempotent lösenord:** temp-lösenordet sätts endast vid nyskapande, aldrig över befintligt.

**Säkerhet:**
- Lösenord matas till `chpasswd` via **stdin** (aldrig som argument → syns inte i `ps`).
- Temp-lösenordet skrivs ut **en gång till stdout**, aldrig till loggfilen.
- Loggfilen skapas med **läge 640 root:adm** (inte världsläsbar).
- Lösenord från **CSPRNG** (`/dev/urandom`), 20 tecken, `chpasswd`-säker teckenmängd.

**Robusthet:**
- `--dry-run` är **helt bieffektsfri** (ingen fs-/användar-/logg-/lösenordsmutation).
- Alla variabler citeras, funktioner använder `local`, **shellcheck-rent**.
- Validerar både användar- och gruppnamn; **vägrar skyddade systemkataloger**.
- Verifierar ACL-stöd (`setfacl`) innan användning.

---

## Prompten

```markdown
## Roll
Du är en erfaren Linux-systemadministratör och pedagog. Du skriver produktionsmässiga,
shellcheck-rena Bash-skript och förklarar varje beslut så att en student på en YH-utbildning
i IT-infrastruktur kan försvara lösningen muntligt.

## Miljö
- OS: Ubuntu Server [24.04 LTS] (Bash 5.x) i VirtualBox
- Skriptet körs med sudo av en administratör
- Filsystemet stödjer POSIX-ACL (ext4). Inga externa beroenden utöver standardförråden
  (paketet `acl` får installeras om `setfacl` saknas)

## Scenario
Ett företag anställer en ny medarbetare på avdelningen [ekonomi]. Skapa ett Bash-skript som:
1. Skapar användaren [anna] med hemkatalog, skal /bin/bash och ett tillfälligt lösenord som
   måste bytas vid första inloggning
2. Skapar gruppen [ekonomi] om den inte finns och lägger till användaren i den
3. Säkerställer att även revisionsgruppen [revision] finns (skapa om den saknas) — ACL nedan
   misslyckas annars
4. Skapar den delade katalogen [/srv/ekonomi] med denna rättighetsstruktur:
   - Ägare: root, grupp: [ekonomi], basläge 3770 (setgid + sticky, inga rättigheter för övriga)
   - Gruppmedlemmar [ekonomi] får läsa, skapa OCH redigera filer i katalogen
   - Nya filer och underkataloger ärver gruppen automatiskt (setgid)
   - Nya filer ska bli gruppskrivbara oavsett användarens umask — lös med default-ACL
     (`d:g:ekonomi:rwX`), eftersom setgid ensamt bara ärver grupp, inte skrivbiten
   - Användare kan inte radera varandras filer (sticky bit)
   - Övriga användare (inte i någon relevant grupp) har ingen åtkomst alls
   - Gruppen [revision] får endast LÄSA — inklusive framtida filer (default ACL). Observera:
     på själva katalogen krävs r-x (exekvering för att kunna gå in och lista), och i
     default-ACL:n används `X` så att framtida underkataloger blir traverserbara medan
     framtida filer förblir r--

## Krav på skriptet
- Börja med `#!/usr/bin/env bash` och `set -Eeuo pipefail` (`-E` krävs för att ERR-trappen
  ska ärvas in i funktioner)
- Kontrollera att skriptet körs som root (EUID 0), avbryt annars med tydligt felmeddelande
- Ta användarnamn, primär grupp, revisionsgrupp och katalog som argument med rimliga
  standardvärden; visa hjälptext med `-h/--help` och stöd `--dry-run`
- Validera indata: giltiga användar-/gruppnamn enligt Linux-konventioner
  (`^[a-z_][a-z0-9_-]*$`), absolut sökväg för katalogen; vägra farliga mål
  (t.ex. /, /home, /etc, /root, /boot, /usr)
- Verifiera att `setfacl` finns (installera `acl` vid behov) innan ACL sätts
- Idempotent: kan köras flera gånger utan fel eller dubbletter och konvergerar mot önskat
  läge (grupper, medlemskap, ägare/läge, ACL sätts om varje gång). LÖSENORDET sätts dock
  ENDAST när användaren nyskapas — skriv aldrig över ett befintligt lösenord vid omkörning
- Sätt lösenord säkert: generera med CSPRNG (t.ex. `openssl rand`/`/dev/urandom`), rimlig
  längd (≥16) och ett teckenval som är kompatibelt med `chpasswd` och ev. pwquality-policy.
  Skicka aldrig lösenordet som kommandoargument — mata `chpasswd` via stdin/here-string.
  Tvinga byte vid första inloggning (t.ex. `chage -d 0`, efter att lösenordet satts)
- Skriv aldrig lösenordet till loggfilen. Skriv ut det tillfälliga lösenordet EN gång till
  stdout (rekommendera i utskriften att det överlämnas out-of-band), inte i --dry-run
- Logga varje steg med tidsstämpel (ISO-8601) till både terminalen och
  [/var/log/nyanvandare.log]. Skapa loggfilen med läge 640 och ägare root:adm (aldrig
  världsläsbar)
- `--dry-run` ska vara HELT bieffektsfri: validerar indata och skriver ut de kommandon som
  skulle köras, men ändrar inget (ingen användare/grupp/katalog/ACL, ingen skrivning till
  riktiga loggfilen, inget genererat lösenord)
- Samla logik i funktioner (t.ex. `kontrollera_root`, `validera_indata`, `skapa_grupp`,
  `skapa_anvandare`, `satt_rattigheter`, `satt_acl`). Använd `local` för funktionsvariabler
  och citera ALLA variabelexpansioner ("$var")
- Använd `trap '...' ERR` som rapporterar rad ($LINENO) och kommando ($BASH_COMMAND) vid fel,
  samt sätter en tydlig exit-kod
- Definiera tydliga exit-koder (0 = ok, ≠0 för olika felslag)
- Kommentarer på svenska. Skriptet ska passera `shellcheck` utan varningar
- Använd inte `chmod 777` eller andra osäkra genvägar

## Leverans
Svara i denna ordning:
1. Kort översikt av lösningen (max 5 meningar) INKLUSIVE varje antagande du gjort (särskilt
   tolkningen av "skriva" = redigera andras filer, samt val av ACL för att uppnå detta)
2. Hela skriptet i ett kodblock
3. Förklaring av rättighetsmodellen: vad det numeriska modet (3770) betyder, vad setgid och
   sticky bit gör, varför setgid ENSAMT inte räcker för gruppskrivbara nya filer (umask), och
   varför ACL behövs för revisionsgruppen i stället för vanliga rättigheter — förklara även
   ACL-**masken** och skillnaden mellan access-ACL och default-ACL samt varför `X` (versalt)
   används
4. Testplan med konkreta kommandon som bevisar att allt fungerar: `id`, `getent`, `ls -ld`,
   `getfacl`, `stat`, samt tester (med `sudo -u`) där en användare i [ekonomi], en i
   [revision] och en utan grupp försöker (a) gå in i katalogen, (b) läsa en fil, (c) skapa
   en fil, (d) redigera en ANNAN användares fil och (e) radera en annan användares fil —
   med förväntat utfall för varje
5. Ett rollback-skript/kommandon som tar bort användare (och ev. hemkatalog), grupper och
   katalog igen — även det idempotent
6. Tre troliga frågor en lärare kan ställa vid muntlig validering, med korta svar

## Begränsningar
- Förklara varför du väljer `useradd` eller `adduser` (motivera utifrån idempotens och
  icke-interaktiv körning)
- Om något i scenariot är tvetydigt, gör ett rimligt antagande och redovisa det under punkt 1
```
