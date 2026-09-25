#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Radarr 6.3.0 which has already seen one
# release of it (v6.3.0-0), plus the release history this repository really
# carries. Two of those tags are traps that exist for real: `v6-0` and
# `v3.14.6-0` were both minted by the commit-message autotagger this script
# replaced, and name versions the role never pinned. `v6.1.1-3` is there so
# that a counter is never read off a different version's tags.
#
# The defaults file deliberately carries the traps this role's real one has: a
# commented-out example of the version variable and an image tag derived from
# it, neither of which may be picked up as the version. The `# renovate:`
# annotation is included so that moving it away from `radarr_version` - or
# renaming the variable the tag is keyed on - breaks this suite.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# radarr_version: 9.9.9
		# renovate: datasource=docker depName=ghcr.io/linuxserver/radarr versioning=semver
		radarr_version: 6.3.0
		radarr_container_image: "{{ radarr_container_image_registry_prefix }}linuxserver/radarr:{{ radarr_container_image_tag }}"
		radarr_container_image_tag: "{{ radarr_version }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v5.28.0-0 v6.1.1-0 v6.1.1-1 v6.1.1-2 v6.1.1-3 v6.2.1-0 v6.3.0-0 v6-0 v3.14.6-0; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_patch="sed -i 's|^radarr_version: 6.3.0$|radarr_version: 6.3.1|' defaults/main.yml"
revert_patch="sed -i 's|^radarr_version: 6.3.1$|radarr_version: 6.3.0|' defaults/main.yml"
bump_minor="sed -i 's|^radarr_version: 6.3.0$|radarr_version: 6.4.2|' defaults/main.yml"
bump_to_released="sed -i 's|^radarr_version: 6.3.0$|radarr_version: 6.1.1|' defaults/main.yml"
bump_to_major_only="sed -i 's|^radarr_version: 6.3.0$|radarr_version: 6|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v6.3.1-0 "$(merge "$bump_patch")"
expect 'task edit'    v6.3.1-1 "$(merge "$edit_task")"
expect 'template'     v6.3.1-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v6.3.0-1 "$(merge "$edit_task")"
expect 'version bump' v6.3.1-0 "$(merge "$bump_patch")"

scenario 'A minor bump of a version never released'
expect 'minor bump' v6.4.2-0 "$(merge "$bump_minor")"

# `v6.1.1-3` is the highest release of 6.1.1 and must be continued from,
# rather than a counter belonging to 6.3.0 or to the stray `v6-0`.
scenario 'Going back to an already released version'
expect 'downgrade to 6.1.1' v6.1.1-4 "$(merge "$bump_to_released")"

# `v6-0` and `v3.14.6-0` were minted by the commit-message autotagger from
# commits that had nothing to do with the pinned Radarr version. They must not
# be read as releases of 6.3.0, and `v6-0` must only ever be continued by a
# version that really is `6`.
scenario 'Tags left behind by the commit-message autotagger'
expect 'a task at 6.3.0'  v6.3.0-1 "$(merge "$edit_task")"

scenario 'A version whose tag prefix is a prefix of other tags'
expect 'version 6' v6-1 "$(merge "$bump_to_major_only")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'meta'     v6.3.0-1   "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 1 2 3 4 5 6 7 8 9 10; do
	git tag "v6.3.0-$release_number"
done
expect 'a task' v6.3.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_patch" > /dev/null
# The role is now identical to what v6.3.0-0 already published, so there is
# nothing new to release.
expect 'a revert' ''       "$(merge "$revert_patch")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_patch" > /dev/null
expect 'a revert' v6.3.0-1 "$(merge "$revert_patch && $edit_task")"

# This repository keeps a `develop` branch that gets merged into `main`, and the
# autotag workflow runs on both. The merge into `main` carries the tree that was
# already released from `develop`, so it must not be released a second time.
scenario 'A release on develop, then the merge of develop into main'
git branch -q develop
git checkout -q develop
expect 'a task on develop' v6.3.0-1 "$(merge "$edit_task")"
git checkout -q main
git merge -q --no-ff -m 'Merge pull request from develop' develop
expect 'the merge into main' '' "$(bin/compute-next-tag.sh 2>/dev/null)"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
