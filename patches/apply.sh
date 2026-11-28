#!/usr/bin/env bash
# Apply port patches to a LineageOS 24.0 tree, safe to re-run
# usage: apply.sh [topic ...]   (default: frontlight eink charging audio)
set -euo pipefail

PATCHES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# patches/<dir> -> project path in the tree
declare -A PROJECTS=(
    [packages_frameworks_base]=frameworks/base
    [system_sepolicy]=system/sepolicy
    [lineage-sdk]=lineage-sdk
    [external_tinyalsa_new]=external/tinyalsa_new
    [hardware_interfaces]=hardware/interfaces
    [vendor_lineage]=vendor/lineage
)
ORDER_frontlight=(packages_frameworks_base system_sepolicy)
# eink's sepolicy patch applies on top of frontlight's, keep it after
ORDER_eink=(packages_frameworks_base system_sepolicy)
ORDER_charging=(lineage-sdk vendor_lineage)
ORDER_audio=(external_tinyalsa_new hardware_interfaces)

die() { printf '\n*** ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d .repo && -f build/envsetup.sh ]] || die "run this from the root of the Lineage source tree"

declare -A TOPIC_DIRS=(
    [eink]="$PWD/hardware/onyx/eink/patches"
)

# git am needs a committer identity; use a neutral one if none is configured.
if ! git config user.email >/dev/null 2>&1; then
    export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-local}"
    export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-local@localhost}"
fi

TOPICS=("$@")
if (( ${#TOPICS[@]} == 0 )); then
    TOPICS=(frontlight eink charging audio)
fi

for topic in "${TOPICS[@]}"; do
    topic_dir="${TOPIC_DIRS[$topic]:-$PATCHES_ROOT/$topic}"
    [[ -d "$topic_dir" ]] || die "unknown topic: $topic ($topic_dir not found)"
    declare -n ORDER="ORDER_$topic"

    for dir in "${ORDER[@]}"; do
        project="${PROJECTS[$dir]}"
        [[ -d "$project/.git" || -f "$project/.git" ]] || die "$project is not a git checkout"
        if [[ -d "$(git -C "$project" rev-parse --git-path rebase-apply)" ]]; then
            die "$project has a git am/rebase in progress; run 'git -C $project am --abort' first"
        fi
        [[ -z "$(git -C "$project" status --porcelain --untracked-files=no)" ]] \
            || die "$project has uncommitted changes; commit or reset them first"

        recent="$(git -C "$project" log -n 200 --format=%s)"
        for patch in "$topic_dir/$dir"/*.patch; do
            name="$(basename "$patch")"
            if git -C "$project" apply --check --reverse "$patch" >/dev/null 2>&1; then
                echo "skip    $project: $name (already applied)"
                continue
            fi
            subject="$(git mailinfo /dev/null /dev/null < "$patch" | sed -n 's/^Subject: //p')"
            if [[ -n "$subject" ]] && grep -qxF -- "$subject" <<< "$recent"; then
                echo "skip    $project: $name (already applied: same subject)"
                continue
            fi
            if ! git -C "$project" -c commit.gpgsign=false am --3way "$patch"; then
                git -C "$project" am --abort || true
                die "$name failed to apply to $project (git am error above)."
            fi
            echo "applied $project: $name"
        done
    done
done

echo
echo "All patches applied (${TOPICS[*]})."
