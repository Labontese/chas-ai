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
        temp_pass=$(head -c 9 /dev/urandom | base64)
        
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
