#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Déploiement GitHub avec signature GPG
#  Usage :
#    ./deploy.sh init              # 1re fois : git init + remote + push
#    ./deploy.sh "message commit"  # Commits signés + push
#    ./deploy.sh --tag v0.1.0      # Tag GPG signé + push
#    ./deploy.sh --check           # Vérifier que tout est prêt
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
log()  { echo "${BLUE}▶${NC} $*"; }
ok()   { echo "${GREEN}✓${NC} $*"; }
warn() { echo "${YELLOW}⚠${NC} $*"; }
die()  { echo "${RED}✗${NC} $*" >&2; exit 1; }

# =============================================================================
#  1. VÉRIFICATIONS
# =============================================================================
check_env() {
    log "Vérification de l'environnement..."

    command -v git  >/dev/null || die "git introuvable"
    command -v gpg  >/dev/null || die "gpg introuvable (apt install gnupg)"

    # GPG_TTY : indispensable pour la passphrase (sinon "Inappropriate ioctl")
    if [[ -z "${GPG_TTY:-}" ]]; then
        export GPG_TTY=$(tty)
        warn "GPG_TTY non défini → forcé à $GPG_TTY"
        warn "Ajoutez 'export GPG_TTY=\$(tty)' à votre ~/.zshrc"
    fi

    # Clé de signature configurée ?
    SIGNING_KEY=$(git config --get user.signingkey || true)
    if [[ -z "$SIGNING_KEY" ]]; then
        die "Aucune clé GPG configurée. Lancez :
    gpg --full-generate-key
    gpg --list-secret-keys --keyid-format=long
    git config --global user.signingkey <ID>
    git config --global commit.gpgsign true"
    fi

    # Signature automatique activée ?
    GPG_SIGN=$(git config --get commit.gpgsign || echo "false")
    if [[ "$GPG_SIGN" != "true" ]]; then
        warn "commit.gpgsign n'est pas activé → activation..."
        git config --global commit.gpgsign true
    fi

    # Remote configuré ?
    if ! git remote get-url origin >/dev/null 2>&1; then
        warn "Aucun remote 'origin' configuré"
    fi

    ok "Environnement prêt (clé : ${SIGNING_KEY:0:16}...)"
}

# =============================================================================
#  2. INITIALISATION (1re fois)
# =============================================================================
cmd_init() {
    check_env

    if [[ ! -d .git ]]; then
        log "Initialisation du dépôt Git..."
        git init
        git branch -M main
        ok "Dépôt initialisé (branche main)"
    else
        ok "Dépôt déjà initialisé"
    fi

    # Remote ?
    if ! git remote get-url origin >/dev/null 2>&1; then
        read -rp "URL du dépôt GitHub (ex: https://github.com/user/hash36.git) : " URL
        [[ -n "$URL" ]] || die "URL requise"
        git remote add origin "$URL"
        ok "Remote 'origin' → $URL"
    else
        ok "Remote déjà configuré : $(git remote get-url origin)"
    fi

    log "Ajout des fichiers..."
    git add -A

    log "Vérification de la signature GPG sur un commit de test..."
    git commit --allow-empty -S -m "chore: initial commit (signed)" >/dev/null
    git log --show-signature -1 | grep -q "Good signature" \
        && ok "Signature GPG valide" \
        || die "La signature GPG a échoué. Vérifiez votre configuration."

    ok "Prêt. Lancez maintenant :"
    echo "    ./deploy.sh \"feat: initial HASH-36 v0.1.0\""
}

# =============================================================================
#  3. COMMIT + PUSH (avec signature GPG)
# =============================================================================
cmd_commit() {
    local msg="${1:-}"
    [[ -n "$msg" ]] || die "Message de commit requis : ./deploy.sh \"mon message\""

    check_env

    # Y a-t-il des changements ?
    if git diff --quiet && git diff --cached --quiet; then
        warn "Aucun changement à committer"
        return 0
    fi

    log "Fichiers modifiés :"
    git status --short

    log "Ajout..."
    git add -A

    log "Commit signé GPG : \"$msg\""
    git commit -S -m "$msg"

    # Vérifier la signature
    if git log --show-signature -1 | grep -q "Good signature"; then
        ok "Commit signé et vérifié"
    else
        warn "Le commit n'est pas signé correctement !"
        git log --show-signature -1
        read -rp "Continuer quand même ? [y/N] " ans
        [[ "${ans,,}" == "y" ]] || die "Abandon"
    fi

    log "Push vers origin/main..."
    git push -u origin main || die "Échec du push (conflit ? authentification ?)"

    ok "Push réussi"
    echo
    echo "Vérifiez sur GitHub : https://github.com/$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+/[^/.]+).*#\1#')/commits/main"
    echo "Le commit doit avoir le badge vert 'Verified'."
}

# =============================================================================
#  4. TAG SIGNÉ (release)
# =============================================================================
cmd_tag() {
    local tag="${1:-}"
    [[ -n "$tag" ]] || die "Tag requis : ./deploy.sh --tag v0.1.0"

    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || warn "Format de tag non standard (attendu : v0.1.0)"

    check_env

    # Vérifier que la working tree est propre
    if ! git diff --quiet || ! git diff --cached --quiet; then
        die "Working tree non propre. Commitez d'abord avec ./deploy.sh \"message\""
    fi

    log "Création du tag signé GPG : $tag"
    git tag -s "$tag" -m "Release $tag"

    log "Vérification..."
    git tag -v "$tag" 2>&1 | grep -q "Good signature" \
        && ok "Tag signé GPG valide" \
        || die "Signature du tag invalide"

    log "Push du tag..."
    git push origin "$tag"

    ok "Tag $tag poussé"
    echo
    echo "Créez la release GitHub :"
    echo "  https://github.com/$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+/[^/.]+).*#\1#')/releases/new?tag=$tag"
}

# =============================================================================
#  5. CHECK (diagnostic)
# =============================================================================
cmd_check() {
    log "Diagnostic du dépôt..."

    echo "--- Git ---"
    git --version
    git config --get user.name    || warn "user.name non défini"
    git config --get user.email   || warn "user.email non défini"
    git config --get user.signingkey || warn "user.signingkey non défini"
    git config --get commit.gpgsign  || warn "commit.gpgsign non défini"

    echo "--- GPG ---"
    gpg --version | head -1
    gpg --list-secret-keys --keyid-format=long 2>/dev/null | head -10

    echo "--- Remote ---"
    git remote -v 2>/dev/null || warn "Aucun remote"

    echo "--- État ---"
    git status --short 2>/dev/null || warn "Pas de dépôt Git"

    echo "--- Dernier commit ---"
    git log --show-signature -1 2>/dev/null | head -20 || warn "Aucun commit"

    echo
    ok "Diagnostic terminé"
}

# =============================================================================
#  DISPATCH
# =============================================================================
case "${1:-}" in
    init)              cmd_init ;;
    --tag)             cmd_tag "${2:-}" ;;
    --check)           cmd_check ;;
    -h|--help)
        sed -n '2,10p' "$0"
        exit 0
        ;;
    "")
        die "Usage : ./deploy.sh init | \"message\" | --tag v0.1.0 | --check"
        ;;
    *)
        cmd_commit "$1"
        ;;
esac