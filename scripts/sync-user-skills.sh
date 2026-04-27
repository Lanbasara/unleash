#!/usr/bin/env bash
# Sync Unleash skills to user-level ~/.claude/skills/
# Rewrites frontmatter name and internal references so skills work outside the plugin/marketplace system.
# Run this after editing any SKILL.md in ./skills/

set -e

UNLEASH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_SKILLS="$HOME/.claude/skills"

rewrite() {
  local src="$1"
  local name="$2"
  local dst="$USER_SKILLS/unleash-$name/SKILL.md"
  mkdir -p "$(dirname "$dst")"
  sed -e "s|^name: $name$|name: unleash-$name|" \
      -e 's|unleash:brainstorming|unleash-brainstorming|g' \
      -e 's|unleash:debating|unleash-debating|g' \
      -e 's|unleash:planning|unleash-planning|g' \
      -e 's|unleash:implementing|unleash-implementing|g' \
      -e 's|unleash:validating|unleash-validating|g' \
      -e 's|unleash:walking-through|unleash-walking-through|g' \
      -e 's|unleash:archiving|unleash-archiving|g' \
      -e 's|unleash:reporting|unleash-reporting|g' \
      -e 's|unleash:using-unleash|unleash-using-unleash|g' \
      -e "s|\`references/unleash-knowledge\.md\`|\`$UNLEASH_ROOT/references/unleash-knowledge.md\`|g" \
      "$src" > "$dst"
  echo "synced: $src -> $dst"
}

for skill_dir in "$UNLEASH_ROOT"/skills/*/; do
  name="$(basename "$skill_dir")"
  src="$skill_dir/SKILL.md"
  [ -f "$src" ] || continue
  rewrite "$src" "$name"
done

echo ""
echo "done. restart Claude Code to pick up changes."
