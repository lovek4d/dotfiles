## Shell Command Rules
- NEVER use `cd` to change to the current working directory — you are already there
- NEVER use `git -C <path>` when `<path>` is the current working directory — just run `git` directly
- When running Bash commands, use paths relative to the current working directory. Do not prefix commands with the absolute path of the working directory.

## Git Command Grouping
- **Group state-changing git commands** into a single `&&`-chained Bash call to minimize permission prompts:
  - Committing: `git add <files> && git commit -m "..."` (one call, not two)
  - Stash + switch: `git stash && git switch <branch>` or `git switch <branch> && git stash pop`
  - Stash + checkout: `git stash && git checkout <branch>` or `git checkout <branch> && git stash pop`
  - Checkout workflows: `git checkout -b <branch> && git push -u origin <branch>`
- **Never push unless explicitly asked** to create a PR or push.
- **When asked to create a PR**, group all commands into minimal Bash calls:
  - `git add <files> && git commit -m "..." && git push -u origin <branch>` then `gh pr create ...`
  - Or if already committed: `git push -u origin <branch> && gh pr create ...`
