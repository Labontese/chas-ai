# Jämförelse och testning: användare, grupp och delad katalog med ACL

Studiematerial för YH-utbildningen IT-infrastrukturspecialist (ISCX26, Chas Academy). Dokumentet innehåller prompterna, skriptet `nyanvandare.sh` med förklaring av rättighetsmodellen, testplan, rollback, förberedelse inför muntlig validering samt en testad jämförelse mellan tre skript, plus Oscars interaktiva variant:

- [`nyanvandare.sh`](nyanvandare.sh), skrivet av Claude utifrån den första avancerade prompten
- [`../skapa_nyanvandare.sh`](../skapa_nyanvandare.sh), genererat utifrån den härdade prompten i [`../PROMPT.md`](../PROMPT.md)
- [`gemini_nyanvandare.sh`](gemini_nyanvandare.sh), skrivet av Gemini
- [`oscar_skapa_anvandare.sh`](oscar_skapa_anvandare.sh), Oscars variant, som tolkar uppgiften annorlunda och testas med en egen svit (avsnitt 9)

Avsnitt 10 är ett färdigt underlag för redovisningen. Alla jämförelser finns också samlade i [`JAMFORELSE.md`](JAMFORELSE.md).

Allt är testat i Ubuntu 24.04 LTS (september 2026). Testmiljön saknade `sudo`, så rättighetstesterna kördes med `runuser -u`, som ger samma resultat som `sudo -u`.

## Filer som hör till dokumentet

| Fil | Innehåll |
|---|---|
| [`JAMFORELSE.md`](JAMFORELSE.md) | Alla jämförelser och testmatriser samlade på ett ställe |
| [`nyanvandare.sh`](nyanvandare.sh) | Claudes skript (avsnitt 3) |
| [`rollback_nyanvandare.sh`](rollback_nyanvandare.sh) | Tar bort användare, grupper och katalog igen (avsnitt 6) |
| [`gemini_nyanvandare.sh`](gemini_nyanvandare.sh) | Geminis skript, oförändrat (bilaga A) |
| [`gemini_lagad.sh`](gemini_lagad.sh) | Geminis skript med enbart lösenordsraden lagad (avsnitt 8) |
| [`jamfor_skript.sh`](jamfor_skript.sh) | Testsviten som jämför skripten (bilaga B) |
| [`testresultat.txt`](testresultat.txt) | Fullständig utskrift från testkörningen (bilaga C) |
| [`../skapa_nyanvandare.sh`](../skapa_nyanvandare.sh) | Skriptet från den härdade prompten |
| [`../PROMPT.md`](../PROMPT.md) | Den härdade prompten |
| [`oscar_skapa_anvandare.sh`](oscar_skapa_anvandare.sh) | Oscars variant, oförändrad (bilaga D) |
| [`oscar_lagad.sh`](oscar_lagad.sh) | Oscars variant med sex lagningar (avsnitt 9) |
| [`testa_oscar.sh`](testa_oscar.sh) | Testsvit för Oscars interaktiva skript (bilaga E) |
| [`testresultat_oscar.txt`](testresultat_oscar.txt) | Utskrift från testkörningen av Oscars skript (bilaga F) |

## Innehåll

1. Prompter
2. Översikt och antaganden
3. Skriptet `nyanvandare.sh`
4. Rättighetsmodellen
5. Testplan
6. Rollback
7. Frågor vid muntlig validering
8. Jämförelse och testresultat
9. Oscars variant
10. Underlag för redovisning
11. Bilaga A: Gemini-skriptet
12. Bilaga B: Testsviten `jamfor_skript.sh`
13. Bilaga C: Fullständig testutskrift
14. Bilaga D: Oscars skript
15. Bilaga E: Testsviten `testa_oscar.sh`
16. Bilaga F: Testutskrift för Oscars skript

---

## 1. Prompter

Prompterna är sparade ordagrant, i den ordning de användes.

### 1.1 Uppgiften

```text
Bash eller skript för ett specifikt administrativt scenario "Skapa en användare och sätt rättighetsstrukturer för en ny katalog i Linux"
```

### 1.2 Beställningen av prompten

```text
gör en avancerad promt för detta "Bash eller skript för ett specifikt administrativt scenario "Skapa en användare och sätt rättighetsstrukturer för en ny katalog i Linux""
```

### 1.3 Den avancerade prompten

Både `nyanvandare.sh` (Claude) och `gemini_nyanvandare.sh` (Gemini) bygger på den här prompten. Byt ut värdena inom hakparentes innan du använder den.

````text
## Roll
Du är en erfaren Linux-systemadministratör och pedagog. Du skriver produktionsmässiga Bash-skript och förklarar varje beslut så att en student på en YH-utbildning i IT-infrastruktur kan försvara lösningen muntligt.

## Miljö
- OS: Ubuntu Server [24.04 LTS] i VirtualBox
- Skriptet körs med sudo av en administratör
- Inga externa beroenden utöver paket som finns i standardförråden (acl får installeras om det saknas)

## Scenario
Ett företag anställer en ny medarbetare på avdelningen [ekonomi]. Skapa ett Bash-skript som:
1. Skapar användaren [anna] med hemkatalog, skal /bin/bash och ett tillfälligt lösenord som måste bytas vid första inloggning
2. Skapar gruppen [ekonomi] om den inte finns och lägger till användaren i den
3. Skapar den delade katalogen [/srv/ekonomi] med denna rättighetsstruktur:
   - Ägare: root, grupp: [ekonomi]
   - Gruppmedlemmar får läsa, skriva och skapa filer
   - Övriga användare har ingen åtkomst alls
   - Nya filer och underkataloger ärver gruppen automatiskt (setgid)
   - Användare kan inte radera varandras filer (sticky bit)
   - Gruppen [revision] får endast läsrättighet via ACL, även på filer som skapas i framtiden (default ACL)

## Krav på skriptet
- Börja med `#!/usr/bin/env bash` och `set -euo pipefail`
- Kontrollera att skriptet körs som root, avbryt annars med tydligt felmeddelande
- Ta användarnamn, grupp och katalog som argument med rimliga standardvärden, och visa hjälptext med `-h`
- Validera indata: giltigt användarnamn enligt Linux-konventioner, absolut sökväg för katalogen
- Idempotent: skriptet ska kunna köras flera gånger utan fel eller dubbletter
- Stöd för `--dry-run` som visar vad som skulle göras utan att ändra något
- Logga varje steg med tidsstämpel till både terminalen och [/var/log/nyanvandare.log]
- Samla logik i funktioner (t.ex. `skapa_grupp`, `skapa_anvandare`, `satt_rattigheter`)
- Generera det tillfälliga lösenordet slumpmässigt, skriv aldrig lösenord i klartext till loggfilen
- Använd `trap` för att rapportera vilken rad som fallerade vid fel
- Kommentarer på svenska

## Leverans
Svara i denna ordning:
1. Kort översikt av lösningen (max 5 meningar)
2. Hela skriptet i ett kodblock
3. Förklaring av rättighetsmodellen: vad betyder den numeriska modet (t.ex. 3770), vad gör setgid och sticky bit, och varför ACL behövs för revisionsgruppen i stället för vanliga rättigheter
4. Testplan med konkreta kommandon som bevisar att allt fungerar: `id`, `getent`, `ls -ld`, `getfacl`, `stat`, samt tester där en användare i [ekonomi], en i [revision] och en utan grupp försöker läsa, skriva och radera filer (använd `sudo -u`)
5. Ett rollback-skript eller kommandon som tar bort användare, grupper och katalog igen
6. Tre troliga frågor en lärare kan ställa vid en muntlig validering, med korta svar

## Begränsningar
- Förklara varför du väljer `useradd` eller `adduser`
- Använd inte `chmod 777` eller andra osäkra genvägar
- Om något i scenariot är tvetydigt, gör ett rimligt antagande och redovisa det under punkt 1
````

### 1.4 Den härdade prompten

Den härdade prompten ligger i [`../PROMPT.md`](../PROMPT.md) och ligger till grund för [`../skapa_nyanvandare.sh`](../skapa_nyanvandare.sh). Den åtgärdar bland annat `-E` i `set -Eeuo pipefail`, skydd av systemkataloger, loggfilens rättigheter och en helt bieffektsfri dry-run.

**Förslag till nästa version, utifrån testresultaten i avsnitt 8:**

- Kräv att sökvägen normaliseras (`realpath -m`) och att både systemkatalogerna och allt under dem vägras. En lista med exakta namn släpper igenom `/etc/`, `/srv/x/../../etc`, `/tmp` och `/usr/local`.
- Ta ställning till om lösenordet ska skrivas ut när utdata går till en fil eller en pipe (`[[ -t 1 ]]`).
- Använd tilläggsgrupp (`-G` eller `usermod -aG`), inte primärgrupp.
- Kräv en testsvit som bevisar kraven, så att fel som SIGPIPE-kraschen syns direkt.

### 1.5 Uppföljande prompter

Jämförelsen (Geminis skript bifogades):

```text
kan du jämnföra skriptet
```

Samla allt i en fil:

```text
gör en komplett fil jag kan spara om promten och allt
```

Lägg till testerna och prompterna:

```text
och testerna mellan vårat och gemeni script, spara även prompterna
```

Anpassa materialet till repot (där `PROMPT.md` och `skapa_nyanvandare.sh` redan fanns):

```text
https://github.com/Labontese/chas-ai
```

Redovisningskraven (avsnitt 10):

```text
* Redovisning:
   * Varje grupp visar sina två prompts och förklarar skillnaden i utdata.
   * De visar upp ett konkret exempel på där AI:n hallucinerade eller där de behövde dubbelkolla ett kommandos flaggor manuellt.
```

Oscars variant (avsnitt 9, skriptet bifogades):

```text
lägg även in Oscars variant
```

Lägg in allt i repot:

```text
lägg up till git
```

### 1.6 Oscars prompt

**AI-verktyg:** ChatGPT

Oscars prompt (ordagrant):

```text
Jag vill att du ska skapa en script i bash där vi ska skapa nya användare och de
användare ska få tilldelade till rätt avdelningar, roll & rättigheter. Därefter
tilldela mappar Dokument, Bilder, Appar, Videos, där endast den nya användaren har
tillgång till. Därefter vill vi att den ska få ett fint välkomstmeddelande och att
den är tilldelad att vi kom överens om, sedan efter det vill vi att den ska få namnen
för andra personer i andelningen. Du som AI ska även ge en detaljerad förklaring efter
scripten vad alla delar gör och varför du använde de kommandos du gjorde
```

Prompten förklarar varför Oscars skript blev så annorlunda än de andra tre. Den ber om
**privata mappar per användare** (inte en delad avdelningskatalog), nämner **avdelning och
roll** men inte setgid, sticky bit eller ACL, och säger ingenting om idempotens, dry-run,
validering eller lösenordshantering. Den bad däremot uttryckligen om en **detaljerad
förklaring efter skriptet**, vilket ChatGPT levererade. Kort sagt: en annan uppgift, ställd i
vardagsspråk utan de tekniska kraven — därav ett interaktivt skript med annan inriktning.

---

## 2. Översikt och antaganden

Skriptet skapar användaren, avdelningsgruppen och läsgruppen, och sätter sedan upp `/srv/ekonomi` med ägare `root:ekonomi`, mode `3770` och ACL för `revision`. All logik ligger i funktioner, och en hjälpfunktion `kor` gör att `--dry-run` bara visar kommandona i stället för att köra dem. Skriptet är idempotent: det kontrollerar vad som redan finns och kan köras om utan fel. Lösenordet slumpas, skickas via stdin till `chpasswd`, visas bara i terminalen och måste bytas vid första inloggning.

**Antaganden:**

- Gruppen `revision` skapas (tom) om den saknas, annars går det inte att sätta ACL för den.
- Skriptet använder `set -Eeuo pipefail`. Det extra `-E` behövs för att `trap ... ERR` ska fungera inuti funktioner.
- En användare som redan finns får inget nytt lösenord, annars vore skriptet inte idempotent.
- Om utdata inte går till en terminal visas lösenordet inte alls, och administratören sätter ett nytt med `passwd`.
- `--dry-run` kräver också root och skriver ingenting till loggfilen.

---

## 3. Skriptet `nyanvandare.sh`

### Så använder du det

```bash
nano nyanvandare.sh              # klistra in skriptet och spara
chmod +x nyanvandare.sh
sudo ./nyanvandare.sh --dry-run  # se vad som skulle hända
sudo ./nyanvandare.sh            # kör på riktigt
sudo ./nyanvandare.sh -u erik -g hr -d /srv/hr -r revision
```

### Flaggor

| Flagga | Betydelse | Standard |
|---|---|---|
| `-u`, `--user` | Användarnamn | `anna` |
| `-g`, `--group` | Avdelningsgrupp | `ekonomi` |
| `-d`, `--dir` | Delad katalog | `/srv/ekonomi` |
| `-r`, `--readgroup` | Grupp med läsrätt | `revision` |
| `-n`, `--dry-run` | Visa utan att ändra | av |
| `-h`, `--help` | Visa hjälp | |

### Koden

Skriptet passerar `shellcheck` utan anmärkningar.

```bash
#!/usr/bin/env bash
#
# nyanvandare.sh
# Skapar en användare, lägger den i en avdelningsgrupp och sätter upp en
# delad katalog med setgid, sticky bit och läs-ACL för en revisionsgrupp.
#
# Exempel:
#   sudo ./nyanvandare.sh
#   sudo ./nyanvandare.sh -u erik -g hr -d /srv/hr --dry-run

# -E gör att ERR-trapen även gäller inuti funktioner
set -Eeuo pipefail

# ---------- Standardvärden ----------
ANVANDARE="anna"
GRUPP="ekonomi"
KATALOG="/srv/ekonomi"
LASGRUPP="revision"
LOGGFIL="/var/log/nyanvandare.log"
DRY_RUN=0

# ---------- Loggning och felhantering ----------

# Skriver till terminalen och (utom vid dry-run) till loggfilen
logga() {
    local niva="$1"; shift
    local rad
    rad="$(date '+%Y-%m-%d %H:%M:%S') [${niva}] $*"
    if [[ "$niva" == "FEL" ]]; then
        printf '%s\n' "$rad" >&2
    else
        printf '%s\n' "$rad"
    fi
    if (( DRY_RUN == 0 )); then
        { printf '%s\n' "$rad" >> "$LOGGFIL"; } 2>/dev/null || true
    fi
}

# Anropas automatiskt när ett kommando misslyckas
fel_hanterare() {
    local rad="$1" kommando="$2"
    logga "FEL" "Avbrutet på rad ${rad}: '${kommando}'"
    exit 1
}
trap 'fel_hanterare "$LINENO" "$BASH_COMMAND"' ERR

# Kör ett kommando, eller visar bara vad som skulle köras vid dry-run
kor() {
    if (( DRY_RUN )); then
        logga "DRY-RUN" "$*"
    else
        logga "KÖR" "$*"
        "$@"
    fi
}

# ---------- Argument och validering ----------

visa_hjalp() {
    cat <<EOF
Användning: sudo $(basename "$0") [ALTERNATIV]

Skapar en användare, lägger den i en avdelningsgrupp och sätter upp en
delad katalog med setgid, sticky bit och läs-ACL för en revisionsgrupp.

Alternativ:
  -u, --user NAMN        Användarnamn        (standard: ${ANVANDARE})
  -g, --group NAMN       Avdelningsgrupp     (standard: ${GRUPP})
  -d, --dir SÖKVÄG       Delad katalog       (standard: ${KATALOG})
  -r, --readgroup NAMN   Grupp med läsrätt   (standard: ${LASGRUPP})
  -n, --dry-run          Visa vad som görs utan att ändra något
  -h, --help             Visa denna hjälp
EOF
}

tolka_argument() {
    while (( $# > 0 )); do
        case "$1" in
            -u|--user)      ANVANDARE="${2:?Saknar värde för $1}"; shift 2 ;;
            -g|--group)     GRUPP="${2:?Saknar värde för $1}"; shift 2 ;;
            -d|--dir)       KATALOG="${2:?Saknar värde för $1}"; shift 2 ;;
            -r|--readgroup) LASGRUPP="${2:?Saknar värde för $1}"; shift 2 ;;
            -n|--dry-run)   DRY_RUN=1; shift ;;
            -h|--help)      visa_hjalp; exit 0 ;;
            *)              printf 'Okänt alternativ: %s\n\n' "$1" >&2
                            visa_hjalp >&2
                            exit 2 ;;
        esac
    done
}

kontrollera_root() {
    # Använder printf direkt eftersom loggfilen kräver root
    if [[ "$EUID" -ne 0 ]]; then
        printf 'FEL: Skriptet måste köras som root, till exempel: sudo %s\n' "$0" >&2
        exit 1
    fi
}

# Linux-konvention (samma som Debians standard för useradd):
# små bokstäver, siffror, _ och -, börjar med bokstav eller _, max 32 tecken
validera_namn() {
    local namn="$1" typ="$2"
    if [[ ! "$namn" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        logga "FEL" "Ogiltigt ${typ}: '${namn}'"
        exit 2
    fi
}

validera_katalog() {
    if [[ "$KATALOG" != /* ]]; then
        logga "FEL" "Katalogen måste vara en absolut sökväg: '${KATALOG}'"
        exit 2
    fi
    if [[ "$KATALOG" == *..* ]]; then
        logga "FEL" "Sökvägen får inte innehålla '..': '${KATALOG}'"
        exit 2
    fi
    # Ta bort eventuellt avslutande snedstreck
    KATALOG="${KATALOG%/}"
    # Skydda systemkataloger, både själva katalogen och allt under dem
    case "$KATALOG" in
        ""|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
        /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
            logga "FEL" "Vägrar att ändra rättigheter i systemkatalogen '${KATALOG:-/}'"
            exit 2 ;;
    esac
}

# ---------- Förberedelser ----------

forbered_loggfil() {
    # Loggfilen ska inte vara läsbar för alla (640, root:adm)
    if (( DRY_RUN == 0 )) && [[ ! -e "$LOGGFIL" ]]; then
        install -m 0640 -o root -g adm /dev/null "$LOGGFIL"
    fi
}

kontrollera_acl() {
    if command -v setfacl >/dev/null 2>&1; then
        logga "INFO" "ACL-verktygen finns redan"
    else
        logga "INFO" "Paketet acl saknas och installeras"
        kor apt-get update -qq
        kor env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq acl
    fi
}

# ---------- Huvudsteg ----------

skapa_grupp() {
    local grupp="$1"
    if getent group "$grupp" >/dev/null; then
        logga "INFO" "Gruppen '${grupp}' finns redan"
    else
        kor groupadd "$grupp"
    fi
}

satt_tillfalligt_losenord() {
    if (( DRY_RUN )); then
        logga "DRY-RUN" "Sätter slumpat lösenord och kräver byte vid första inloggning (chage -d 0 ${ANVANDARE})"
        return 0
    fi

    local losenord
    # 12 slumpade byte ger 16 tecken base64
    losenord="$(head -c 12 /dev/urandom | base64)"

    # printf är inbyggt i bash, så lösenordet syns aldrig i processlistan (ps)
    printf '%s:%s\n' "$ANVANDARE" "$losenord" | chpasswd
    kor chage -d 0 "$ANVANDARE"
    logga "INFO" "Tillfälligt lösenord satt för '${ANVANDARE}' (loggas inte)"

    # Visa lösenordet bara om utdata går till en terminal, aldrig till fil
    if [[ -t 1 ]]; then
        printf '\n  Tillfälligt lösenord för %s: %s\n  Lämna över det via en säker kanal.\n\n' \
            "$ANVANDARE" "$losenord"
    else
        logga "VARNING" "Ingen terminal, lösenordet visas inte. Sätt ett nytt med: sudo passwd ${ANVANDARE}"
    fi
}

skapa_anvandare() {
    if id "$ANVANDARE" &>/dev/null; then
        logga "INFO" "Användaren '${ANVANDARE}' finns redan, lösenordet lämnas orört"
        # Säkerställ gruppmedlemskap även för en befintlig användare
        if [[ " $(id -nG "$ANVANDARE") " == *" ${GRUPP} "* ]]; then
            logga "INFO" "'${ANVANDARE}' är redan medlem i '${GRUPP}'"
        else
            kor usermod -aG "$GRUPP" "$ANVANDARE"
        fi
    else
        kor useradd --create-home --shell /bin/bash --groups "$GRUPP" "$ANVANDARE"
        satt_tillfalligt_losenord
    fi
}

satt_rattigheter() {
    if [[ -d "$KATALOG" ]]; then
        logga "INFO" "Katalogen '${KATALOG}' finns redan, rättigheterna sätts om"
    else
        kor mkdir -p "$KATALOG"
    fi

    kor chown "root:${GRUPP}" "$KATALOG"

    # 3770 = setgid (2) + sticky (1), ägare rwx, grupp rwx, övriga inget
    kor chmod 3770 "$KATALOG"

    # Läsrätt för läsgruppen på befintligt innehåll.
    # Stort X ger exekvering (inträde) bara på kataloger, inte på filer.
    kor setfacl -R -m "g:${LASGRUPP}:rX" "$KATALOG"

    # Default-ACL ärvs av allt som skapas i framtiden. Den ersätter även
    # användarens umask, så att nya filer blir skrivbara för gruppen.
    kor setfacl -R -d -m "u::rwx,g::rwx,o::---,g:${LASGRUPP}:rX" "$KATALOG"
}

# ---------- Start ----------

main() {
    tolka_argument "$@"
    kontrollera_root
    forbered_loggfil
    validera_namn "$ANVANDARE" "användarnamn"
    validera_namn "$GRUPP" "gruppnamn"
    validera_namn "$LASGRUPP" "gruppnamn för läsgrupp"
    validera_katalog

    if (( DRY_RUN )); then
        logga "INFO" "DRY-RUN aktivt, inga ändringar görs"
    fi
    logga "INFO" "Start: användare=${ANVANDARE} grupp=${GRUPP} katalog=${KATALOG} läsgrupp=${LASGRUPP}"

    kontrollera_acl
    skapa_grupp "$GRUPP"
    skapa_grupp "$LASGRUPP"
    skapa_anvandare
    satt_rattigheter

    logga "INFO" "Klart"
}

main "$@"
```

---

## 4. Rättighetsmodellen

### Mode 3770

Läses siffra för siffra:

| Siffra | Gäller | Värde |
|---|---|---|
| 3 | Specialbitar | setgid (2) + sticky (1). setuid skulle vara 4 |
| 7 | Ägare (root) | rwx |
| 7 | Grupp (ekonomi) | rwx |
| 0 | Övriga | inget |

I `ls -ld` syns det som `drwxrws--T+`:

- `s` i gruppens position betyder setgid (med exekveringsrätt).
- Versalt `T` betyder sticky bit utan exekveringsrätt för övriga.
- `+` visar att katalogen har ACL.

### Setgid på en katalog

Nya filer och underkataloger får katalogens grupp (`ekonomi`) i stället för skaparens primära grupp. På Ubuntu har varje användare en egen primärgrupp (till exempel `anna`), så utan setgid skulle kollegorna inte komma åt Annas filer. Underkataloger ärver även setgid-biten; i testet fick `rapporter` mode `2770`.

### Sticky bit

Bara filens ägare (eller root) kan radera eller byta namn på den, trots att gruppen har skrivrätt till katalogen. Kollegor kan alltså ändra innehållet i varandras filer, men inte ta bort dem. Sticky bit ärvs inte av underkataloger.

### Varför ACL för revision

En fil har bara en ägande grupp, och den platsen är upptagen av `ekonomi`. Det enda sättet att ge `revision` läsrätt med vanliga rättigheter vore via "övriga", men då kan alla på systemet läsa. ACL låter dig lägga till fler namngivna grupper med egna rättigheter.

**Default-ACL** (`setfacl -d`) gör att nya filer ärver reglerna automatiskt. En bonus är att default-ACL ersätter användarens umask: i testet hade Anna umask `0022`, men hennes nya fil fick ändå `660`, alltså skrivbar för gruppen.

**ACL-masken** är ett tak för vad namngivna poster och ägargruppen faktiskt får. Därför visar `getfacl` på en fil `group:revision:r-x #effective:r--`: masken är `rw-` för filer, så revision får bara läsa. Om någon kör `chmod g-w` på en fil ändras masken.

**Stort `X`** i `rX` ger exekveringsrätt (inträde) bara på kataloger, aldrig på vanliga filer.

### Varför `useradd` och inte `adduser`

`useradd` är det låga, icke-interaktiva verktyget som finns på alla distributioner och ger förutsägbara returkoder, vilket passar skript. `adduser` på Ubuntu är ett interaktivt skal runt `useradd` som frågar efter lösenord och namn. Nackdelen med `useradd` är snåla standardvärden (ingen hemkatalog, skalet `/bin/sh`), därför anges `--create-home` och `--shell /bin/bash` uttryckligen. `--groups` (tilläggsgrupp) används i stället för `-g` (primärgrupp) så att Anna behåller sin egen primärgrupp enligt Ubuntus standard.

### Lösenordshanteringen

- Slumpas med `head -c 12 /dev/urandom | base64` (16 tecken).
- Skickas till `chpasswd` via stdin med den inbyggda `printf`, så det syns aldrig i `ps` eller i bash-historiken.
- Skrivs aldrig till loggfilen.
- Visas bara om utdata går till en terminal (`[[ -t 1 ]]`).
- `chage -d 0` tvingar byte vid första inloggning.
- Loggfilen skapas med rättigheterna `640 root:adm`.

---

## 5. Testplan

Grupptillhörighet läses in vid inloggning, så en användare som redan är inloggad måste logga ut och in igen. `sudo -u` läser in grupperna på nytt och fungerar direkt.

### Förberedelser och grundkontroller

```bash
# Testanvändare
sudo useradd -m -G ekonomi kollega
sudo useradd -m -G revision revisor
sudo useradd -m utomstaende

# Grundkontroller (förväntat resultat i kommentaren)
id anna                              # groups=...(anna),...(ekonomi)
getent group ekonomi revision        # ekonomi:x:...:anna,kollega
sudo chage -l anna | head -1         # password must be changed
ls -ld /srv/ekonomi                  # drwxrws--T+ root ekonomi
stat -c '%a %A %U:%G' /srv/ekonomi   # 3770 drwxrws--T root:ekonomi
getfacl /srv/ekonomi                 # group:revision:r-x plus default:-rader
```

Förväntad utdata från `getfacl /srv/ekonomi`:

```text
# file: srv/ekonomi
# owner: root
# group: ekonomi
# flags: -st
user::rwx
group::rwx
group:revision:r-x
mask::rwx
other::---
default:user::rwx
default:group::rwx
default:group:revision:r-x
default:mask::rwx
default:other::---
```

### Rättighetstester

Kör i den här ordningen, eftersom filen skapas först och raderingstesterna kommer sist.

```bash
sudo -u anna bash -c 'echo hej > /srv/ekonomi/anna.txt'      # OK
sudo -u anna mkdir /srv/ekonomi/rapporter                     # OK
sudo -u kollega cat /srv/ekonomi/anna.txt                     # OK
sudo -u kollega bash -c 'echo mer >> /srv/ekonomi/anna.txt'   # OK
sudo -u kollega rm -f /srv/ekonomi/anna.txt                   # Nekas (sticky bit)
sudo -u revisor ls /srv/ekonomi                               # OK
sudo -u revisor cat /srv/ekonomi/anna.txt                     # OK
sudo -u revisor touch /srv/ekonomi/rev.txt                    # Nekas
sudo -u revisor bash -c 'echo x >> /srv/ekonomi/anna.txt'     # Nekas
sudo -u revisor rm -f /srv/ekonomi/anna.txt                   # Nekas
sudo -u utomstaende ls /srv/ekonomi                           # Nekas
sudo -u utomstaende cat /srv/ekonomi/anna.txt                 # Nekas
```

### Resultat från testkörningen

| Test | Resultat |
|---|---|
| anna skapar fil | OK |
| anna skapar underkatalog | OK |
| kollega läser annas fil | OK |
| kollega skriver i annas fil | OK |
| kollega raderar annas fil | Nekas |
| revisor listar katalogen | OK |
| revisor läser fil | OK |
| revisor skapar fil | Nekas |
| revisor skriver i fil | Nekas |
| revisor raderar fil | Nekas |
| utomstående listar katalogen | Nekas |
| utomstående läser fil | Nekas |
| anna raderar egen fil | OK |

### Arv av grupp och ACL

```bash
stat -c '%n %a %U:%G' /srv/ekonomi/anna.txt /srv/ekonomi/rapporter
# /srv/ekonomi/anna.txt 660 anna:ekonomi
# /srv/ekonomi/rapporter 2770 anna:ekonomi

getfacl /srv/ekonomi/anna.txt
# group:revision:r-x    #effective:r--
# mask::rw-
```

### Idempotens, dry-run, validering och logg

```bash
sudo ./nyanvandare.sh                     # "finns redan" på alla steg, inga fel
sudo ./nyanvandare.sh -u erik --dry-run   # bara [DRY-RUN]-rader, inget skapas
sudo ./nyanvandare.sh -u Anna; echo $?    # Ogiltigt användarnamn, 2
sudo ./nyanvandare.sh -d /etc; echo $?    # Vägrar ändra systemkatalog, 2
sudo ./nyanvandare.sh -d /usr/local/x; echo $?   # Vägrar, även under systemkataloger, 2
./nyanvandare.sh; echo $?                 # utan sudo: FEL, 1
sudo stat -c '%a %U:%G' /var/log/nyanvandare.log      # 640 root:adm
sudo grep -c 'lösenord för' /var/log/nyanvandare.log  # 0
```

### Test av `trap`

Byt tillfälligt ut raden `kor chmod 3770 "$KATALOG"` mot `false` i en kopia av skriptet och kör den. Förväntat resultat:

```text
[FEL] Avbrutet på rad 209: 'false'
```

---

## 6. Rollback

### Manuellt

```bash
sudo pkill -u anna                  # avsluta eventuella processer
sudo userdel --remove anna          # tar även bort hemkatalog och primärgrupp
sudo groupdel ekonomi
sudo groupdel revision
sudo rm -rf --one-file-system /srv/ekonomi

# Testanvändarna
sudo userdel --remove kollega
sudo userdel --remove revisor
sudo userdel --remove utomstaende
```

### Skript: `rollback_nyanvandare.sh`

Kräver att du skriver `JA` för att bekräfta och har samma skydd mot systemkataloger som huvudskriptet. Efter rollback gick huvudskriptet att köra igen från noll utan problem.

```bash
sudo ./rollback_nyanvandare.sh                            # standardvärden
sudo ./rollback_nyanvandare.sh erik hr /srv/hr revision   # egna värden
```

```bash
#!/usr/bin/env bash
#
# rollback_nyanvandare.sh
# Tar bort det som nyanvandare.sh skapade.
# Användning: sudo ./rollback_nyanvandare.sh [användare] [grupp] [katalog] [läsgrupp]

set -Eeuo pipefail

ANVANDARE="${1:-anna}"
GRUPP="${2:-ekonomi}"
KATALOG="${3:-/srv/ekonomi}"
LASGRUPP="${4:-revision}"
KATALOG="${KATALOG%/}"

if [[ "$EUID" -ne 0 ]]; then
    echo "FEL: Kör som root (sudo)." >&2
    exit 1
fi

# Samma skydd som i huvudskriptet, en rm -rf på fel ställe är oåterkallelig
case "$KATALOG" in
    ""|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
    /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
        echo "FEL: Vägrar att ta bort '${KATALOG:-/}'." >&2
        exit 2 ;;
esac
if [[ "$KATALOG" != /* || "$KATALOG" == *..* ]]; then
    echo "FEL: Ogiltig sökväg '${KATALOG}'." >&2
    exit 2
fi

echo "Följande tas bort:"
echo "  Användare: ${ANVANDARE} (inklusive hemkatalog)"
echo "  Grupper:   ${GRUPP}, ${LASGRUPP}"
echo "  Katalog:   ${KATALOG} (inklusive allt innehåll)"
read -rp "Skriv JA för att fortsätta: " svar
if [[ "$svar" != "JA" ]]; then
    echo "Avbrutet, inget ändrades."
    exit 0
fi

if id "$ANVANDARE" &>/dev/null; then
    # Avsluta eventuella processer, annars vägrar userdel
    pkill -KILL -u "$ANVANDARE" || true
    userdel --remove "$ANVANDARE"
    echo "Användaren ${ANVANDARE} borttagen"
fi

for grupp in "$GRUPP" "$LASGRUPP"; do
    if getent group "$grupp" >/dev/null; then
        groupdel "$grupp"
        echo "Gruppen ${grupp} borttagen"
    fi
done

if [[ -d "$KATALOG" ]]; then
    rm -rf --one-file-system -- "$KATALOG"
    echo "Katalogen ${KATALOG} borttagen"
fi

echo "Rollback klar"
```

---

## 7. Frågor vid muntlig validering

**"Varför setgid, räcker det inte med `chown root:ekonomi` och `chmod 770`?"**
Nej, `chown` påverkar bara själva katalogen. Nya filer får skaparens primärgrupp, på Ubuntu en personlig grupp som `anna`, och då kan kollegorna inte läsa dem. Setgid gör att allt nytt ärver `ekonomi`.

**"Vad är ACL-masken och varför står det `#effective` i getfacl?"**
Masken är den högsta rättighet som namngivna ACL-poster och ägargruppen kan få. Posten för revision säger `r-x`, men på filer är masken `rw-`, så den effektiva rättigheten blir `r--`. Om någon kör `chmod g-w` på en fil ändras masken.

**"Hur skyddar skriptet lösenordet?"**
Det slumpas från `/dev/urandom`, skickas till `chpasswd` via stdin med den inbyggda `printf` så att det aldrig syns i `ps` eller i bash-historiken, skrivs aldrig till loggen och visas bara om utdata går till en terminal. Med `chage -d 0` måste användaren dessutom byta det vid första inloggning.

**Fler frågor att vara beredd på:**

- *Vad betyder idempotent och varför spelar det roll?* Samma körning ger samma slutläge oavsett hur många gånger den görs, så skriptet kan köras om efter ett avbrott utan dubbletter eller fel.
- *Varför `pipefail`?* Utan det räknas bara sista kommandot i en pipeline, så fel tidigare i kedjan döljs.
- *Vad betyder stort `X` i en default-ACL?* Det löses upp direkt mot katalogen när `setfacl` körs och lagras som `x`, vilket `getfacl` visar som `r-x`. Att nya filer ändå inte blir körbara beror på att program skapar filer med läge 666, så masken blir `rw-`.
- *Varför sticky bit om gruppen ändå får skriva?* Skrivrätt på en katalog betyder rätt att radera filer i den. Sticky bit begränsar radering till filens ägare.

---

## 8. Jämförelse och testresultat

Alla skript kördes med samma testsvit (49 tester) i Ubuntu 24.04.4 LTS den 16 september 2026.

### Testresultat i korthet

| Skript | Godkända tester |
|---|---|
| `nyanvandare.sh` (Claude) | **49 av 49** |
| `skapa_nyanvandare.sh` (härdad prompt, efter lagning) | **48 av 49** |
| `skapa_nyanvandare.sh` (härdad prompt, commit `197c62e`) | 44 av 49 |
| `gemini_nyanvandare.sh` (Gemini, original) | 30 av 49 |
| `gemini_lagad.sh` (Gemini, bara lösenordsraden lagad) | 36 av 49 |

Hela tabellen finns under "Testsviten" längre ned. Oscars variant löser uppgiften på ett annat sätt och har en egen testsvit med 25 tester (avsnitt 9): **16 av 25** i original och **25 av 25** efter sex lagningar.

### 8.1 `skapa_nyanvandare.sh` (härdad prompt)

Skriptet är välbyggt: tydliga exitkoder, dry-run utan root, helt bieffektsfri dry-run, loggfil 640 och en sammanfattning efter körning. Rättighetstesterna gav samma resultat som `nyanvandare.sh`.

**Lucka i sökvägsvalideringen (lagad).** Versionen i commit `197c62e` jämförde sökvägen mot en lista med exakta namn. I dry-run släpptes därför följande igenom, och hade gett `chmod 3770` på riktigt:

| Sökväg | Före lagning | Efter lagning |
|---|---|---|
| `/etc/` | släpps igenom | vägras (normaliseras till `/etc`) |
| `/srv/x/../../etc` | släpps igenom | vägras |
| `/tmp` | släpps igenom | vägras |
| `/srv`, `/opt` | släpps igenom | vägras |
| `/usr/local` | släpps igenom | vägras |
| `/srv/ekonomi/` | godkänns | godkänns (som `/srv/ekonomi`) |

`chmod 3770 /tmp` hade hindrat alla vanliga användare från att skapa temporära filer. Lagningen normaliserar sökvägen med `realpath -m` efter kontrollen av absolut sökväg och vägrar både systemkatalogerna och allt under dem:

```bash
KATALOG="$(realpath -m -- "${KATALOG}")"

case "${KATALOG}" in
  /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
  /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
    printf 'Fel: vägrar operera på skyddad systemkatalog: %q\n' "${KATALOG}" >&2
    exit "${E_VALIDERING}"
    ;;
esac
```

Samma skydd mot "allt under" infördes i `nyanvandare.sh` och `rollback_nyanvandare.sh`, som tidigare också bara kontrollerade exakta namn och därmed släppte igenom `/usr/local`.

**Shellcheck.** README:n angav att skriptet är shellcheck-rent, men shellcheck 0.9.0 (versionen i Ubuntu 24.04) gav SC2317 för `vid_fel`, eftersom verktyget inte ser att funktionen anropas via `trap`. En `disable`-kommentar lades till.

**Kvarstående avvikelse (medvetet val).** Lösenordet skrivs ut även när utdata går till en fil eller pipe, till exempel `sudo ./skapa_nyanvandare.sh | tee logg.txt`. Det är vad `PROMPT.md` kräver ("skriv ut det tillfälliga lösenordet EN gång till stdout"), så testet är strängare än specifikationen. Vill man skärpa det räcker en kontroll med `[[ -t 1 ]]`, som i `nyanvandare.sh`.

**Lösenordsraden är robust.** Rad 242 använder samma `tr | head`-mönster som kraschar Gemini-skriptet, men `|| true` och den efterföljande längdkontrollen gör den säker. Den kördes 20 gånger isolerat utan fel, och lösenordet som skrevs ut verifierades mot hashen i `/etc/shadow`.

**Pedagogisk detalj om `X`.** Kommentaren i skriptet och `PROMPT.md` säger att `rX` i default-ACL:n gör att framtida filer förblir `r--`. I praktiken löses `X` upp mot katalogen redan när `setfacl` körs och lagras som `r-x` (det syns i `getfacl`). Att nya filer blir `r--` beror på att program skapar filer med läge 666, så att ACL-masken blir `rw-`. Resultatet är detsamma, men förklaringen är värd att ha rätt vid en muntlig validering.

**Småsaker.** Felmeddelandet från trapen skrivs till stdout via `logga` i stället för stderr. Posten `g:ekonomi:rwx` är redundant eftersom `ekonomi` redan är ägargrupp och täcks av `group::rwx`, men den är ofarlig.

### 8.2 Gemini-skriptet

Geminis skript (bilaga A) har en korrekt rättighetsmodell, men går inte igenom en enda körning i sitt ursprungliga skick, och felet är tyst.

#### Tre allvarliga fel

**1. Lösenordsraden kraschar skriptet varje gång.**

```bash
temp_pass=$(tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c 12)
```

`head` stänger röret efter 12 tecken, `tr` försöker skriva mer och dödas av SIGPIPE (signal 13, alltså returkod 128 + 13 = 141). Med `pipefail` räknas hela kedjan som misslyckad och `set -e` avbryter. Raden testades isolerat fem gånger och gav 141 alla fem.

Följder i testet:

- Raden körs innan skriptet kontrollerar dry-run, så även `--dry-run` kraschar med kod 141 när användaren inte redan finns.
- Första körningen stannade direkt efter `useradd`, utan felmeddelande.
- Anna fanns men saknade lösenord (`!` i `/etc/shadow`), `chage -d 0` hade aldrig körts och katalogen fanns inte.
- Andra körningen rapporterade "slutförts framgångsrikt" eftersom Anna redan fanns, men kontot var fortfarande utan lösenord och utan tvingat byte.

**2. `trap` fungerar aldrig.** Utan `-E` ärvs inte ERR-trapen av funktioner, och all logik ligger i funktioner. Därför kom inget felmeddelande i fel 1. När `chmod`-raden byttes mot `false` avslutades skriptet med kod 1 utan ett ord.

**3. Inget skydd mot systemkataloger.** `-p /etc -g root` godkändes (testat med dry-run, när användaren redan fanns) och skulle köra `chmod 3770 /etc`, vilket gör att vanliga användare inte kommer åt `/etc` och systemet i praktiken slutar fungera. `/srv/x/../../etc` gick också igenom.

#### Mindre skillnader

| Område | Gemini-skriptet | `nyanvandare.sh` |
|---|---|---|
| Gruppmedlemskap | `-g`: `ekonomi` blir primärgrupp | `--groups`: tilläggsgrupp, egen primärgrupp behålls |
| Befintlig användare | Läggs inte till i gruppen | Kontrolleras och läggs till vid behov |
| Validering | Gruppnamn kontrolleras inte, användarnamn saknar längdgräns | Alla namn valideras, max 32 tecken |
| Flagga utan värde | `$2: unbound variable` | Tydligt meddelande |
| Loggfil | 644 root:root, läsbar för alla | 640 root:adm |
| Vad loggas | Beskrivningar, men inga fel och inga kommandon | Varje kommando och varje fel med tidsstämpel |
| Lösenord i utdata | Skrivs alltid ut, även vid omdirigering till fil | Bara om utdata går till en terminal |
| ACL vid omkörning | Bara själva katalogen | Rekursivt, befintliga filer får också läsrätt |
| Argumenttolkning | På toppnivå, utanför funktioner | I funktionen `tolka_argument` |
| Flaggor | `-d` = dry-run, `-p` = sökväg | `-d` = katalog, `-n` = dry-run |

Primärgruppsvalet är mer än en stilfråga. I testet visade `getent group ekonomi` en tom medlemslista trots att Anna tillhör gruppen, eftersom primärgrupper inte listas i `/etc/group`. Dessutom vägrar `groupdel ekonomi` så länge Anna finns.

Raden `setfacl -d -m g:ekonomi:rwx` är ofarlig men överflödig, eftersom `ekonomi` redan är ägargrupp via setgid och täcks av `default:group::rwx`. Den ger en dubbelpost i `getfacl`.

#### Det som är bra

Strukturen är tydlig, gruppskapandet i en loop är idempotent, root kontrolleras först och lösenordet hamnar aldrig i loggfilen. Med lagad lösenordsrad gav rättighetstesterna samma resultat som `nyanvandare.sh`: `drwxrws--T+`, nya filer `660 anna:ekonomi`, revision får `r--`, kollegan kan skriva men inte radera och utomstående nekas.

#### Minsta lagningen

```bash
set -Eeuo pipefail

# i skapa_anvandare
temp_pass=$(head -c 9 /dev/urandom | base64)

# i validera_indata
if [[ "$KATALOG" == *..* ]]; then
    echo "FEL: Sökvägen får inte innehålla '..'." >&2; exit 1
fi
KATALOG="${KATALOG%/}"
case "$KATALOG" in
    ""|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
    /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
        echo "FEL: Vägrar att ändra systemkatalogen '${KATALOG:-/}'." >&2; exit 1 ;;
esac
```

Byts dessutom `-g "$GRUPP"` mot `-G "$GRUPP"` i `useradd` blir beteendet i praktiken detsamma som i `nyanvandare.sh`.

### 8.3 Testsviten

Testsviten [`jamfor_skript.sh`](jamfor_skript.sh) (bilaga B) kör exakt samma 49 tester mot varje skript den får som argument, i en ren miljö för varje skript. Den läser skriptets hjälptext för att avgöra om katalogflaggan heter `--dir` eller `--path`.

**Kör endast i en test-VM**, eftersom sviten skapar och tar bort användare, grupper och `/srv/ekonomi`.

```bash
cd linux-anvandare-acl/jamforelse
sudo apt install acl

# Versionen av skapa_nyanvandare.sh före lagningen (valfritt)
git show 197c62e:linux-anvandare-acl/skapa_nyanvandare.sh > skapa_nyanvandare_fore_fix.sh

sudo bash jamfor_skript.sh nyanvandare.sh ../skapa_nyanvandare.sh \
    skapa_nyanvandare_fore_fix.sh gemini_nyanvandare.sh gemini_lagad.sh | tee testresultat.txt
```

`gemini_lagad.sh` skapades med ett enda byte, för att se vad som återstår när kraschen är borta:

```bash
sed 's/temp_pass=$(tr .*$/temp_pass=$(head -c 9 \/dev\/urandom | base64)/' \
    gemini_nyanvandare.sh > gemini_lagad.sh
```

**Vad sviten testar:**

| Grupp | Innehåll |
|---|---|
| Dry-run och validering | Att dry-run inte ändrar något, att farliga värden avvisas (`/etc`, `/etc/`, `/etc` via `..`, `/tmp`, katalog under `/usr`), att ogiltiga namn avvisas och att en flagga utan värde ger ett begripligt fel |
| Körning 1 | Returkod, användare, lösenord, tvingat byte, katalog, att lösenordet inte läcker till omdirigerad utdata eller loggfil |
| Körning 2 | Idempotens: returkod och att kontot är i korrekt skick |
| Struktur | Mode, ägare, ACL, default-ACL, gruppmedlemskap och loggfilens rättigheter |
| Rättighetsmatris | Samma tolv åtkomsttester som i avsnitt 5 |
| Arv | Nya filers rättigheter, effektiv ACL och setgid på underkataloger |
| Befintlig användare | Att en användare som redan finns läggs till i gruppen |
| Felhantering | Att `trap` rapporterar radnummer när ett kommando fallerar |

Tre saker i sviten är värda att förstå:

- **Lösenordsläckor** upptäcks genom att varje ord i utdata och i loggfilen prövas mot hashen i `/etc/shadow` (med Pythons `crypt`, som använder systemets libxcrypt och klarar yescrypt). Formatet på utskriften spelar därför ingen roll. Ett tidigare mönster letade efter texten "lösenord för" och missade `skapa_nyanvandare.sh`, som skriver `Lösenord : ...`.
- **Valideringstesterna** godkänns bara om skriptet avbryter med felkod *innan* det börjar arbeta (ingen `DRY-RUN`-rad i utdata). Utan det kriteriet blev Gemini-originalet felaktigt godkänt, eftersom det kraschade med kod 141 längre fram och den koden tolkades som "vägrade".
- **Valideringstesterna körs bara om dry-run bevisligen inte ändrar systemet**, så att ett skript med trasig dry-run aldrig får chansen att köra `chmod 3770 /etc` på riktigt.

**Resultat (Ubuntu 24.04.4 LTS, 2026-09-16).** `skapa_nyanvandare_fore_fix.sh` är versionen från commit `197c62e`.

| Test | Förväntat | nyanvandare.sh | skapa_nyanvandare.sh | skapa_nyanvandare_fore_fix.sh | gemini_nyanvandare.sh | gemini_lagad.sh |
|---|---|---|---|---|---|---|
| Dry-run: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Dry-run: inget ändras på systemet | nej | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar /etc | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc/ (avslutande snedstreck) | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc via '..' | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /tmp | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar katalog under /usr | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar relativ sökväg | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar versaler i användarnamn | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar användarnamn > 32 tecken | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar ogiltigt gruppnamn | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Tydligt fel vid flagga utan värde | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Körning 1: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Körning 1: användaren skapad | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 1: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: katalogen skapad | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Lösenord visas inte i omdirigerad utdata | ja | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | Godkänt | **UNDERKÄNT** (nej) |
| Lösenord finns inte i loggfilen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 2: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Katalog: mode | 3770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Katalog: ägare | root:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| ACL: revision r-x på katalogen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: revision r-x | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: övriga --- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna i ekonomi (id) | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna listad i getent group ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Loggfil inte läsbar för alla | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| anna skapar fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna skapar underkatalog | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega läser annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega skriver i annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega raderar annas fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor listar katalogen | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor läser fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skapar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skriver i fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor raderar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående listar katalogen | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående läser fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: mode och ägare | 660 anna:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: revision effektivt r-- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Underkatalog: ärver setgid | 2770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna raderar egen fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare läggs i ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| trap rapporterar fel med radnummer | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |

**Tolkning:**

- Alla tre skripten ger samma resultat i rättighetsmatrisen och arvstesterna. Skillnaderna ligger i validering, felhantering och robusthet.
- `skapa_nyanvandare.sh` föll före lagningen på fyra sökvägstester. Efter lagningen återstår bara lösenordsutskriften, som är ett medvetet val enligt `PROMPT.md`.
- Gemini-originalet klarar rättighetsmatrisen enbart därför att andra körningen hoppar över lösenordsraden (Anna finns redan) och då hinner skapa katalogen. Kontot saknar ändå lösenord.
- När kraschen i Gemini-skriptet är lagad återstår 13 underkända tester: fem sökvägstester, namnlängd, gruppnamn, flagga utan värde, lösenord i omdirigerad utdata, primärgrupp i stället för tilläggsgrupp (två tester), loggfilens rättigheter och `trap`.

### 8.4 Lärdom

`pipefail` tillsammans med `head` är en klassisk fälla: allt som läser från en oändlig källa (`/dev/urandom`, `yes`) och klipps av med `head` kommer att misslyckas. Läs i stället ett bestämt antal byte direkt med `head -c` först i kedjan, så behöver inget kommando skriva till ett stängt rör. Alternativet är att fånga felet uttryckligen, som `skapa_nyanvandare.sh` gör med `|| true` följt av en längdkontroll.

En andra lärdom: en lista med exakta katalognamn är ett svagt skydd. Normalisera sökvägen först och vägra hela underträd.

---

## 9. Oscars variant

Oscars skript (bilaga D) tolkar uppgiften annorlunda än de andra. I stället för en delad avdelningskatalog med ACL skapar det en användare via interaktiva menyer (avdelning och roll), lägger användaren i avdelningsgruppen och skapar fyra privata mappar i hemkatalogen plus en välkomstfil.

Skriptet har inga flaggor och kan därför inte köras med `jamfor_skript.sh`. Det har i stället en egen svit, [`testa_oscar.sh`](testa_oscar.sh) (bilaga E), som matar in svaren via stdin. Siffrorna är inte direkt jämförbara med de 49 testerna i avsnitt 8.

### 9.1 Tolkningen av uppgiften

"Sätt rättighetsstrukturer för en ny katalog" går att läsa på flera sätt. Claude och Gemini fick en detaljerad prompt som bestämde tolkningen (delad katalog, setgid, sticky bit, ACL). Oscars variant visar hur olika resultatet blir när uppgiften inte är preciserad: skriptet fokuserar på privata mappar och användarvänlighet i stället för delad åtkomst.

### 9.2 Det som är bra

- Lätt att läsa, med tydliga numrerade kommentarer.
- Användarvänligt: menyer, välkomstfil och en tydlig sammanfattning.
- Root kontrolleras först.
- Ogiltiga menyval avbryter **innan** något ändras på systemet.
- En befintlig användare avvisas i stället för att skrivas över.
- Fullständigt namn sparas i kommentarfältet (`-c`), vilket de andra skripten saknar.
- Rätt val av `useradd -G` (tilläggsgrupp), till skillnad från Gemini som valde `-g`.
- Felkoden från `useradd` kontrolleras.
- De privata mapparna är korrekt skyddade med 700.

### 9.3 Fynd, bekräftade i testerna

**1. Kontot går inte att logga in med.** Skriptet sätter aldrig något lösenord, så kontot är låst (`passwd -S anna` visar `L`, och `/etc/shadow` innehåller `!`).

**2. Hela avdelningen kan läsa i hemkatalogen.** Raden

```bash
chown -R "$USERNAME:$DEPARTMENT" "$USER_HOME"
```

ger hemkatalogen gruppen `ekonomi`. Ubuntu 24.04 skapar hemkataloger med mode 750 (`HOME_MODE` i `/etc/login.defs`), så alla i avdelningen får läs- och inträdesrätt. I testet kunde en kollega lista Annas hemkatalog och läsa `anteckningar.txt` som Anna skapat där. Mapparna med 700 och `VÄLKOMMEN.txt` med 600 var däremot skyddade. En vanlig hemkatalog har användarens egen grupp (`kollega:kollega` i testet) och är därför stängd för andra.

Det här är ett bra exempel för redovisningen: raden ser helt rimlig ut, och välkomstfilen säger att mapparna är privata, men rättighetsmodellen öppnar ändå hemkatalogen för hela avdelningen.

**3. Den nya användaren listas som "annan användare".** `getent group ekonomi` innehåller alltid den nya användaren själv, så grenen "Inga andra användare finns ännu" körs aldrig.

**4. Ingen validering av användarnamn.** `Erik` med versal godkändes, eftersom `useradd` på Ubuntu 24.04 tillåter versaler (det är `adduser` som stoppar dem).

**5. Rester vid fel.** Avdelningsgruppen skapas innan `useradd` körs. När `useradd` misslyckas (till exempel med kolon i det fullständiga namnet) ligger gruppen kvar.

**6. `read` utan `-r`.** `Per\Olsson` sparades som `PerOlsson`. `shellcheck` varnar för detta (SC2162).

**Övrigt, inte testat som fel:**

- Rollen påverkar inga rättigheter. En "Administratör" eller "Chef" får exakt samma behörighet som en "Medarbetare"; rollen skrivs bara i välkomstfilen.
- Funktionen `paus` definieras men används aldrig.
- `clear` skriver `TERM environment variable not set.` när skriptet körs utan terminal.
- Skriptet är interaktivt och kan därför inte användas i automatisering utan att svaren matas in via stdin.
- Ingen loggning och ingen dry-run.

### 9.4 Testresultat

| Test | Förväntat | oscar_skapa_anvandare.sh |
|---|---|---|
| Körning: returkod | 0 | Godkänt |
| Användaren skapad | ja | Godkänt |
| Fullständigt namn sparat | Anna Andersson | Godkänt |
| Skal | /bin/bash | Godkänt |
| Tilläggsgrupp ekonomi (id) | ja | Godkänt |
| Listad i getent group ekonomi | ja | Godkänt |
| Privata mappar: finns, 700, ägs av anna | ja | Godkänt |
| VÄLKOMMEN.txt: mode | 600 | Godkänt |
| Utskrift: nya användaren listas inte som 'annan' | ja | **UNDERKÄNT** (nej) |
| Lösenord satt (kan logga in) | ja | **UNDERKÄNT** (nej) |
| Lösenordsbyte krävs | ja | **UNDERKÄNT** (nej) |
| Kollega listar annas hemkatalog | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser fil i hemkatalogens rot | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser .bashrc | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser Dokument/cv.txt | NEKAS | Godkänt |
| Kollega läser VÄLKOMMEN.txt | NEKAS | Godkänt |
| Utomstående listar annas hemkatalog | NEKAS | Godkänt |
| Anna skriver i Dokument | OK | Godkänt |
| Befintlig användare avvisas | ja | Godkänt |
| Ogiltig avdelning: avbryter utan ändringar | ja | Godkänt |
| Ogiltig roll: avbryter utan ändringar | ja | Godkänt |
| Versaler i användarnamn avvisas | ja | **UNDERKÄNT** (nej) |
| Misslyckad useradd lämnar ingen grupp kvar | ja | **UNDERKÄNT** (nej) |
| Backslash i namn bevaras | Per\Olsson | **UNDERKÄNT** (PerOlsson) |
| Icke-root avvisas | ja | Godkänt |

oscar_skapa_anvandare.sh: 16 av 25 godkända

### 9.5 Lagningar

Sex ändringar räcker för att få **25 av 25**. Samma testsvit kördes mot [`oscar_lagad.sh`](oscar_lagad.sh).

| Fynd | Lagning |
|---|---|
| Inget lösenord | Slumpat lösenord via `chpasswd`, `chage -d 0`, lösenordet visas i sammanfattningen |
| Hemkatalogen öppen för avdelningen | `chown -R "$USERNAME:"` (tomt efter kolon ger användarens egen grupp) |
| Användaren listas som "annan" | `grep -vx "$USERNAME"` filtrerar bort den nya användaren |
| Ingen validering | Regex för användarnamn direkt efter inmatningen |
| Grupp kvar vid fel | Flaggan `GRUPP_SKAPAD` och `groupdel` om `useradd` misslyckas |
| Backslash försvinner | `read -r` |

```diff
--- oscar_skapa_anvandare.sh
+++ oscar_lagad.sh
@@ -22,7 +22,7 @@
 # ----------------------------------------------------------
 
 paus() {
-    read -p "Tryck Enter för att fortsätta..."
+    read -r -p "Tryck Enter för att fortsätta..."
 }
 
 
@@ -37,8 +37,13 @@
 echo "=============================================="
 echo
 
-read -p "Ange användarnamn: " USERNAME
-read -p "Ange användarens fullständiga namn: " FULLNAME
+read -r -p "Ange användarnamn: " USERNAME
+read -r -p "Ange användarens fullständiga namn: " FULLNAME
+
+if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
+    echo "Fel: Ogiltigt användarnamn. Använd små bokstäver, siffror, _ och -, max 32 tecken."
+    exit 1
+fi
 
 
 # ----------------------------------------------------------
@@ -64,7 +69,7 @@
 echo "4) Produktion"
 echo
 
-read -p "Ditt val: " DEPARTMENT_CHOICE
+read -r -p "Ditt val: " DEPARTMENT_CHOICE
 
 case "$DEPARTMENT_CHOICE" in
     1)
@@ -102,7 +107,7 @@
 echo "4) Tekniker"
 echo
 
-read -p "Ditt val: " ROLE_CHOICE
+read -r -p "Ditt val: " ROLE_CHOICE
 
 case "$ROLE_CHOICE" in
     1)
@@ -128,8 +133,10 @@
 # 7. Skapa avdelningsgruppen om den inte finns
 # ----------------------------------------------------------
 
+GRUPP_SKAPAD=0
 if ! getent group "$DEPARTMENT" > /dev/null; then
     groupadd "$DEPARTMENT"
+    GRUPP_SKAPAD=1
     echo "Gruppen '$DEPARTMENT' skapades."
 else
     echo "Gruppen '$DEPARTMENT' finns redan."
@@ -149,10 +156,16 @@
 
 if [ $? -ne 0 ]; then
     echo "Fel: Kunde inte skapa användaren."
+    [ "$GRUPP_SKAPAD" -eq 1 ] && groupdel "$DEPARTMENT"
     exit 1
 fi
 
 
+TEMP_PASS=$(head -c 12 /dev/urandom | base64)
+printf '%s:%s\n' "$USERNAME" "$TEMP_PASS" | chpasswd
+chage -d 0 "$USERNAME"
+
+
 # ----------------------------------------------------------
 # 9. Skapa privata mappar
 # ----------------------------------------------------------
@@ -169,7 +182,7 @@
 # 10. Ge användaren ägarskap över mapparna
 # ----------------------------------------------------------
 
-chown -R "$USERNAME:$DEPARTMENT" "$USER_HOME"
+chown -R "$USERNAME:" "$USER_HOME"
 
 
 # ----------------------------------------------------------
@@ -223,7 +236,7 @@
 # 13. Ändra ägare på välkomstfilen
 # ----------------------------------------------------------
 
-chown "$USERNAME:$DEPARTMENT" "$USER_HOME/VÄLKOMMEN.txt"
+chown "$USERNAME:" "$USER_HOME/VÄLKOMMEN.txt"
 
 chmod 600 "$USER_HOME/VÄLKOMMEN.txt"
 
@@ -232,7 +245,7 @@
 # 14. Hitta andra användare på samma avdelning
 # ----------------------------------------------------------
 
-OTHER_USERS=$(getent group "$DEPARTMENT" | cut -d: -f4)
+OTHER_USERS=$(getent group "$DEPARTMENT" | cut -d: -f4 | tr ',' '\n' | grep -vx "$USERNAME")
 
 
 # ----------------------------------------------------------
@@ -249,6 +262,8 @@
 echo "Avdelning  : $DEPARTMENT_NAME"
 echo "Roll       : $ROLE"
 echo
+echo "Tillfälligt lösenord: $TEMP_PASS (måste bytas vid första inloggning)"
+echo
 echo "Privata mappar:"
 echo "  /home/$USERNAME/Dokument"
 echo "  /home/$USERNAME/Bilder"
@@ -262,7 +277,7 @@
 if [ -z "$OTHER_USERS" ]; then
     echo "Inga andra användare finns ännu."
 else
-    echo "$OTHER_USERS" | tr ',' '\n'
+    echo "$OTHER_USERS"
 fi
 
 echo
```

### 9.6 Jämförelse av alla fyra

| Egenskap | Claude (`nyanvandare.sh`) | Härdad prompt (`skapa_nyanvandare.sh`) | Gemini | Oscar |
|---|---|---|---|---|
| Delad avdelningskatalog | Ja | Ja | Ja | Nej |
| Setgid och sticky bit | Ja | Ja | Ja | Nej |
| ACL för läsgrupp | Ja | Ja | Ja | Nej |
| Privata mappar i hemkatalogen | Nej | Nej | Nej | Ja |
| Hemkatalogen stängd för andra | Ja | Ja | Ja | Nej |
| Lösenord och tvingat byte | Ja | Ja | Nej (kraschar) | Nej (saknas) |
| Fullständigt namn sparas | Nej | Nej | Nej | Ja |
| Tilläggsgrupp | Ja (`-G`) | Ja (`usermod -aG`) | Nej (`-g`) | Ja (`-G`) |
| Indata | Argument | Argument | Argument | Interaktiva menyer |
| Validering av användarnamn | Ja | Ja | Delvis | Nej |
| Skydd mot systemkataloger | Ja | Ja | Nej | Ej relevant (fast sökväg) |
| Dry-run | Ja | Ja, även utan root | Ja, men kraschar | Nej |
| Loggning | Ja | Ja | Delvis | Nej |
| Omkörning | Idempotent | Idempotent | Delvis | Avbryter om användaren finns |
| Felhantering | `set -Eeuo pipefail` och `trap` | `set -Eeuo pipefail` och `trap` | `trap` som aldrig triggas | Kontroll efter `useradd` |
| Användarvänlighet | Hjälptext | Hjälptext och sammanfattning | Hjälptext | Menyer, välkomstfil |
| Testresultat | 49 av 49 | 48 av 49 | 30 av 49 | 16 av 25 (egen svit) |
| Efter minsta lagning | | | 36 av 49 | 25 av 25 |

Ingen av varianterna är bäst på allt. Skripten från Claude och den härdade prompten är säkrast och går att automatisera, Oscars är mest användarvänligt och det enda som sparar det fullständiga namnet, och Gemini har samma struktur som Claude men med fel som gör att det inte fungerar.

### 9.7 Så kör du testerna

Kör endast i en test-VM, eftersom sviten skapar och tar bort användare och grupperna administration, it, ekonomi och produktion.

```bash
cd linux-anvandare-acl/jamforelse
sudo bash testa_oscar.sh oscar_skapa_anvandare.sh | tee testresultat_oscar.txt
sudo bash testa_oscar.sh oscar_lagad.sh
```

---

## 10. Underlag för redovisning

Redovisningskraven: visa två prompts och förklara skillnaden i utdata, och visa ett konkret exempel där AI:n hallucinerade eller där ett kommandos flaggor behövde dubbelkollas manuellt.

### 10.1 Två prompts och skillnaden i utdata

Det finns två naturliga par att visa, beroende på vad gruppen vill betona:

- **Uppgiften (1.1) mot den avancerade prompten (1.3):** hur mycket en detaljerad prompt styr resultatet.
- **Den avancerade prompten (1.3) mot den härdade prompten (1.4, [`../PROMPT.md`](../PROMPT.md)):** hur man skärper en prompt utifrån fel som testerna hittat.

Det här syns i utdatan:

- **Prompten styr utdatan.** Claude och Gemini fick den avancerade prompten och gav nästan identisk struktur: samma standardvärden, loggfil, dry-run, funktioner och 3770 med ACL. Oscars variant, som inte bygger på den prompten, blev ett helt annat skript med menyer och privata mappar.
- **Prompten styr även felen.** Den avancerade prompten krävde `set -euo pipefail`. Gemini kopierade det rakt av, och därför fungerar dess `trap` aldrig inuti funktioner. Claude lade till `-E` och förklarade varför. Den härdade prompten kräver `-E` uttryckligen. En brist i prompten gick alltså rakt in i koden hos den AI som följde den bokstavligt.
- **Mätbar skillnad:** med samma 49 tester fick Claude 49, den härdade prompten 48 och Gemini 30. Oscars variant fick 16 av 25 i en egen svit, eftersom den löser en annan tolkning av uppgiften.

Oscars prompt (1.6) är ett tredje talande exempel: den ställdes i vardagsspråk till ChatGPT, utan de tekniska kraven, och gav därför en helt annan tolkning av uppgiften. Det visar att det inte bara är AI-modellen som avgör resultatet, utan minst lika mycket hur prompten formuleras.

### 10.2 Exempel 1: kod som ser rätt ut men aldrig fungerar

Gemini skrev följande och kommenterade att lösenordet var säkert:

```bash
temp_pass=$(tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c 12)
```

Tillsammans med `pipefail` kraschar raden varje gång med kod 141 (SIGPIPE). Resultatet blir ett konto utan lösenord, och andra körningen rapporterar ändå att allt gick bra. Livedemo på tio sekunder:

```bash
bash -c 'set -euo pipefail; x=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12); echo ok'; echo "rc=$?"
# rc=141, "ok" skrivs aldrig ut

bash -c 'set -euo pipefail; x=$(head -c 9 /dev/urandom | base64); echo ok'; echo "rc=$?"
# ok, rc=0
```

Strikt taget är det inget påhittat kommando, utan ett självsäkert påstående om beteende som inte stämmer. Samma sak gäller Geminis kommentar om att `trap` rapporterar fel på en specifik rad: den triggas aldrig.

### 10.3 Exempel 2: en rimlig men felaktig förklaring

Kommentaren i `skapa_nyanvandare.sh` och `PROMPT.md` säger att `rX` i default-ACL:n gör att framtida filer förblir `r--`. I praktiken löses `X` upp mot katalogen redan när `setfacl` körs och lagras som `r-x`, vilket syns i `getfacl`. Att nya filer ändå blir `r--` beror på ACL-masken (avsnitt 8.1). Resultatet stämmer, men förklaringen är fel, och det är precis den sortens fel som avslöjas vid en muntlig validering.

### 10.4 Exempel 3: flaggor som behövde dubbelkollas

| Flagga | Vad den faktiskt gör | Hur det kontrollerades |
|---|---|---|
| `useradd -g` / `-G` | `-g` sätter primärgrupp, `-G` tilläggsgrupp. Gemini valde `-g`, så Anna syntes inte i `getent group ekonomi` | `man useradd`, `id anna`, `getent group ekonomi` |
| `set -E` | Krävs för att ERR-trapen ska ärvas av funktioner | `man bash` (errtrace), test med `false` |
| `setfacl -d` / `rX` | `-d` sätter default-ACL. Stort `X` löses upp mot målet när kommandot körs | `man setfacl`, `getfacl` och `getfacl -e` på en ny fil |
| `chage -d 0` | Tvingar lösenordsbyte vid nästa inloggning | `chage -l anna` |
| `chown user:grupp` / `user:` | Grupp efter kolon sätts på allt; tomt efter kolon ger användarens egen grupp. Oscars `-R` med avdelningsgrupp öppnade hemkatalogen | `man chown`, `ls -la /home/anna`, åtkomsttest som kollega |
| `read -r` | Utan `-r` tolkas backslash som specialtecken och försvinner | `shellcheck` (SC2162), test med `Per\Olsson` |
| `useradd` och versaler | Ubuntu 24.04:s `useradd` godkänner `Erik`; det är `adduser` som stoppar versaler | Test i VM |
| `realpath -m` | Normaliserar `/etc/` och `/srv/x/../../etc` till `/etc` även om sökvägen inte finns | `man realpath`, valideringstesterna i avsnitt 8.3 |

### 10.5 Exempel 4: AI-genererade skript och tester behövde också rättas

- Sökvägsskyddet i både `nyanvandare.sh` och `skapa_nyanvandare.sh` jämförde bara mot exakta namn och släppte igenom bland annat `/etc/`, `/tmp` och `/usr/local`. Det upptäcktes först när testsviten utökades (avsnitt 8.1).
- README:n för `skapa_nyanvandare.sh` påstod att skriptet var shellcheck-rent, men shellcheck 0.9.0 gav SC2317.
- I Claudes första skript skapades loggfilen med rättigheterna 644 innan skyddet hann köras. Det hittades vid testkörningen.
- Den första testsviten godkände felaktigt Geminis validering, eftersom kraschen med kod 141 tolkades som att skriptet vägrade. Felet upptäcktes för att resultatet såg för bra ut, och kriteriet fick skärpas.

Lärdomen är inte att en AI har rätt och en annan fel, utan att all AI-kod måste testas, även testerna och dokumentationen.

### 10.6 Förslag på upplägg (cirka 7 minuter)

1. Uppgiften och de två prompterna (1,5 min)
2. Skillnaden i utdata: Claude och Gemini mot Oscar, och att felen följde med prompten (1,5 min)
3. Livedemo av kod 141 (1 min)
4. Flaggtabellen, med `-g`/`-G` och Oscars `chown -R` som huvudexempel (1,5 min)
5. Resultat: 49, 48 och 30 av 49, Oscar 16 av 25 i egen svit, samt att även tester och dokumentation hade fel (1 min)
6. Lärdom: verifiera med `man`, testa i en VM, lita inte på kommentarer (0,5 min)

---

## 11. Bilaga A: Gemini-skriptet

[`gemini_nyanvandare.sh`](gemini_nyanvandare.sh), oförändrat som det såg ut när jämförelsen gjordes. **Kör det inte utan lagningarna i avsnitt 8.2.**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Trap för felrapportering vid fel på en specifik rad
trap 'echo "[FEL] Skriptet misslyckades på rad $LINENO vid kommando: $BASH_COMMAND" >&2' ERR

# Standardvärden för variabler
ANVANDARE="anna"
GRUPP="ekonomi"
KATALOG="/srv/ekonomi"
REVISION_GRUPP="revision"
LOGGFIL="/var/log/nyanvandare.log"
DRY_RUN=0

# Hjälpfunktion / Usage
visa_hjalp() {
    cat << EOF
Användning: sudo $0 [FLAGGOR]

Beskrivning:
  Skapar en användare, tilldelar grupper samt konfigurerar en delad katalog 
  med POSIX-rättigheter (setgid, sticky bit) och POSIX ACL.

Flaggor:
  -u, --user USERNAME     Ange användarnamn (Standard: $ANVANDARE)
  -g, --group GROUPNAME   Ange huvudgrupp (Standard: $GRUPP)
  -p, --path PATH         Ange absolut sökväg till katalogen (Standard: $KATALOG)
  -d, --dry-run           Visa vad som skulle göras utan att utföra ändringar
  -h, --help              Visa denna hjälptext
EOF
}

# Argumenthantering
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            ANVANDARE="$2"
            shift 2
            ;;
        -g|--group)
            GRUPP="$2"
            shift 2
            ;;
        -p|--path)
            KATALOG="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            visa_hjalp
            exit 0
            ;;
        *)
            echo "FEL: Okänd parameter '$1'" >&2
            visa_hjalp
            exit 1
            ;;
    esac
done

# Centraliserad loggningsfunktion
logga() {
    local meddelande="$1"
    local tidstampel
    tidstampel=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$tidstampel] $meddelande"
    
    if [[ $DRY_RUN -eq 0 ]]; then
        echo "[$tidstampel] $meddelande" >> "$LOGGFIL"
    fi
}

# Funktion för att köra kommandon eller enbart simulera dem vid --dry-run
exekvera() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[DRY-RUN] Skulle kört: $*"
    else
        "$@"
    fi
}

# Indatavalidering och säkerhetskontroll
validera_indata() {
    if [[ $EUID -ne 0 ]]; then
        echo "FEL: Skriptet måste köras med root-rättigheter (sudo)." >&2
        exit 1
    fi

    if [[ ! "$KATALOG" =~ ^/ ]]; then
        echo "FEL: Katalogsökvägen '$KATALOG' måste vara en absolut sökväg (starta med /)." >&2
        exit 1
    fi

    if [[ ! "$ANVANDARE" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "FEL: Ogiltigt användarnamn '$ANVANDARE'. Använd endast gemener, siffror, Bindestreck och understreck." >&2
        exit 1
    fi
}

# Säkerställ att acl-paketet är installerat
sakerstall_beroenden() {
    if ! command -v setfacl &> /dev/null; then
        logga "Verktyget 'acl' saknas. Installerar..."
        exekvera apt-get update -qq
        exekvera apt-get install -y acl -qq
    fi
}

# Funktion för skapande av grupper (idempotent)
skapa_grupper() {
    local grupper=("$GRUPP" "$REVISION_GRUPP")
    for g in "${grupper[@]}"; do
        if getent group "$g" > /dev/null 2>&1; then
            logga "Gruppen '$g' finns redan. Hoppar över skapande."
        else
            logga "Skapar gruppen '$g'..."
            exekvera groupadd "$g"
        fi
    done
}

# Funktion för skapande av användare (idempotent)
skapa_anvandare() {
    if id -u "$ANVANDARE" > /dev/null 2>&1; then
        logga "Användaren '$ANVANDARE' finns redan. Hoppar över skapande."
    else
        logga "Skapar användaren '$ANVANDARE' med hemkatalog och /bin/bash..."
        exekvera useradd -m -s /bin/bash -g "$GRUPP" "$ANVANDARE"
        
        # Generera ett säkert tillfälligt lösenord (12 tecken)
        local temp_pass
        temp_pass=$(tr -dc 'A-Za-z0-9!@#$%' < /dev/urandom | head -c 12)
        
        if [[ $DRY_RUN -eq 0 ]]; then
            echo "$ANVANDARE:$temp_pass" | chpasswd
            # Tvinga lösenordsbyte vid första inloggning
            chage -d 0 "$ANVANDARE"
            
            logga "Användaren '$ANVANDARE' har skapats. Lösenord satt till utgånget (kräver byte vid inloggning)."
            echo "------------------------------------------------------------------"
            echo " Viktigt: Tillfälligt lösenord för $ANVANDARE: $temp_pass"
            echo " (Spara detta! Det loggas INTE till loggfilen av säkerhetsskäl)."
            echo "------------------------------------------------------------------"
        else
            echo "[DRY-RUN] Skulle ha satt ett slumpmässigt lösenord och kört 'chage -d 0 $ANVANDARE'."
        fi
    fi
}

# Funktion för att sätta rättigheter och ACL (idempotent)
satt_rattigheter() {
    if [[ ! -d "$KATALOG" ]]; then
        logga "Skapar katalogen '$KATALOG'..."
        exekvera mkdir -p "$KATALOG"
    else
        logga "Katalogen '$KATALOG' existerar redan."
    fi

    logga "Sätter ägarskap root:$GRUPP på '$KATALOG'..."
    exekvera chown root:"$GRUPP" "$KATALOG"

    # Sätter POSIX-rättigheter: 3770 (Setgid = 2000, Sticky bit = 1000, Owner = 7, Group = 7, Others = 0)
    logga "Sätter POSIX-rättigheter 3770 (Setgid, Sticky Bit, rwxrwx---)..."
    exekvera chmod 3770 "$KATALOG"

    logga "Konfigurerar POSIX ACL för gruppen '$REVISION_GRUPP'..."
    # Läs- och exekveringsrättighet för revisionsgruppen på själva katalogen
    exekvera setfacl -m g:"$REVISION_GRUPP":r-x "$KATALOG"
    
    # Standard-ACL (Default ACL) för framtida filer och underkataloger
    exekvera setfacl -d -m g:"$REVISION_GRUPP":r-x "$KATALOG"
    exekvera setfacl -d -m g:"$GRUPP":rwx "$KATALOG"
    exekvera setfacl -d -m u::rwx "$KATALOG"
    exekvera setfacl -d -m o::--- "$KATALOG"
}

# Huvudfunktion
main() {
    validera_indata
    sakerstall_beroenden
    skapa_grupper
    skapa_anvandare
    satt_rattigheter
    logga "Exekveringen har slutförts framgångsrikt."
}

main "$@"
```

---

## 12. Bilaga B: Testsviten `jamfor_skript.sh`

Passerar `shellcheck` utan anmärkningar.

```bash
#!/usr/bin/env bash
#
# jamfor_skript.sh
# Kör samma testsvit mot ett eller flera skript som löser uppgiften
# "Skapa en användare och sätt rättighetsstrukturer för en ny katalog"
# och skriver en sammanfattning som Markdown-tabell.
#
# VARNING: Kör endast i en test-VM. Testsviten skapar och tar bort
# användarna anna, kollega, revisor, utomstaende, befintlig och drytest,
# grupperna ekonomi och revision, katalogerna /srv/ekonomi och /srv/drytest
# samt loggfilen /var/log/nyanvandare.log.
#
# Användning:
#   sudo ./jamfor_skript.sh ./nyanvandare.sh ./gemini_nyanvandare.sh | tee testresultat.txt
#   sudo ./jamfor_skript.sh -y ...   (hoppa över bekräftelsen)
#
# Skripten som testas måste stödja -u, -g, --dry-run samt --dir eller --path.

# Medvetet utan -e: tester ska kunna misslyckas utan att sviten avbryts
set -uo pipefail

# UTF-8 så att å, ä och ö räknas som ett tecken vid kolumnjustering
if locale -a 2>/dev/null | grep -qiE '^c\.utf-?8$'; then
    export LC_ALL=C.UTF-8
fi

KATALOG="/srv/ekonomi"
LOGGFIL="/var/log/nyanvandare.log"
TESTANVANDARE=(anna kollega revisor utomstaende befintlig drytest)
TIMEOUT=120

declare -A RESULTAT=() FORVANTAT=() KAND=() GODKANDA=()
declare -a TESTNAMN=() SKRIPT_ID=()
ARBETSKATALOG="$(mktemp -d)"
UT="$ARBETSKATALOG/ut.txt"
FEL="$ARBETSKATALOG/fel.txt"
RC=0
SOKVAGSFLAGGA="--dir"
trap 'rm -rf "$ARBETSKATALOG"' EXIT

# ---------- Kontroller ----------

if [[ "$EUID" -ne 0 ]]; then
    echo "Kör som root: sudo $0 skript1 [skript2 ...]" >&2
    exit 1
fi

BEKRAFTA=1
if [[ "${1:-}" == "-y" ]]; then
    BEKRAFTA=0
    shift
fi

if (( $# < 1 )); then
    echo "Användning: sudo $0 [-y] skript1 [skript2 ...]" >&2
    exit 1
fi

for s in "$@"; do
    if [[ ! -f "$s" ]]; then
        echo "Hittar inte skriptet: $s" >&2
        exit 1
    fi
done

if ! command -v runuser >/dev/null || ! command -v getfacl >/dev/null; then
    echo "runuser (util-linux) och getfacl (acl) krävs: sudo apt install acl" >&2
    exit 1
fi

if (( BEKRAFTA )); then
    echo "Testsviten skapar och TAR BORT användare, grupper och katalogen ${KATALOG}."
    read -rp "Kör endast i en test-VM. Skriv JA för att fortsätta: " svar
    [[ "$svar" == "JA" ]] || { echo "Avbrutet."; exit 0; }
fi

# ---------- Hjälpfunktioner ----------

# Återställer testmiljön till ett rent läge
stada() {
    local u g
    for u in "${TESTANVANDARE[@]}"; do
        if id "$u" &>/dev/null; then
            pkill -KILL -u "$u" &>/dev/null
            userdel --remove "$u" &>/dev/null
        fi
    done
    for g in ekonomi revision; do
        if getent group "$g" >/dev/null; then
            groupdel "$g" &>/dev/null
        fi
    done
    rm -rf --one-file-system "$KATALOG" /srv/drytest
    rm -f "$LOGGFIL"
}

# Kör skriptet som testas. Utdata hamnar i $UT och $FEL, returkoden i $RC.
kor() {
    local skript="$1"; shift
    timeout "$TIMEOUT" bash "$skript" "$@" </dev/null >"$UT" 2>"$FEL"
    RC=$?
}

# Registrerar ett resultat: notera SKRIPT TESTNAMN FAKTISKT FÖRVÄNTAT
notera() {
    local skript="$1" namn="$2" faktiskt="$3" forvantat="$4"
    if [[ -z "${KAND[$namn]:-}" ]]; then
        KAND[$namn]=1
        TESTNAMN+=("$namn")
        FORVANTAT[$namn]="$forvantat"
    fi
    if [[ "$faktiskt" == "$forvantat" ]]; then
        RESULTAT["$skript|$namn"]="Godkänt"
        GODKANDA[$skript]=$(( ${GODKANDA[$skript]:-0} + 1 ))
    else
        RESULTAT["$skript|$namn"]="**UNDERKÄNT** (${faktiskt})"
    fi
    printf '  %s%*s %s\n' "$namn" $(( 48 - ${#namn} )) '' "${RESULTAT["$skript|$namn"]}"
}

# Kör ett kommando som en annan användare och svarar OK eller NEKAS
atkomst() {
    local anv="$1"; shift
    if runuser -u "$anv" -- "$@" &>/dev/null; then echo OK; else echo NEKAS; fi
}

# Kör ett test och svarar ja eller nej
ja_nej() {
    if "$@" &>/dev/null; then echo ja; else echo nej; fi
}

medlem() {
    [[ " $(id -nG "$1" 2>/dev/null) " == *" $2 "* ]]
}

har_losenord() {
    local falt
    falt="$(getent shadow "$1" | cut -d: -f2)"
    [[ -n "$falt" && "$falt" != '!'* && "$falt" != '*'* ]]
}

maste_byta_losenord() {
    grep -q 'must be changed' <<<"$(LC_ALL=C chage -l "$1" 2>/dev/null)"
}

# Godkänt bara om skriptet avbryter med felkod INNAN det börjar arbeta.
# En krasch längre fram (till exempel kod 141) räknas alltså inte som validering.
avvisad_fore_arbete() {
    (( RC != 0 )) && ! grep -q 'DRY-RUN' "$UT"
}

tydligt_fel_utan_varde() {
    (( RC != 0 )) && ! grep -q 'unbound variable' "$FEL"
}

# Felmeddelandet får komma på stdout eller stderr
trap_rapporterade() {
    (( RC != 0 )) && cat "$UT" "$FEL" | grep -qE 'rad [0-9]+'
}

# Sant om något ord i filen är användarens riktiga lösenord.
# Varje ord prövas mot hashen i /etc/shadow, så formatet på utskriften spelar ingen roll.
losenord_i_fil() {
    local anv="$1" fil="$2" hash
    [[ -s "$fil" ]] || return 1
    hash="$(getent shadow "$anv" | cut -d: -f2)"
    [[ "$hash" == \$* ]] || return 1
    if command -v python3 >/dev/null; then
        python3 -W ignore - "$hash" "$fil" <<'PYKOD'
import crypt, re, sys
h, fil = sys.argv[1], sys.argv[2]
text = open(fil, encoding="utf-8", errors="replace").read()
ord_ = {o for o in re.split(r"\s+", text) if 8 <= len(o) <= 64}
sys.exit(0 if any(crypt.crypt(o, h) == h for o in ord_) else 1)
PYKOD
    else
        # Reserv utan python3: leta efter typiska utskriftsformat
        grep -qiE 'lösenord[^:]*: *[^ ]{8,}' "$fil"
    fi
}

loggfil_ej_lasbar_for_alla() {
    local mode
    mode="$(stat -c %a "$LOGGFIL" 2>/dev/null)" || return 1
    [[ "${mode: -1}" == "0" ]]
}

acl_rad() {
    grep -qxF -- "$2" <<<"$(getfacl -p "$1" 2>/dev/null)"
}

revision_effektivt_las() {
    grep -qE '^group:revision:...[[:space:]]+#effective:r--$' \
        <<<"$(getfacl -p -e "$1" 2>/dev/null)"
}

# Tar reda på om skriptet använder --dir eller --path för katalogen
satt_flaggor() {
    local hjalp
    hjalp="$(timeout 10 bash "$1" -h 2>&1 </dev/null)"
    if grep -q -- '--path' <<<"$hjalp"; then
        SOKVAGSFLAGGA="--path"
    else
        SOKVAGSFLAGGA="--dir"
    fi
}

# ---------- Testsviten ----------

testsvit() {
    local skript="$1" id="$2"
    local fil="$KATALOG/anna.txt"

    echo
    echo "=== ${id} (${skript}, katalogflagga ${SOKVAGSFLAGGA}) ==="
    stada

    # --- Dry-run ---
    echo "-- Dry-run och validering"
    kor "$skript" --dry-run -u drytest -g ekonomi "$SOKVAGSFLAGGA" /srv/drytest
    notera "$id" "Dry-run: returkod" "$RC" 0
    local andrat=nej
    if id drytest &>/dev/null || [[ -e /srv/drytest || -e "$LOGGFIL" ]] \
        || getent group ekonomi >/dev/null; then
        andrat=ja
    fi
    notera "$id" "Dry-run: inget ändras på systemet" "$andrat" nej

    # --- Validering (körs bara om dry-run bevisligen inte ändrar något) ---
    local validering=(
        "Validering: vägrar /etc|--dry-run -g root $SOKVAGSFLAGGA /etc"
        "Validering: vägrar /etc/ (avslutande snedstreck)|--dry-run -g root $SOKVAGSFLAGGA /etc/"
        "Validering: vägrar /etc via '..'|--dry-run $SOKVAGSFLAGGA /srv/x/../../etc"
        "Validering: vägrar /tmp|--dry-run $SOKVAGSFLAGGA /tmp"
        "Validering: vägrar katalog under /usr|--dry-run $SOKVAGSFLAGGA /usr/local/ekonomi"
        "Validering: vägrar relativ sökväg|--dry-run $SOKVAGSFLAGGA srv/ekonomi"
        "Validering: vägrar versaler i användarnamn|--dry-run -u Anna"
        "Validering: vägrar användarnamn > 32 tecken|--dry-run -u $(printf 'a%.0s' {1..40})"
        "Validering: vägrar ogiltigt gruppnamn|--dry-run -g Fel!Grupp"
    )
    local rad namn args
    for rad in "${validering[@]}"; do
        namn="${rad%%|*}"
        args="${rad#*|}"
        if [[ "$andrat" == nej ]]; then
            # shellcheck disable=SC2086  # argumenten ska delas upp
            kor "$skript" $args
            notera "$id" "$namn" "$(ja_nej avvisad_fore_arbete)" ja
        else
            notera "$id" "$namn" "ej testat" ja
        fi
    done
    kor "$skript" -u
    notera "$id" "Tydligt fel vid flagga utan värde" "$(ja_nej tydligt_fel_utan_varde)" ja
    stada

    # --- Körning 1 ---
    echo "-- Körning 1"
    kor "$skript"
    cp "$UT" "$ARBETSKATALOG/korning1.txt"
    notera "$id" "Körning 1: returkod" "$RC" 0
    notera "$id" "Körning 1: användaren skapad" "$(ja_nej id anna)" ja
    notera "$id" "Körning 1: lösenord satt" "$(ja_nej har_losenord anna)" ja
    notera "$id" "Körning 1: lösenordsbyte krävs" "$(ja_nej maste_byta_losenord anna)" ja
    notera "$id" "Körning 1: katalogen skapad" "$(ja_nej test -d "$KATALOG")" ja

    # Lösenord som skrivits ut trots att utdata inte är en terminal
    notera "$id" "Lösenord visas inte i omdirigerad utdata" \
        "$(losenord_i_fil anna "$ARBETSKATALOG/korning1.txt" && echo nej || echo ja)" ja
    notera "$id" "Lösenord finns inte i loggfilen" \
        "$(losenord_i_fil anna "$LOGGFIL" && echo nej || echo ja)" ja

    # --- Körning 2 ---
    echo "-- Körning 2 (idempotens)"
    kor "$skript"
    notera "$id" "Körning 2: returkod" "$RC" 0
    notera "$id" "Körning 2: lösenord satt" "$(ja_nej har_losenord anna)" ja
    notera "$id" "Körning 2: lösenordsbyte krävs" "$(ja_nej maste_byta_losenord anna)" ja

    # --- Struktur ---
    echo "-- Struktur"
    notera "$id" "Katalog: mode" "$(stat -c %a "$KATALOG" 2>/dev/null || echo saknas)" 3770
    notera "$id" "Katalog: ägare" "$(stat -c %U:%G "$KATALOG" 2>/dev/null || echo saknas)" root:ekonomi
    notera "$id" "ACL: revision r-x på katalogen" "$(ja_nej acl_rad "$KATALOG" group:revision:r-x)" ja
    notera "$id" "Default-ACL: revision r-x" "$(ja_nej acl_rad "$KATALOG" default:group:revision:r-x)" ja
    notera "$id" "Default-ACL: övriga ---" "$(ja_nej acl_rad "$KATALOG" default:other::---)" ja
    notera "$id" "anna i ekonomi (id)" "$(ja_nej medlem anna ekonomi)" ja
    notera "$id" "anna listad i getent group ekonomi" \
        "$([[ ",$(getent group ekonomi | cut -d: -f4)," == *",anna,"* ]] && echo ja || echo nej)" ja
    notera "$id" "Loggfil inte läsbar för alla" "$(ja_nej loggfil_ej_lasbar_for_alla)" ja

    # --- Rättighetsmatris ---
    echo "-- Rättighetsmatris"
    useradd -m -G ekonomi kollega &>/dev/null
    useradd -m -G revision revisor &>/dev/null
    useradd -m utomstaende &>/dev/null

    notera "$id" "anna skapar fil" "$(atkomst anna bash -c "echo hej > '$fil'")" OK
    notera "$id" "anna skapar underkatalog" "$(atkomst anna mkdir "$KATALOG/rapporter")" OK
    notera "$id" "kollega läser annas fil" "$(atkomst kollega cat "$fil")" OK
    notera "$id" "kollega skriver i annas fil" "$(atkomst kollega bash -c "echo mer >> '$fil'")" OK
    notera "$id" "kollega raderar annas fil" "$(atkomst kollega rm -f "$fil")" NEKAS
    notera "$id" "revisor listar katalogen" "$(atkomst revisor ls "$KATALOG")" OK
    notera "$id" "revisor läser fil" "$(atkomst revisor cat "$fil")" OK
    notera "$id" "revisor skapar fil" "$(atkomst revisor touch "$KATALOG/rev.txt")" NEKAS
    notera "$id" "revisor skriver i fil" "$(atkomst revisor bash -c "echo x >> '$fil'")" NEKAS
    notera "$id" "revisor raderar fil" "$(atkomst revisor rm -f "$fil")" NEKAS
    notera "$id" "utomstående listar katalogen" "$(atkomst utomstaende ls "$KATALOG")" NEKAS
    notera "$id" "utomstående läser fil" "$(atkomst utomstaende cat "$fil")" NEKAS

    # --- Arv ---
    echo "-- Arv"
    notera "$id" "Ny fil: mode och ägare" \
        "$(stat -c '%a %U:%G' "$fil" 2>/dev/null || echo saknas)" "660 anna:ekonomi"
    notera "$id" "Ny fil: revision effektivt r--" "$(ja_nej revision_effektivt_las "$fil")" ja
    notera "$id" "Underkatalog: ärver setgid" \
        "$(stat -c %a "$KATALOG/rapporter" 2>/dev/null || echo saknas)" 2770
    notera "$id" "anna raderar egen fil" "$(atkomst anna rm "$fil")" OK

    # --- Befintlig användare ---
    echo "-- Befintlig användare"
    useradd -m befintlig &>/dev/null
    kor "$skript" -u befintlig
    notera "$id" "Befintlig användare: returkod" "$RC" 0
    notera "$id" "Befintlig användare läggs i ekonomi" "$(ja_nej medlem befintlig ekonomi)" ja

    # --- trap ---
    echo "-- Felhantering"
    local kopia="$ARBETSKATALOG/trap_test.sh"
    sed -E 's/^([[:space:]]*)[a-z_]+ chmod 3770 .*/\1false/' "$skript" >"$kopia"
    if cmp -s "$skript" "$kopia"; then
        notera "$id" "trap rapporterar fel med radnummer" "ej testat" ja
    else
        kor "$kopia"
        notera "$id" "trap rapporterar fel med radnummer" "$(ja_nej trap_rapporterade)" ja
    fi

    stada
}

demo_pipefail() {
    local rc
    echo
    echo "=== Isolerat test: pipefail och head ==="
    printf '  tr -dc ... </dev/urandom | head -c 12:  '
    for _ in 1 2 3 4 5; do
        bash -c 'set -euo pipefail; x=$(tr -dc "A-Za-z0-9" </dev/urandom | head -c 12); : "$x"' &>/dev/null
        rc=$?
        printf 'rc=%s ' "$rc"
    done
    echo "(141 = SIGPIPE)"
    printf '  head -c 9 /dev/urandom | base64:        '
    for _ in 1 2 3 4 5; do
        bash -c 'set -euo pipefail; x=$(head -c 9 /dev/urandom | base64); : "$x"' &>/dev/null
        rc=$?
        printf 'rc=%s ' "$rc"
    done
    echo
}

skriv_sammanfattning() {
    local namn s rubrik="| Test | Förväntat |" linje="|---|---|"
    echo
    echo "=== SAMMANFATTNING ==="
    echo
    for s in "${SKRIPT_ID[@]}"; do
        rubrik+=" ${s} |"
        linje+="---|"
    done
    echo "$rubrik"
    echo "$linje"
    for namn in "${TESTNAMN[@]}"; do
        printf '| %s | %s |' "$namn" "${FORVANTAT[$namn]}"
        for s in "${SKRIPT_ID[@]}"; do
            printf ' %s |' "${RESULTAT["$s|$namn"]:-}"
        done
        echo
    done
    echo
    for s in "${SKRIPT_ID[@]}"; do
        echo "${s}: ${GODKANDA[$s]:-0} av ${#TESTNAMN[@]} godkända"
    done
}

# ---------- Start ----------

# shellcheck disable=SC1091  # systemfil som finns på alla Ubuntu-installationer
echo "Testsvit startad $(date '+%Y-%m-%d %H:%M:%S') på $(. /etc/os-release && echo "$PRETTY_NAME")"
for s in "$@"; do
    id="$(basename "$s")"
    SKRIPT_ID+=("$id")
    satt_flaggor "$s"
    testsvit "$s" "$id"
done
demo_pipefail
skriv_sammanfattning
```

---

## 13. Bilaga C: Fullständig testutskrift

Utskriften från [`testresultat.txt`](testresultat.txt). I terminalen visas `**UNDERKÄNT**` med asterisker eftersom sammanfattningen är skriven som Markdown.

```text
Testsvit startad 2026-09-16 11:49:12 på Ubuntu 24.04.4 LTS

=== nyanvandare.sh (nyanvandare.sh, katalogflagga --dir) ===
-- Dry-run och validering
  Dry-run: returkod                                Godkänt
  Dry-run: inget ändras på systemet                Godkänt
  Validering: vägrar /etc                          Godkänt
  Validering: vägrar /etc/ (avslutande snedstreck) Godkänt
  Validering: vägrar /etc via '..'                 Godkänt
  Validering: vägrar /tmp                          Godkänt
  Validering: vägrar katalog under /usr            Godkänt
  Validering: vägrar relativ sökväg                Godkänt
  Validering: vägrar versaler i användarnamn       Godkänt
  Validering: vägrar användarnamn > 32 tecken      Godkänt
  Validering: vägrar ogiltigt gruppnamn            Godkänt
  Tydligt fel vid flagga utan värde                Godkänt
-- Körning 1
  Körning 1: returkod                              Godkänt
  Körning 1: användaren skapad                     Godkänt
  Körning 1: lösenord satt                         Godkänt
  Körning 1: lösenordsbyte krävs                   Godkänt
  Körning 1: katalogen skapad                      Godkänt
  Lösenord visas inte i omdirigerad utdata         Godkänt
  Lösenord finns inte i loggfilen                  Godkänt
-- Körning 2 (idempotens)
  Körning 2: returkod                              Godkänt
  Körning 2: lösenord satt                         Godkänt
  Körning 2: lösenordsbyte krävs                   Godkänt
-- Struktur
  Katalog: mode                                    Godkänt
  Katalog: ägare                                   Godkänt
  ACL: revision r-x på katalogen                   Godkänt
  Default-ACL: revision r-x                        Godkänt
  Default-ACL: övriga ---                          Godkänt
  anna i ekonomi (id)                              Godkänt
  anna listad i getent group ekonomi               Godkänt
  Loggfil inte läsbar för alla                     Godkänt
-- Rättighetsmatris
  anna skapar fil                                  Godkänt
  anna skapar underkatalog                         Godkänt
  kollega läser annas fil                          Godkänt
  kollega skriver i annas fil                      Godkänt
  kollega raderar annas fil                        Godkänt
  revisor listar katalogen                         Godkänt
  revisor läser fil                                Godkänt
  revisor skapar fil                               Godkänt
  revisor skriver i fil                            Godkänt
  revisor raderar fil                              Godkänt
  utomstående listar katalogen                     Godkänt
  utomstående läser fil                            Godkänt
-- Arv
  Ny fil: mode och ägare                           Godkänt
  Ny fil: revision effektivt r--                   Godkänt
  Underkatalog: ärver setgid                       Godkänt
  anna raderar egen fil                            Godkänt
-- Befintlig användare
  Befintlig användare: returkod                    Godkänt
  Befintlig användare läggs i ekonomi              Godkänt
-- Felhantering
  trap rapporterar fel med radnummer               Godkänt

=== skapa_nyanvandare.sh (../skapa_nyanvandare.sh, katalogflagga --dir) ===
-- Dry-run och validering
  Dry-run: returkod                                Godkänt
  Dry-run: inget ändras på systemet                Godkänt
  Validering: vägrar /etc                          Godkänt
  Validering: vägrar /etc/ (avslutande snedstreck) Godkänt
  Validering: vägrar /etc via '..'                 Godkänt
  Validering: vägrar /tmp                          Godkänt
  Validering: vägrar katalog under /usr            Godkänt
  Validering: vägrar relativ sökväg                Godkänt
  Validering: vägrar versaler i användarnamn       Godkänt
  Validering: vägrar användarnamn > 32 tecken      Godkänt
  Validering: vägrar ogiltigt gruppnamn            Godkänt
  Tydligt fel vid flagga utan värde                Godkänt
-- Körning 1
  Körning 1: returkod                              Godkänt
  Körning 1: användaren skapad                     Godkänt
  Körning 1: lösenord satt                         Godkänt
  Körning 1: lösenordsbyte krävs                   Godkänt
  Körning 1: katalogen skapad                      Godkänt
  Lösenord visas inte i omdirigerad utdata         **UNDERKÄNT** (nej)
  Lösenord finns inte i loggfilen                  Godkänt
-- Körning 2 (idempotens)
  Körning 2: returkod                              Godkänt
  Körning 2: lösenord satt                         Godkänt
  Körning 2: lösenordsbyte krävs                   Godkänt
-- Struktur
  Katalog: mode                                    Godkänt
  Katalog: ägare                                   Godkänt
  ACL: revision r-x på katalogen                   Godkänt
  Default-ACL: revision r-x                        Godkänt
  Default-ACL: övriga ---                          Godkänt
  anna i ekonomi (id)                              Godkänt
  anna listad i getent group ekonomi               Godkänt
  Loggfil inte läsbar för alla                     Godkänt
-- Rättighetsmatris
  anna skapar fil                                  Godkänt
  anna skapar underkatalog                         Godkänt
  kollega läser annas fil                          Godkänt
  kollega skriver i annas fil                      Godkänt
  kollega raderar annas fil                        Godkänt
  revisor listar katalogen                         Godkänt
  revisor läser fil                                Godkänt
  revisor skapar fil                               Godkänt
  revisor skriver i fil                            Godkänt
  revisor raderar fil                              Godkänt
  utomstående listar katalogen                     Godkänt
  utomstående läser fil                            Godkänt
-- Arv
  Ny fil: mode och ägare                           Godkänt
  Ny fil: revision effektivt r--                   Godkänt
  Underkatalog: ärver setgid                       Godkänt
  anna raderar egen fil                            Godkänt
-- Befintlig användare
  Befintlig användare: returkod                    Godkänt
  Befintlig användare läggs i ekonomi              Godkänt
-- Felhantering
  trap rapporterar fel med radnummer               Godkänt

=== skapa_nyanvandare_fore_fix.sh (skapa_nyanvandare_fore_fix.sh, katalogflagga --dir) ===
-- Dry-run och validering
  Dry-run: returkod                                Godkänt
  Dry-run: inget ändras på systemet                Godkänt
  Validering: vägrar /etc                          Godkänt
  Validering: vägrar /etc/ (avslutande snedstreck) **UNDERKÄNT** (nej)
  Validering: vägrar /etc via '..'                 **UNDERKÄNT** (nej)
  Validering: vägrar /tmp                          **UNDERKÄNT** (nej)
  Validering: vägrar katalog under /usr            **UNDERKÄNT** (nej)
  Validering: vägrar relativ sökväg                Godkänt
  Validering: vägrar versaler i användarnamn       Godkänt
  Validering: vägrar användarnamn > 32 tecken      Godkänt
  Validering: vägrar ogiltigt gruppnamn            Godkänt
  Tydligt fel vid flagga utan värde                Godkänt
-- Körning 1
  Körning 1: returkod                              Godkänt
  Körning 1: användaren skapad                     Godkänt
  Körning 1: lösenord satt                         Godkänt
  Körning 1: lösenordsbyte krävs                   Godkänt
  Körning 1: katalogen skapad                      Godkänt
  Lösenord visas inte i omdirigerad utdata         **UNDERKÄNT** (nej)
  Lösenord finns inte i loggfilen                  Godkänt
-- Körning 2 (idempotens)
  Körning 2: returkod                              Godkänt
  Körning 2: lösenord satt                         Godkänt
  Körning 2: lösenordsbyte krävs                   Godkänt
-- Struktur
  Katalog: mode                                    Godkänt
  Katalog: ägare                                   Godkänt
  ACL: revision r-x på katalogen                   Godkänt
  Default-ACL: revision r-x                        Godkänt
  Default-ACL: övriga ---                          Godkänt
  anna i ekonomi (id)                              Godkänt
  anna listad i getent group ekonomi               Godkänt
  Loggfil inte läsbar för alla                     Godkänt
-- Rättighetsmatris
  anna skapar fil                                  Godkänt
  anna skapar underkatalog                         Godkänt
  kollega läser annas fil                          Godkänt
  kollega skriver i annas fil                      Godkänt
  kollega raderar annas fil                        Godkänt
  revisor listar katalogen                         Godkänt
  revisor läser fil                                Godkänt
  revisor skapar fil                               Godkänt
  revisor skriver i fil                            Godkänt
  revisor raderar fil                              Godkänt
  utomstående listar katalogen                     Godkänt
  utomstående läser fil                            Godkänt
-- Arv
  Ny fil: mode och ägare                           Godkänt
  Ny fil: revision effektivt r--                   Godkänt
  Underkatalog: ärver setgid                       Godkänt
  anna raderar egen fil                            Godkänt
-- Befintlig användare
  Befintlig användare: returkod                    Godkänt
  Befintlig användare läggs i ekonomi              Godkänt
-- Felhantering
  trap rapporterar fel med radnummer               Godkänt

=== gemini_nyanvandare.sh (gemini_nyanvandare.sh, katalogflagga --path) ===
-- Dry-run och validering
  Dry-run: returkod                                **UNDERKÄNT** (141)
  Dry-run: inget ändras på systemet                Godkänt
  Validering: vägrar /etc                          **UNDERKÄNT** (nej)
  Validering: vägrar /etc/ (avslutande snedstreck) **UNDERKÄNT** (nej)
  Validering: vägrar /etc via '..'                 **UNDERKÄNT** (nej)
  Validering: vägrar /tmp                          **UNDERKÄNT** (nej)
  Validering: vägrar katalog under /usr            **UNDERKÄNT** (nej)
  Validering: vägrar relativ sökväg                Godkänt
  Validering: vägrar versaler i användarnamn       Godkänt
  Validering: vägrar användarnamn > 32 tecken      **UNDERKÄNT** (nej)
  Validering: vägrar ogiltigt gruppnamn            **UNDERKÄNT** (nej)
  Tydligt fel vid flagga utan värde                **UNDERKÄNT** (nej)
-- Körning 1
  Körning 1: returkod                              **UNDERKÄNT** (141)
  Körning 1: användaren skapad                     Godkänt
  Körning 1: lösenord satt                         **UNDERKÄNT** (nej)
  Körning 1: lösenordsbyte krävs                   **UNDERKÄNT** (nej)
  Körning 1: katalogen skapad                      **UNDERKÄNT** (nej)
  Lösenord visas inte i omdirigerad utdata         Godkänt
  Lösenord finns inte i loggfilen                  Godkänt
-- Körning 2 (idempotens)
  Körning 2: returkod                              Godkänt
  Körning 2: lösenord satt                         **UNDERKÄNT** (nej)
  Körning 2: lösenordsbyte krävs                   **UNDERKÄNT** (nej)
-- Struktur
  Katalog: mode                                    Godkänt
  Katalog: ägare                                   Godkänt
  ACL: revision r-x på katalogen                   Godkänt
  Default-ACL: revision r-x                        Godkänt
  Default-ACL: övriga ---                          Godkänt
  anna i ekonomi (id)                              Godkänt
  anna listad i getent group ekonomi               **UNDERKÄNT** (nej)
  Loggfil inte läsbar för alla                     **UNDERKÄNT** (nej)
-- Rättighetsmatris
  anna skapar fil                                  Godkänt
  anna skapar underkatalog                         Godkänt
  kollega läser annas fil                          Godkänt
  kollega skriver i annas fil                      Godkänt
  kollega raderar annas fil                        Godkänt
  revisor listar katalogen                         Godkänt
  revisor läser fil                                Godkänt
  revisor skapar fil                               Godkänt
  revisor skriver i fil                            Godkänt
  revisor raderar fil                              Godkänt
  utomstående listar katalogen                     Godkänt
  utomstående läser fil                            Godkänt
-- Arv
  Ny fil: mode och ägare                           Godkänt
  Ny fil: revision effektivt r--                   Godkänt
  Underkatalog: ärver setgid                       Godkänt
  anna raderar egen fil                            Godkänt
-- Befintlig användare
  Befintlig användare: returkod                    Godkänt
  Befintlig användare läggs i ekonomi              **UNDERKÄNT** (nej)
-- Felhantering
  trap rapporterar fel med radnummer               **UNDERKÄNT** (nej)

=== gemini_lagad.sh (gemini_lagad.sh, katalogflagga --path) ===
-- Dry-run och validering
  Dry-run: returkod                                Godkänt
  Dry-run: inget ändras på systemet                Godkänt
  Validering: vägrar /etc                          **UNDERKÄNT** (nej)
  Validering: vägrar /etc/ (avslutande snedstreck) **UNDERKÄNT** (nej)
  Validering: vägrar /etc via '..'                 **UNDERKÄNT** (nej)
  Validering: vägrar /tmp                          **UNDERKÄNT** (nej)
  Validering: vägrar katalog under /usr            **UNDERKÄNT** (nej)
  Validering: vägrar relativ sökväg                Godkänt
  Validering: vägrar versaler i användarnamn       Godkänt
  Validering: vägrar användarnamn > 32 tecken      **UNDERKÄNT** (nej)
  Validering: vägrar ogiltigt gruppnamn            **UNDERKÄNT** (nej)
  Tydligt fel vid flagga utan värde                **UNDERKÄNT** (nej)
-- Körning 1
  Körning 1: returkod                              Godkänt
  Körning 1: användaren skapad                     Godkänt
  Körning 1: lösenord satt                         Godkänt
  Körning 1: lösenordsbyte krävs                   Godkänt
  Körning 1: katalogen skapad                      Godkänt
  Lösenord visas inte i omdirigerad utdata         **UNDERKÄNT** (nej)
  Lösenord finns inte i loggfilen                  Godkänt
-- Körning 2 (idempotens)
  Körning 2: returkod                              Godkänt
  Körning 2: lösenord satt                         Godkänt
  Körning 2: lösenordsbyte krävs                   Godkänt
-- Struktur
  Katalog: mode                                    Godkänt
  Katalog: ägare                                   Godkänt
  ACL: revision r-x på katalogen                   Godkänt
  Default-ACL: revision r-x                        Godkänt
  Default-ACL: övriga ---                          Godkänt
  anna i ekonomi (id)                              Godkänt
  anna listad i getent group ekonomi               **UNDERKÄNT** (nej)
  Loggfil inte läsbar för alla                     **UNDERKÄNT** (nej)
-- Rättighetsmatris
  anna skapar fil                                  Godkänt
  anna skapar underkatalog                         Godkänt
  kollega läser annas fil                          Godkänt
  kollega skriver i annas fil                      Godkänt
  kollega raderar annas fil                        Godkänt
  revisor listar katalogen                         Godkänt
  revisor läser fil                                Godkänt
  revisor skapar fil                               Godkänt
  revisor skriver i fil                            Godkänt
  revisor raderar fil                              Godkänt
  utomstående listar katalogen                     Godkänt
  utomstående läser fil                            Godkänt
-- Arv
  Ny fil: mode och ägare                           Godkänt
  Ny fil: revision effektivt r--                   Godkänt
  Underkatalog: ärver setgid                       Godkänt
  anna raderar egen fil                            Godkänt
-- Befintlig användare
  Befintlig användare: returkod                    Godkänt
  Befintlig användare läggs i ekonomi              **UNDERKÄNT** (nej)
-- Felhantering
  trap rapporterar fel med radnummer               **UNDERKÄNT** (nej)

=== Isolerat test: pipefail och head ===
  tr -dc ... </dev/urandom | head -c 12:  rc=141 rc=141 rc=141 rc=141 rc=141 (141 = SIGPIPE)
  head -c 9 /dev/urandom | base64:        rc=0 rc=0 rc=0 rc=0 rc=0 

=== SAMMANFATTNING ===

| Test | Förväntat | nyanvandare.sh | skapa_nyanvandare.sh | skapa_nyanvandare_fore_fix.sh | gemini_nyanvandare.sh | gemini_lagad.sh |
|---|---|---|---|---|---|---|
| Dry-run: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Dry-run: inget ändras på systemet | nej | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar /etc | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc/ (avslutande snedstreck) | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /etc via '..' | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar /tmp | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar katalog under /usr | ja | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar relativ sökväg | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar versaler i användarnamn | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Validering: vägrar användarnamn > 32 tecken | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Validering: vägrar ogiltigt gruppnamn | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Tydligt fel vid flagga utan värde | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Körning 1: returkod | 0 | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (141) | Godkänt |
| Körning 1: användaren skapad | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 1: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 1: katalogen skapad | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Lösenord visas inte i omdirigerad utdata | ja | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) | Godkänt | **UNDERKÄNT** (nej) |
| Lösenord finns inte i loggfilen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Körning 2: lösenord satt | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Körning 2: lösenordsbyte krävs | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | Godkänt |
| Katalog: mode | 3770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Katalog: ägare | root:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| ACL: revision r-x på katalogen | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: revision r-x | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Default-ACL: övriga --- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna i ekonomi (id) | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna listad i getent group ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| Loggfil inte läsbar för alla | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| anna skapar fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna skapar underkatalog | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega läser annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega skriver i annas fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| kollega raderar annas fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor listar katalogen | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor läser fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skapar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor skriver i fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| revisor raderar fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående listar katalogen | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| utomstående läser fil | NEKAS | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: mode och ägare | 660 anna:ekonomi | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Ny fil: revision effektivt r-- | ja | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Underkatalog: ärver setgid | 2770 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| anna raderar egen fil | OK | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare: returkod | 0 | Godkänt | Godkänt | Godkänt | Godkänt | Godkänt |
| Befintlig användare läggs i ekonomi | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |
| trap rapporterar fel med radnummer | ja | Godkänt | Godkänt | Godkänt | **UNDERKÄNT** (nej) | **UNDERKÄNT** (nej) |

nyanvandare.sh: 49 av 49 godkända
skapa_nyanvandare.sh: 48 av 49 godkända
skapa_nyanvandare_fore_fix.sh: 44 av 49 godkända
gemini_nyanvandare.sh: 30 av 49 godkända
gemini_lagad.sh: 36 av 49 godkända
```

---

## 14. Bilaga D: Oscars skript

[`oscar_skapa_anvandare.sh`](oscar_skapa_anvandare.sh), oförändrat.

```bash
#!/bin/bash

# ==========================================================
# Användarskapare
# Skapar användare, avdelning, roll och privata mappar
# ==========================================================

# ----------------------------------------------------------
# 1. Kontrollera att scriptet körs som root
# ----------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "Fel: Scriptet måste köras som root."
    echo "Kör exempelvis:"
    echo "sudo ./skapa_anvandare.sh"
    exit 1
fi


# ----------------------------------------------------------
# 2. Funktion för att pausa
# ----------------------------------------------------------

paus() {
    read -p "Tryck Enter för att fortsätta..."
}


# ----------------------------------------------------------
# 3. Fråga efter användarens information
# ----------------------------------------------------------

clear

echo "=============================================="
echo "        VÄLKOMMEN TILL ANVÄNDARSKAPAREN"
echo "=============================================="
echo

read -p "Ange användarnamn: " USERNAME
read -p "Ange användarens fullständiga namn: " FULLNAME


# ----------------------------------------------------------
# 4. Kontrollera om användaren redan finns
# ----------------------------------------------------------

if id "$USERNAME" &>/dev/null; then
    echo
    echo "Fel: Användaren '$USERNAME' finns redan."
    exit 1
fi


# ----------------------------------------------------------
# 5. Välj avdelning
# ----------------------------------------------------------

echo
echo "Välj avdelning:"
echo "1) Administration"
echo "2) IT"
echo "3) Ekonomi"
echo "4) Produktion"
echo

read -p "Ditt val: " DEPARTMENT_CHOICE

case "$DEPARTMENT_CHOICE" in
    1)
        DEPARTMENT="administration"
        DEPARTMENT_NAME="Administration"
        ;;
    2)
        DEPARTMENT="it"
        DEPARTMENT_NAME="IT"
        ;;
    3)
        DEPARTMENT="ekonomi"
        DEPARTMENT_NAME="Ekonomi"
        ;;
    4)
        DEPARTMENT="produktion"
        DEPARTMENT_NAME="Produktion"
        ;;
    *)
        echo "Felaktigt val av avdelning."
        exit 1
        ;;
esac


# ----------------------------------------------------------
# 6. Välj roll
# ----------------------------------------------------------

echo
echo "Välj roll:"
echo "1) Administratör"
echo "2) Chef"
echo "3) Medarbetare"
echo "4) Tekniker"
echo

read -p "Ditt val: " ROLE_CHOICE

case "$ROLE_CHOICE" in
    1)
        ROLE="Administratör"
        ;;
    2)
        ROLE="Chef"
        ;;
    3)
        ROLE="Medarbetare"
        ;;
    4)
        ROLE="Tekniker"
        ;;
    *)
        echo "Felaktigt val av roll."
        exit 1
        ;;
esac


# ----------------------------------------------------------
# 7. Skapa avdelningsgruppen om den inte finns
# ----------------------------------------------------------

if ! getent group "$DEPARTMENT" > /dev/null; then
    groupadd "$DEPARTMENT"
    echo "Gruppen '$DEPARTMENT' skapades."
else
    echo "Gruppen '$DEPARTMENT' finns redan."
fi


# ----------------------------------------------------------
# 8. Skapa användaren
# ----------------------------------------------------------

useradd \
    -m \
    -s /bin/bash \
    -c "$FULLNAME" \
    -G "$DEPARTMENT" \
    "$USERNAME"

if [ $? -ne 0 ]; then
    echo "Fel: Kunde inte skapa användaren."
    exit 1
fi


# ----------------------------------------------------------
# 9. Skapa privata mappar
# ----------------------------------------------------------

USER_HOME="/home/$USERNAME"

mkdir -p "$USER_HOME/Dokument"
mkdir -p "$USER_HOME/Bilder"
mkdir -p "$USER_HOME/Appar"
mkdir -p "$USER_HOME/Videos"


# ----------------------------------------------------------
# 10. Ge användaren ägarskap över mapparna
# ----------------------------------------------------------

chown -R "$USERNAME:$DEPARTMENT" "$USER_HOME"


# ----------------------------------------------------------
# 11. Skydda användarens privata mappar
# ----------------------------------------------------------

chmod 700 "$USER_HOME/Dokument"
chmod 700 "$USER_HOME/Bilder"
chmod 700 "$USER_HOME/Appar"
chmod 700 "$USER_HOME/Videos"


# ----------------------------------------------------------
# 12. Skapa välkomstfil
# ----------------------------------------------------------

cat > "$USER_HOME/VÄLKOMMEN.txt" << EOF
==================================================
                 VÄLKOMMEN!
==================================================

Hej $FULLNAME!

Ditt användarkonto har nu skapats.

Användarnamn : $USERNAME
Avdelning    : $DEPARTMENT_NAME
Roll         : $ROLE

Du har fått tillgång till följande privata mappar:

- Dokument
- Bilder
- Appar
- Videos

Dessa mappar är privata och kan endast användas
av ditt användarkonto.

Du är medlem i avdelningen:

$DEPARTMENT_NAME

Välkommen till organisationen!

==================================================
EOF


# ----------------------------------------------------------
# 13. Ändra ägare på välkomstfilen
# ----------------------------------------------------------

chown "$USERNAME:$DEPARTMENT" "$USER_HOME/VÄLKOMMEN.txt"

chmod 600 "$USER_HOME/VÄLKOMMEN.txt"


# ----------------------------------------------------------
# 14. Hitta andra användare på samma avdelning
# ----------------------------------------------------------

OTHER_USERS=$(getent group "$DEPARTMENT" | cut -d: -f4)


# ----------------------------------------------------------
# 15. Slutlig information
# ----------------------------------------------------------

echo
echo "=============================================="
echo "        ANVÄNDAREN HAR SKAPATS"
echo "=============================================="
echo
echo "Namn       : $FULLNAME"
echo "Användare  : $USERNAME"
echo "Avdelning  : $DEPARTMENT_NAME"
echo "Roll       : $ROLE"
echo
echo "Privata mappar:"
echo "  /home/$USERNAME/Dokument"
echo "  /home/$USERNAME/Bilder"
echo "  /home/$USERNAME/Appar"
echo "  /home/$USERNAME/Videos"
echo

echo "Andra användare på avdelningen:"
echo

if [ -z "$OTHER_USERS" ]; then
    echo "Inga andra användare finns ännu."
else
    echo "$OTHER_USERS" | tr ',' '\n'
fi

echo
echo "=============================================="
echo "Välkommen, $FULLNAME!"
echo "=============================================="
```

---

## 15. Bilaga E: Testsviten `testa_oscar.sh`

Passerar `shellcheck` 0.9.0 utan anmärkningar.

```bash
#!/usr/bin/env bash
#
# testa_oscar.sh
# Testar Oscars interaktiva skript (oscar_skapa_anvandare.sh) genom att
# mata in svaren via stdin, och skriver en sammanfattning som Markdown-tabell.
#
# VARNING: Kör endast i en test-VM. Testsviten skapar och tar bort
# användarna anna, kollega, utomstaende, ny, Erik, kolon och bslash samt
# grupperna administration, it, ekonomi och produktion.
#
# Användning:
#   sudo ./testa_oscar.sh ./oscar_skapa_anvandare.sh | tee testresultat_oscar.txt
#   sudo ./testa_oscar.sh -y ...   (hoppa över bekräftelsen)

# Medvetet utan -e: tester ska kunna misslyckas utan att sviten avbryts
set -uo pipefail

if locale -a 2>/dev/null | grep -qiE '^c\.utf-?8$'; then
    export LC_ALL=C.UTF-8
fi

ANVANDARE=(anna kollega utomstaende ny Erik kolon bslash)
GRUPPER=(administration it ekonomi produktion)
ARBETSKATALOG="$(mktemp -d)"
UT="$ARBETSKATALOG/ut.txt"
RC=0
GODKANDA=0
TOTALT=0
declare -a TABELL=()
trap 'rm -rf "$ARBETSKATALOG"' EXIT

# ---------- Kontroller ----------

if [[ "$EUID" -ne 0 ]]; then
    echo "Kör som root: sudo $0 skript" >&2
    exit 1
fi

BEKRAFTA=1
if [[ "${1:-}" == "-y" ]]; then
    BEKRAFTA=0
    shift
fi

SKRIPT="${1:-}"
if [[ ! -f "$SKRIPT" ]]; then
    echo "Användning: sudo $0 [-y] ./oscar_skapa_anvandare.sh" >&2
    exit 1
fi

if (( BEKRAFTA )); then
    echo "Testsviten skapar och TAR BORT användare och grupperna ${GRUPPER[*]}."
    read -rp "Kör endast i en test-VM. Skriv JA för att fortsätta: " svar
    [[ "$svar" == "JA" ]] || { echo "Avbrutet."; exit 0; }
fi

# ---------- Hjälpfunktioner ----------

stada() {
    local u g
    for u in "${ANVANDARE[@]}"; do
        if id "$u" &>/dev/null; then
            pkill -KILL -u "$u" &>/dev/null
            userdel --remove "$u" &>/dev/null
        fi
    done
    for g in "${GRUPPER[@]}"; do
        if getent group "$g" >/dev/null; then
            groupdel "$g" &>/dev/null
        fi
    done
}

# Kör skriptet och matar in varje argument som en rad på stdin
kor_med_svar() {
    printf '%s\n' "$@" | TERM=xterm timeout 60 bash "$SKRIPT" >"$UT" 2>&1
    RC=$?
}

notera() {
    local namn="$1" faktiskt="$2" forvantat="$3" res
    TOTALT=$(( TOTALT + 1 ))
    if [[ "$faktiskt" == "$forvantat" ]]; then
        res="Godkänt"
        GODKANDA=$(( GODKANDA + 1 ))
    else
        res="**UNDERKÄNT** (${faktiskt})"
    fi
    TABELL+=("| ${namn} | ${forvantat} | ${res} |")
    printf '  %s%*s %s\n' "$namn" $(( 56 - ${#namn} )) '' "$res"
}

ja_nej() {
    if "$@" &>/dev/null; then echo ja; else echo nej; fi
}

atkomst() {
    local anv="$1"; shift
    if runuser -u "$anv" -- "$@" &>/dev/null; then echo OK; else echo NEKAS; fi
}

medlem() {
    [[ " $(id -nG "$1" 2>/dev/null) " == *" $2 "* ]]
}

listad_i_grupp() {
    [[ ",$(getent group "$2" | cut -d: -f4)," == *",$1,"* ]]
}

har_losenord() {
    local falt
    falt="$(getent shadow "$1" | cut -d: -f2)"
    [[ -n "$falt" && "$falt" != '!'* && "$falt" != '*'* ]]
}

maste_byta_losenord() {
    grep -q 'must be changed' <<<"$(LC_ALL=C chage -l "$1" 2>/dev/null)"
}

privata_mappar_ok() {
    local m
    for m in Dokument Bilder Appar Videos; do
        [[ "$(stat -c '%a:%U' "/home/$1/$m" 2>/dev/null)" == "700:$1" ]] || return 1
    done
}

ny_anvandare_utelamnas() {
    ! sed -n '/Andra användare/,/^=====/p' "$UT" | grep -qx "$1"
}

inga_andringar() {
    local g
    id ny &>/dev/null && return 1
    for g in "${GRUPPER[@]}"; do
        getent group "$g" >/dev/null && return 1
    done
    return 0
}

rc_skild_fran_noll() {
    (( RC != 0 ))
}

avbrot_utan_andringar() {
    (( RC != 0 )) && inga_andringar
}

misslyckad_useradd_utan_rester() {
    (( RC != 0 )) && ! getent group produktion >/dev/null
}

# ---------- Testerna ----------

echo "Testsvit startad $(date '+%Y-%m-%d %H:%M:%S') mot ${SKRIPT}"
stada

echo "-- Grundfunktion (anna, Ekonomi, Medarbetare)"
kor_med_svar anna "Anna Andersson" 3 3
cp "$UT" "$ARBETSKATALOG/forsta.txt"
notera "Körning: returkod" "$RC" 0
notera "Användaren skapad" "$(ja_nej id anna)" ja
notera "Fullständigt namn sparat" "$(getent passwd anna | cut -d: -f5)" "Anna Andersson"
notera "Skal" "$(getent passwd anna | cut -d: -f7)" /bin/bash
notera "Tilläggsgrupp ekonomi (id)" "$(ja_nej medlem anna ekonomi)" ja
notera "Listad i getent group ekonomi" "$(ja_nej listad_i_grupp anna ekonomi)" ja
notera "Privata mappar: finns, 700, ägs av anna" "$(ja_nej privata_mappar_ok anna)" ja
notera "VÄLKOMMEN.txt: mode" "$(stat -c %a /home/anna/VÄLKOMMEN.txt 2>/dev/null || echo saknas)" 600
UT="$ARBETSKATALOG/forsta.txt"
notera "Utskrift: nya användaren listas inte som 'annan'" "$(ja_nej ny_anvandare_utelamnas anna)" ja
UT="$ARBETSKATALOG/ut.txt"

echo "-- Lösenord"
notera "Lösenord satt (kan logga in)" "$(ja_nej har_losenord anna)" ja
notera "Lösenordsbyte krävs" "$(ja_nej maste_byta_losenord anna)" ja

echo "-- Sekretess i hemkatalogen"
useradd -m -G ekonomi kollega &>/dev/null
useradd -m utomstaende &>/dev/null
runuser -u anna -- bash -c 'echo hemligt > ~/anteckningar.txt; echo privat > ~/Dokument/cv.txt' &>/dev/null
notera "Kollega listar annas hemkatalog" "$(atkomst kollega ls /home/anna)" NEKAS
notera "Kollega läser fil i hemkatalogens rot" "$(atkomst kollega cat /home/anna/anteckningar.txt)" NEKAS
notera "Kollega läser .bashrc" "$(atkomst kollega cat /home/anna/.bashrc)" NEKAS
notera "Kollega läser Dokument/cv.txt" "$(atkomst kollega cat /home/anna/Dokument/cv.txt)" NEKAS
notera "Kollega läser VÄLKOMMEN.txt" "$(atkomst kollega cat /home/anna/VÄLKOMMEN.txt)" NEKAS
notera "Utomstående listar annas hemkatalog" "$(atkomst utomstaende ls /home/anna)" NEKAS
notera "Anna skriver i Dokument" "$(atkomst anna touch /home/anna/Dokument/ny.txt)" OK

echo "-- Felfall och validering"
kor_med_svar anna "X" 3 3
notera "Befintlig användare avvisas" "$(ja_nej rc_skild_fran_noll)" ja
stada

kor_med_svar ny "Ny" 9
notera "Ogiltig avdelning: avbryter utan ändringar" "$(ja_nej avbrot_utan_andringar)" ja
stada

kor_med_svar ny "Ny" 3 9
notera "Ogiltig roll: avbryter utan ändringar" "$(ja_nej avbrot_utan_andringar)" ja
stada

kor_med_svar Erik "Erik E" 2 3
notera "Versaler i användarnamn avvisas" "$(id Erik &>/dev/null && echo nej || echo ja)" ja
stada

kor_med_svar kolon "A:B" 4 3
notera "Misslyckad useradd lämnar ingen grupp kvar" "$(ja_nej misslyckad_useradd_utan_rester)" ja
stada

kor_med_svar bslash 'Per\Olsson' 3 3
notera "Backslash i namn bevaras" "$(getent passwd bslash | cut -d: -f5)" 'Per\Olsson'
stada

# Skriptet matas in via stdin så att nobody inte behöver läsrätt till filen
runuser -u nobody -- bash -s <"$SKRIPT" &>/dev/null
RC=$?
notera "Icke-root avvisas" "$(ja_nej rc_skild_fran_noll)" ja
stada

# ---------- Sammanfattning ----------

echo
echo "=== SAMMANFATTNING ==="
echo
echo "| Test | Förväntat | $(basename "$SKRIPT") |"
echo "|---|---|---|"
printf '%s\n' "${TABELL[@]}"
echo
echo "$(basename "$SKRIPT"): ${GODKANDA} av ${TOTALT} godkända"
```

---

## 16. Bilaga F: Testutskrift för Oscars skript

Utskriften från [`testresultat_oscar.txt`](testresultat_oscar.txt).

```text
Testsvit startad 2026-09-16 11:57:42 mot oscar_skapa_anvandare.sh
-- Grundfunktion (anna, Ekonomi, Medarbetare)
  Körning: returkod                                        Godkänt
  Användaren skapad                                        Godkänt
  Fullständigt namn sparat                                 Godkänt
  Skal                                                     Godkänt
  Tilläggsgrupp ekonomi (id)                               Godkänt
  Listad i getent group ekonomi                            Godkänt
  Privata mappar: finns, 700, ägs av anna                  Godkänt
  VÄLKOMMEN.txt: mode                                      Godkänt
  Utskrift: nya användaren listas inte som 'annan'         **UNDERKÄNT** (nej)
-- Lösenord
  Lösenord satt (kan logga in)                             **UNDERKÄNT** (nej)
  Lösenordsbyte krävs                                      **UNDERKÄNT** (nej)
-- Sekretess i hemkatalogen
  Kollega listar annas hemkatalog                          **UNDERKÄNT** (OK)
  Kollega läser fil i hemkatalogens rot                    **UNDERKÄNT** (OK)
  Kollega läser .bashrc                                    **UNDERKÄNT** (OK)
  Kollega läser Dokument/cv.txt                            Godkänt
  Kollega läser VÄLKOMMEN.txt                              Godkänt
  Utomstående listar annas hemkatalog                      Godkänt
  Anna skriver i Dokument                                  Godkänt
-- Felfall och validering
  Befintlig användare avvisas                              Godkänt
  Ogiltig avdelning: avbryter utan ändringar               Godkänt
  Ogiltig roll: avbryter utan ändringar                    Godkänt
  Versaler i användarnamn avvisas                          **UNDERKÄNT** (nej)
  Misslyckad useradd lämnar ingen grupp kvar               **UNDERKÄNT** (nej)
  Backslash i namn bevaras                                 **UNDERKÄNT** (PerOlsson)
  Icke-root avvisas                                        Godkänt

=== SAMMANFATTNING ===

| Test | Förväntat | oscar_skapa_anvandare.sh |
|---|---|---|
| Körning: returkod | 0 | Godkänt |
| Användaren skapad | ja | Godkänt |
| Fullständigt namn sparat | Anna Andersson | Godkänt |
| Skal | /bin/bash | Godkänt |
| Tilläggsgrupp ekonomi (id) | ja | Godkänt |
| Listad i getent group ekonomi | ja | Godkänt |
| Privata mappar: finns, 700, ägs av anna | ja | Godkänt |
| VÄLKOMMEN.txt: mode | 600 | Godkänt |
| Utskrift: nya användaren listas inte som 'annan' | ja | **UNDERKÄNT** (nej) |
| Lösenord satt (kan logga in) | ja | **UNDERKÄNT** (nej) |
| Lösenordsbyte krävs | ja | **UNDERKÄNT** (nej) |
| Kollega listar annas hemkatalog | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser fil i hemkatalogens rot | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser .bashrc | NEKAS | **UNDERKÄNT** (OK) |
| Kollega läser Dokument/cv.txt | NEKAS | Godkänt |
| Kollega läser VÄLKOMMEN.txt | NEKAS | Godkänt |
| Utomstående listar annas hemkatalog | NEKAS | Godkänt |
| Anna skriver i Dokument | OK | Godkänt |
| Befintlig användare avvisas | ja | Godkänt |
| Ogiltig avdelning: avbryter utan ändringar | ja | Godkänt |
| Ogiltig roll: avbryter utan ändringar | ja | Godkänt |
| Versaler i användarnamn avvisas | ja | **UNDERKÄNT** (nej) |
| Misslyckad useradd lämnar ingen grupp kvar | ja | **UNDERKÄNT** (nej) |
| Backslash i namn bevaras | Per\Olsson | **UNDERKÄNT** (PerOlsson) |
| Icke-root avvisas | ja | Godkänt |

oscar_skapa_anvandare.sh: 16 av 25 godkända
```
