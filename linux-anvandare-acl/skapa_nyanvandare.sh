#!/usr/bin/env bash
#
# skapa_nyanvandare.sh
# ---------------------------------------------------------------------------
# Skapar en ny medarbetare, en avdelningsgrupp och en delad katalog med
# setgid + sticky bit samt POSIX-ACL för en läsande revisionsgrupp.
#
# Genererat utifrån den härdade uppgiftsprompten (se PROMPT.md).
# Målmiljö: Ubuntu Server 24.04 LTS (Bash 5.x), körs med sudo.
# ---------------------------------------------------------------------------

# -E : ERR-trappen ärvs in i funktioner (annars rapporteras inte fel där)
# -e : avbryt vid fel, -u : fel på odefinierade variabler, pipefail : fel i pipe
set -Eeuo pipefail

# --- Exit-koder (tydliga felslag) -----------------------------------------
readonly E_OK=0            # allt gick bra
readonly E_ROOT=1          # kördes inte som root
readonly E_ARGS=2          # felaktiga argument
readonly E_VALIDERING=3    # ogiltig indata
readonly E_BEROENDE=4      # saknat beroende (t.ex. setfacl)

# --- Standardvärden (kan överstyras med argument) -------------------------
ANVANDARE="anna"
GRUPP="ekonomi"
REVGRUPP="revision"
KATALOG="/srv/ekonomi"
readonly LOGGFIL="/var/log/nyanvandare.log"
DRY_RUN=0

# ---------------------------------------------------------------------------
# Hjälptext
# ---------------------------------------------------------------------------
visa_hjalp() {
  cat <<HJALP
Användning: sudo $0 [alternativ]

Skapar en användare, en avdelningsgrupp och en delad katalog med korrekta
rättigheter (setgid + sticky) samt läsande ACL för en revisionsgrupp.

Alternativ:
  -u, --user NAMN       Användarnamn        (standard: ${ANVANDARE})
  -g, --group NAMN      Avdelningsgrupp      (standard: ${GRUPP})
  -r, --revision NAMN   Revisionsgrupp (läs) (standard: ${REVGRUPP})
  -d, --dir SÖKVÄG      Delad katalog        (standard: ${KATALOG})
  -n, --dry-run         Visa vad som skulle göras, ändra inget
  -h, --help            Visa denna hjälp

Exempel:
  sudo $0 -u anna -g ekonomi -r revision -d /srv/ekonomi
  sudo $0 --dry-run
HJALP
}

# ---------------------------------------------------------------------------
# Loggning: tidsstämplat till terminal + loggfil. Loggfilen skrivs INTE i
# dry-run. Lösenord loggas ALDRIG här.
# ---------------------------------------------------------------------------
logga() {
  local ts meddelande
  ts="$(date --iso-8601=seconds)"
  meddelande="[${ts}] $*"
  printf '%s\n' "${meddelande}"
  if [[ "${DRY_RUN}" -eq 0 && -w "${LOGGFIL}" ]]; then
    printf '%s\n' "${meddelande}" >>"${LOGGFIL}"
  fi
}

# ---------------------------------------------------------------------------
# kor(): kör ett muterande kommando, eller skriv bara ut det i dry-run.
# ---------------------------------------------------------------------------
kor() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    logga "[DRY-RUN] skulle köra: $*"
  else
    logga "kör: $*"
    "$@"
  fi
}

# Bekräftelse som bara loggas i skarpt läge (undviker att påstå att något
# gjordes under en dry-run).
logga_resultat() {
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    logga "$@"
  fi
}

# ---------------------------------------------------------------------------
# ERR-trap: rapportera rad, kommando och exit-kod vid oväntat fel.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2317  # anropas indirekt via trap
vid_fel() {
  local rc=$?
  logga "FEL: kommandot '${BASH_COMMAND}' misslyckades på rad ${BASH_LINENO[0]} (exit ${rc})"
  exit "${rc}"
}
trap vid_fel ERR

# ---------------------------------------------------------------------------
# Argumenthantering
# ---------------------------------------------------------------------------
tolka_argument() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--user)     ANVANDARE="${2:-}"; shift 2 ;;
      -g|--group)    GRUPP="${2:-}";     shift 2 ;;
      -r|--revision) REVGRUPP="${2:-}";  shift 2 ;;
      -d|--dir)      KATALOG="${2:-}";   shift 2 ;;
      -n|--dry-run)  DRY_RUN=1;          shift   ;;
      -h|--help)     visa_hjalp; exit "${E_OK}" ;;
      *)
        printf 'Fel: okänt argument: %s\n\n' "$1" >&2
        visa_hjalp >&2
        exit "${E_ARGS}"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Validering av indata
# ---------------------------------------------------------------------------
giltigt_namn() {
  # Linux-konvention: börjar med gemen bokstav eller _, sedan gemener/siffror/_/-
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

validera_indata() {
  local namn
  for namn in "${ANVANDARE}" "${GRUPP}" "${REVGRUPP}"; do
    if [[ -z "${namn}" ]] || ! giltigt_namn "${namn}"; then
      printf 'Fel: ogiltigt användar-/gruppnamn: %q\n' "${namn}" >&2
      exit "${E_VALIDERING}"
    fi
  done

  if [[ "${KATALOG}" != /* ]]; then
    printf 'Fel: katalogen måste anges som absolut sökväg: %q\n' "${KATALOG}" >&2
    exit "${E_VALIDERING}"
  fi

  # Normalisera sökvägen: tar bort avslutande snedstreck och löser upp .. och
  # symlänkar, så att till exempel /etc/ och /srv/x/../../etc inte slinker igenom
  KATALOG="$(realpath -m -- "${KATALOG}")"

  # Vägra känsliga systemkataloger OCH allt under dem (skydd mot fatala misstag)
  case "${KATALOG}" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|\
    /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib64/*|/proc/*|/root/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/*)
      printf 'Fel: vägrar operera på skyddad systemkatalog: %q\n' "${KATALOG}" >&2
      exit "${E_VALIDERING}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Root-kontroll. Dry-run tillåts utan root (endast förhandsvisning).
# ---------------------------------------------------------------------------
kontrollera_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      logga "VARNING: kör inte som root — endast --dry-run tillåts utan root."
    else
      printf 'Fel: skriptet måste köras som root (använd sudo).\n' >&2
      exit "${E_ROOT}"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Beroenden: säkerställ att setfacl finns (installera acl vid behov).
# ---------------------------------------------------------------------------
sakerstall_beroenden() {
  if command -v setfacl >/dev/null 2>&1; then
    return 0
  fi
  logga "setfacl saknas — installerar paketet 'acl'."
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    logga "[DRY-RUN] skulle köra: apt-get update && apt-get install -y acl"
    return 0
  fi
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq acl
  if ! command -v setfacl >/dev/null 2>&1; then
    printf 'Fel: kunde inte installera setfacl (paketet acl).\n' >&2
    exit "${E_BEROENDE}"
  fi
}

# ---------------------------------------------------------------------------
# Loggfil: skapas med säkert läge 640 root:adm (aldrig världsläsbar).
# ---------------------------------------------------------------------------
skapa_loggfil() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -e "${LOGGFIL}" ]]; then
    install -m 640 -o root -g adm /dev/null "${LOGGFIL}"
  fi
}

# ---------------------------------------------------------------------------
# Skapa grupp om den saknas (idempotent).
# ---------------------------------------------------------------------------
skapa_grupp() {
  local grupp="$1"
  if getent group "${grupp}" >/dev/null 2>&1; then
    logga "Grupp '${grupp}' finns redan — hoppar över."
  else
    kor groupadd "${grupp}"
    logga_resultat "Grupp '${grupp}' skapad."
  fi
}

# ---------------------------------------------------------------------------
# Skapa användare (idempotent). Lösenord sätts ENDAST vid nyskapande, så att
# en befintlig användares lösenord aldrig skrivs över vid omkörning.
# ---------------------------------------------------------------------------
skapa_anvandare() {
  if id -u "${ANVANDARE}" >/dev/null 2>&1; then
    logga "Användare '${ANVANDARE}' finns redan — lösenord lämnas orört."
  else
    kor useradd --create-home --shell /bin/bash "${ANVANDARE}"
    logga_resultat "Användare '${ANVANDARE}' skapad."
    satt_tillfalligt_losenord
  fi

  # Gruppmedlemskap (usermod -aG är idempotent — säker att köra varje gång)
  kor usermod -aG "${GRUPP}" "${ANVANDARE}"
  logga_resultat "Användare '${ANVANDARE}' är medlem i '${GRUPP}'."
}

# ---------------------------------------------------------------------------
# Generera och sätt ett tillfälligt lösenord.
#  - CSPRNG (/dev/urandom), 20 tecken, chpasswd-säker teckenmängd
#  - matas till chpasswd via stdin (aldrig som kommandoargument -> ej i ps)
#  - tvingas bytas vid första inloggning (chage -d 0)
#  - skrivs ut EN gång till stdout, aldrig till loggfilen
# ---------------------------------------------------------------------------
satt_tillfalligt_losenord() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    logga "[DRY-RUN] skulle generera tillfälligt lösenord och tvinga byte vid första inloggning."
    return 0
  fi

  local losen
  losen="$(LC_ALL=C tr -dc 'A-Za-z0-9@%_=+.,-' </dev/urandom 2>/dev/null | head -c 20)" || true
  if [[ "${#losen}" -lt 20 ]]; then
    printf 'Fel: kunde inte generera ett tillräckligt långt lösenord.\n' >&2
    exit "${E_VALIDERING}"
  fi

  printf '%s:%s\n' "${ANVANDARE}" "${losen}" | chpasswd
  chage -d 0 "${ANVANDARE}"
  logga "Tillfälligt lösenord satt för '${ANVANDARE}' (måste bytas vid första inloggning)."

  # Enda utskriften av lösenordet — till terminalen, inte loggfilen.
  printf '\n=== TILLFÄLLIGT LÖSENORD (överlämna out-of-band) ===\n'
  printf 'Användare: %s\n' "${ANVANDARE}"
  printf 'Lösenord : %s\n' "${losen}"
  printf '====================================================\n\n'
}

# ---------------------------------------------------------------------------
# Katalog + rättigheter + ACL.
#  Basläge 3770 = setgid(2) + sticky(1) + rwxrwx--- :
#    - setgid  -> nya filer/kataloger ärver gruppen ekonomi
#    - sticky  -> användare kan bara radera sina egna filer
#    - övriga  -> ingen åtkomst
#  ACL:
#    - ekonomi: rwx på katalogen; default rwX -> nya filer blir gruppskrivbara
#               oavsett användarens umask (setgid ensamt ärver ej skrivbiten)
#    - revision: r-x på katalogen (x krävs för att kunna gå in och lista);
#               default rX -> framtida underkataloger blir traverserbara,
#               framtida filer förblir enbart läsbara
#    - mask rwx -> klämmer inte de namngivna posternas effektiva rättigheter
# ---------------------------------------------------------------------------
satt_rattigheter() {
  kor mkdir -p "${KATALOG}"
  kor chown "root:${GRUPP}" "${KATALOG}"
  kor chmod 3770 "${KATALOG}"
  logga_resultat "Katalog '${KATALOG}' satt till root:${GRUPP}, läge 3770 (setgid+sticky)."

  # Access-ACL (gäller katalogen nu)
  kor setfacl -m "g:${GRUPP}:rwx,g:${REVGRUPP}:r-x,m::rwx,o::---" "${KATALOG}"
  # Default-ACL (ärvs av framtida filer och underkataloger)
  kor setfacl -d -m "u::rwx,g::rwx,g:${GRUPP}:rwX,g:${REVGRUPP}:rX,m::rwx,o::---" "${KATALOG}"
  logga_resultat "ACL satt: ${GRUPP}=rw (skapa/redigera), ${REVGRUPP}=läs (inkl. framtida filer)."
}

# ---------------------------------------------------------------------------
# Sammanfattning för verifiering (endast läskommandon).
# ---------------------------------------------------------------------------
sammanfatta() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    logga "[DRY-RUN] klart — inga ändringar gjordes."
    return 0
  fi
  logga "Sammanfattning:"
  id "${ANVANDARE}"
  ls -ld "${KATALOG}"
  getfacl -p "${KATALOG}"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  tolka_argument "$@"
  validera_indata
  kontrollera_root
  skapa_loggfil

  logga "Start (dry-run=${DRY_RUN}): användare=${ANVANDARE}, grupp=${GRUPP}, revision=${REVGRUPP}, katalog=${KATALOG}"

  sakerstall_beroenden
  skapa_grupp "${GRUPP}"
  skapa_grupp "${REVGRUPP}"
  skapa_anvandare
  satt_rattigheter
  sammanfatta

  logga "Klart."
  exit "${E_OK}"
}

main "$@"
