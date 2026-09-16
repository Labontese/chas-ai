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
