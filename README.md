# claude-skills

Custom skills for Claude Code, Claude Desktop, and other Claude clients.

## Structure

```
claude-skills/
└── mira/
    ├── mira-status/      # cross-project warm start for Mira (server + app)
    │   └── SKILL.md
    ├── mira-server/      # manage the Mira LaunchAgent (start/stop/reload/logs/status)
    │   └── SKILL.md
    └── mira-release/     # bump version, archive, and upload Mira to TestFlight
        ├── SKILL.md
        └── bin/          # release helper scripts (bump, archive, upload, expire builds, ...)
└── mlx/
    ├── mlx-model-card/   # write/refresh real model card descriptions for mlx-community conversions
    │   └── SKILL.md
    └── mlx-convert/      # end-to-end: convert, verify, card, upload, track -- wraps mlx-conversions/scripts/pipeline.py
        └── SKILL.md
```

Skills are grouped by project under subdirectories. A `writing/` group also exists locally
(personal `humanize` skill) but is gitignored and never pushed.

## Installing on a new machine

**Claude Code (CLI):**
```bash
# Clone repo
git clone git@github.com:mabaeyens/claude-skills.git ~/Documents/Projects/claude-skills  # macOS
# or wherever you keep projects on the target machine

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
