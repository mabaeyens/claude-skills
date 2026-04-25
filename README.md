# claude-skills

Custom skills for Claude Code, Claude Desktop, and other Claude clients.

## Structure

```
claude-skills/
└── mira/
    └── mira-status/     # cross-project warm start for Mira (server + app)
        └── SKILL.md
```

Skills are grouped by project under subdirectories.

## Installing on a new machine

**Claude Code (CLI):**
```bash
# Clone repo
git clone git@github.com:mabaeyens/claude-skills.git ~/Documents/Projects/claude-skills

# Symlink each skill into ~/.claude/skills/
mkdir -p ~/.claude/skills
for skill_dir in ~/Documents/Projects/claude-skills/*/; do
  for skill in "$skill_dir"*/; do
    name=$(basename "$skill")
    ln -sf "$skill" ~/.claude/skills/"$name"
  done
done
```

**Claude Desktop / Claude.ai:**
Skills are not yet supported natively outside Claude Code. Copy the `SKILL.md` content into a project instruction or system prompt to use manually.

## Adding a new skill

```bash
mkdir -p ~/Documents/Projects/claude-skills/<group>/<skill-name>
# write SKILL.md
ln -s ~/Documents/Projects/claude-skills/<group>/<skill-name> ~/.claude/skills/<skill-name>
```
