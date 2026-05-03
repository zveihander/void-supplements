#!/bin/sh
# =============================================================================
#  void-supplements repository installer
#  https://github.com/zveihander/void-supplements
#
#  Usage:
#    curl -fsSL https://zveihander.github.io/void-supplements/install.sh | sh
#
# =============================================================================

set -eu

REPO_OWNER="zveihander"
REPO_NAME="void-supplements"
PKGNAME="repo-void-supplements"
PKGVER="1.0_1"
PAGES_BASE="https://${REPO_OWNER}.github.io/${REPO_NAME}"
RELEASES_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/bootstrap"

if [ -t 1 ]; then
  BOLD="\033[1m"
  DIM="\033[2m"
  RED="\033[1;31m"
  YLW="\033[1;33m"
  GRN="\033[1;32m"
  CYN="\033[1;36m"
  RST="\033[0m"
else
  BOLD="" DIM="" RED="" YLW="" GRN="" CYN="" RST=""
fi

say() { printf "  %b\n" "$*"; }
ok() { printf "  ${GRN}✔${RST}  %b\n" "$*"; }
warn() { printf "  ${YLW}⚠${RST}   %b\n" "$*"; }
err() { printf "\n  ${RED}${BOLD}ERROR:${RST} %b\n\n" "$*" >&2; }
die() {
  err "$*"
  exit 1
}
sep() { printf "  ${DIM}────────────────────────────────────────────────${RST}\n"; }

detect_priv() {
  if [ "$(id -u)" -eq 0 ]; then
    PRIV=""
    return
  fi
  if command -v doas >/dev/null 2>&1; then
    PRIV="doas"
  elif command -v sudo >/dev/null 2>&1; then
    PRIV="sudo"
  else
    die "Neither ${BOLD}doas${RST} nor ${BOLD}sudo${RST} found.\nRun this script as root, or install doas/sudo first."
  fi
}

detect_arch() {
  _machine="$(uname -m)"

  _libc=""
  if ldd --version 2>&1 | grep -qi musl; then
    _libc="-musl"
  fi

  case "$_machine" in
  x86_64) ARCH="x86_64${_libc}" ;;
  i686) ARCH="i686" ;;
  aarch64) ARCH="aarch64${_libc}" ;;
  armv6l) ARCH="armv6l${_libc}" ;;
  armv7l) ARCH="armv7l${_libc}" ;;
  *)
    die "Unsupported architecture: ${BOLD}${_machine}${RST}\n\n  void-supplements supports: x86_64, x86_64-musl, i686,\n  aarch64, aarch64-musl, armv6l, armv6l-musl, armv7l, armv7l-musl\n\n  If you think the architecture you're using is worth packaging for, feel free to open an issue: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"
    ;;
  esac
}

check_deps() {
  for _cmd in curl xbps-install; do
    command -v "$_cmd" >/dev/null 2>&1 ||
      die "${BOLD}${_cmd}${RST} is required but not found.\n  Are you on Void Linux?"
  done
}

TMPDIR=""
cleanup() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT INT TERM

check_deps
detect_priv
detect_arch

XBPS_FILE="${PKGNAME}-${PKGVER}.noarch.xbps"
DOWNLOAD_URL="${RELEASES_BASE}/${XBPS_FILE}"

printf "\n"
printf "  ${BOLD}${CYN}╔══════════════════════════════════════════════════════╗${RST}\n"
printf "  ${BOLD}${CYN}║          the void-supplements installer              ║${RST}\n"
printf "  ${BOLD}${CYN}║      github.com/zveihander/void-supplements          ║${RST}\n"
printf "  ${BOLD}${CYN}╚══════════════════════════════════════════════════════╝${RST}\n"
printf "\n"

sep
printf "\n"

say "Detected system:   ${BOLD}${ARCH}${RST}"
printf "\n"
sep
printf "\n"

say "${BOLD}This script will:${RST}"
printf "\n"
say "  ${GRN}1.${RST} Download ${BOLD}${XBPS_FILE}${RST}"
say "     ${DIM}from GitHub${RST}"
printf "\n"
say "  ${GRN}2.${RST} Install it locally with ${BOLD}xbps-install${RST}"
say "     ${DIM}Installs signing key to /var/db/xbps/keys/${RST}"
printf "\n"
say "  ${GRN}3.${RST} Write ${BOLD}/etc/xbps.d/00-master-void-supplements.conf${RST}"
say "     ${DIM}repository=https://github.com/zveihander/void-supplements/releases/download/${ARCH}${RST}"
printf "\n"
sep
printf "\n"

warn "${BOLD}${YLW}This is a THIRD-PARTY repository.${RST}"
warn "It is not affiliated with the Void Linux project."
printf "\n"
warn "ALWAYS review the source: ${CYN}https://github.com/${REPO_OWNER}/${REPO_NAME}${RST}"
printf "\n"
warn "fTo undo installation of void-supplements after install:"
say "     ${BOLD}${PRIV:+${PRIV} }xbps-remove ${PKGNAME}${RST}"
say "     ${BOLD}${PRIV:+${PRIV} }rm /etc/xbps.d/00-master-void-supplements.conf${RST}"
printf "\n"
sep
printf "\n"

printf "  Continue? [y/N] "
read -r _reply
printf "\n"

case "$_reply" in
[yY] | [yY][eE][sS]) ;;
*)
  say "Aborted. Nothing was installed."
  printf "\n"
  exit 0
  ;;
esac

if [ -n "$PRIV" ]; then
  say "You may be prompted for your password:"
  printf "\n"
  $PRIV true || die "Authentication failed."
  printf "\n"
fi

TMPDIR="$(mktemp -d)"
XBPS_PATH="${TMPDIR}/${XBPS_FILE}"

say "Downloading ${BOLD}${XBPS_FILE}${RST} ..."
if ! curl -fsSL --progress-bar "$DOWNLOAD_URL" -o "$XBPS_PATH"; then
  die "Download failed.\n  URL: ${DOWNLOAD_URL}\n\n  Check your connection or open an issue:\n  https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"
fi
ok "Download complete."
printf "\n"

say "Indexing local package ..."
if ! XBPS_TARGET_ARCH="$ARCH" xbps-rindex -a "$XBPS_PATH" 2>/dev/null; then
  say "${DIM}xbps-rindex not found, falling back to direct install...${RST}"
  ${PRIV} xbps-install -y xbps 2>/dev/null || true
  XBPS_TARGET_ARCH="$ARCH" xbps-rindex -a "$XBPS_PATH"
fi

say "Installing ${BOLD}${PKGNAME}${RST} ..."
printf "\n"

if ! ${PRIV} xbps-install --yes --repository="$TMPDIR" "$PKGNAME"; then
  die "Installation failed.\n  xbps-install exited with an error.\n  Check the output above for details."
fi

printf "\n"
sep
printf "\n"
ok "${BOLD}${GRN}void-supplements is installed and active!${RST}"
printf "\n"
say "Run the following to sync and upgrade all packages:"
printf "\n"
say "  ${BOLD}${PRIV:+${PRIV} }xbps-install -Su${RST}"
printf "\n"
say "Currently installed packages that are also in the void-supplements repository"
say "will take priority and will update where versions conflict with the official Void repos."
printf "\n"
say "${DIM}Questions or issues: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues${RST}"
printf "\n"
