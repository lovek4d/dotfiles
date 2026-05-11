## Shell Command Rules
- NEVER use `cd` to change to the current working directory — you are already there
- NEVER use `cd` to navigate away from the starting working directory — use relative paths for child paths, absolute paths for everything else
- NEVER use `git -C <path>` when `<path>` is the current working directory — just run `git` directly
- When running Bash commands, use paths relative to the current working directory. Do not prefix commands with the absolute path of the working directory.

## Git Command Grouping
- **Group state-changing git commands** into a single `&&`-chained Bash call to minimize permission prompts:
  - Committing: `git add <files> && git commit -m "..."` (one call, not two)
  - Stash + switch: `git stash && git switch <branch>` or `git switch <branch> && git stash pop`
  - Stash + checkout: `git stash && git checkout <branch>` or `git checkout <branch> && git stash pop`
  - Checkout workflows: `git checkout -b <branch> && git push -u origin <branch>`
- **Commit and PR descriptions must be based on the actual diff and branch history** (from `git diff`, `git log`, `git status`), not the conversation context. Read the code changes first, then write the description.
- **Never push unless explicitly asked** to create a PR or push.
- **When asked to create a PR**, group all commands into minimal Bash calls:
  - `git add <files> && git commit -m "..." && git push -u origin <branch>` then `gh pr create ...`
  - Or if already committed: `git push -u origin <branch> && gh pr create ...`

## No Decorative Echo in Bash Commands
- NEVER use `echo` to print visual separators or decorations (e.g., `echo "---"`, `echo "==="`, `echo ""`). These trigger the "quoted characters in flag names" permission prompt.
- Output text directly in your response text instead of via bash commands.
- Do not prefix or suffix command groups with separator echoes.

## Minimizing Permission Prompts

### Prefer Dedicated Tools Over Bash
Dedicated tools (Read, Edit, Write, Glob, Grep) never trigger permission prompts. Prefer
them over equivalent Bash commands whenever possible:
- File search: **Glob** not `find` or `ls`
- Content search: **Grep** not `grep` or `rg`
- Reading files: **Read** not `cat`, `head`, `tail`
- Editing files: **Edit** not `sed`, `awk`
- Writing files: **Write** not shell redirection

Reserve Bash for system commands and operations with no dedicated tool equivalent. **When Bash is necessary**, these modern helpers are installed and (where read-only) allowlisted — prefer them over POSIX equivalents:
- `fd` over `find` for file discovery in pipelines
- `rg` over `grep` for content search in pipelines
- `jq` for JSON parsing
- `bat` for paginated file view (rare; Read tool covers most cases)
- `sd` for stream find/replace — **modifies files in-place by default; use the Edit tool for file changes**
- `tldr <cmd>` for command cheatsheets

### Never Use Shell Redirection for File I/O
Shell redirection (`>`, `>>`, heredocs, `tee`) triggers permission prompts every time.
Use dedicated tools instead — they bypass Bash entirely:
- `echo "..." > file`, `cat > file`, `cat <<EOF > file` → use **Write** tool
- `echo "..." >> file`, `tee -a file` → use **Edit** tool (append)
- `sed -i` → use **Edit** tool
- Reading: `cat file`, `head`, `tail` → use **Read** tool

### Batch Permission-Requiring Operations Toward the End
- Do all reading, exploration, and planning first (all allowlisted/tool-based)
- Group permission-requiring Bash calls as late as possible in a task:
  - File deletions (`rm`), directory creation (`mkdir`)
  - Package installs (`npm install`, `pip install`, `brew install`)
  - Any remaining shell writes
- This concentrates prompts into one burst at the end rather than scattering
  interruptions throughout autonomous work
