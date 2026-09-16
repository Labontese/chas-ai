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
