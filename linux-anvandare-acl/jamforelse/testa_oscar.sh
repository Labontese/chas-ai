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
