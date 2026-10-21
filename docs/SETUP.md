# Machine setup: fresh PC to first PR

Applies to all four members. Revision: 21 October 2026 (converted from the team's setup PDF, rev 2026-09-18, which is no longer authoritative; owner handle filled, test names and `make` targets aligned to `main`, external citations removed). Current deadlines and status live in `docs/STATE.md`.

| | |
|---|---|
| Time | 60-90 min per machine, mostly downloads |
| Disk | ~6 GB (WSL + tools), plus 2 GB for the formal suite (Appendix B) |
| Needs | Windows 10 build 19041+ or Windows 11, admin rights, a GitHub account, network |
| Done when | the section 8 one-liner is pasted into `docs/SYNC.md` and `ssh -T git@github.com` greets you by your own GitHub username |

## Three rules that save hours later

1. Everything (git, ssh key, clone, make) happens inside the Ubuntu terminal, never in PowerShell or Git Bash. Windows and WSL have separate home folders; a key generated in PowerShell lands in `C:\Users\you\.ssh` and git inside WSL never sees it.
2. The repo lives under `~/` in Ubuntu, never under `/mnt/c/...`. The Windows filesystem through WSL is 5-10x slower and breaks file permissions and line endings, which shows up as every file marked modified and ssh refusing to load the key.
3. One GitHub account and one SSH key per person per machine. Never copy a private key (`id_ed25519`) between machines or people. A shared key makes every commit look like one person, which breaks the authorship count that decides author order.

## What gets installed, and why

| Tool | Where | Purpose |
|---|---|---|
| WSL2 + Ubuntu 24.04 | Windows feature | Linux environment; every tool below runs inside it |
| Windows Terminal | Windows | Tabs, copy/paste, Ubuntu profile |
| VS Code + WSL extension | Windows, edits inside WSL | Editor; the WSL extension opens files from the Ubuntu side |
| git | Ubuntu (apt) | Version control over SSH |
| Verilator 5.020 | Ubuntu (apt) | Lint and fast-seed simulation. Same version as CI, so local green means CI green |
| Icarus Verilog 12 | Ubuntu (apt) | Second simulator; catches Verilator-specific assumptions |
| GTKWave | Ubuntu (apt) | Waveform viewer, opens as a Windows window through WSLg |
| build-essential, make | Ubuntu (apt) | g++ for Verilator's generated C++; `make` drives the flow |
| keychain | Ubuntu (apt) | Type the SSH passphrase once per boot instead of on every push |
| OSS CAD Suite | Ubuntu (tarball) | Yosys, SymbiYosys, solvers, sv2v. Aashish now; others by January. Cross-check only — JasperGold on the lab machine is the primary formal flow |

Xcelium (simulation) and JasperGold (formal) exist only on the college lab machines and are not installed here.

## 0. Repo owner, once (done)

All of this is on GitHub or in the repo, not on anyone's PC. Recorded as done on `main`; listed so a new machine can verify rather than redo.

1. Four GitHub usernames collected; Settings, Collaborators, Add people, role Write. Each invite must be accepted (step 5.5).
2. `.github/CODEOWNERS` carries real handles. Owner account is `@zackkracky`. Until CODEOWNERS is real, GitHub cannot auto-request the right reviewer.
3. `.gitattributes` is filled so Windows editors cannot introduce CRLF endings.
4. `.gitignore` is filled; build output, waveforms and logs never enter git.
5. Settings, Branches, ruleset for `main`: pull request with 1 approval, required status check, direct pushes blocked. The status check only appears in the picker after CI has run once.

Do not push to `main` even where a ruleset would allow it. Every change is a branch and a PR from the first commit, so the habit is there when it matters.

## 1. Windows: install WSL2 and Ubuntu 24.04

Requires Windows 11, or Windows 10 version 2004 (build 19041) or later. Check with Win+R, `winver`, Enter.

1. Task Manager (Ctrl+Shift+Esc), Performance, CPU. Bottom right must say `Virtualization: Enabled`. If disabled, reboot into BIOS/UEFI (usually F2, Del or F10) and enable Intel VT-x or AMD SVM. Without it, step 2 fails with `0x80370102`.
2. Start menu, PowerShell, Run as administrator:

```
wsl --install -d Ubuntu-24.04
```

Downloads the WSL kernel and the Ubuntu 24.04 image (~700 MB), 5-15 min, prompts to reboot.

3. Reboot. An Ubuntu window finishes the install (if not: Start menu, Ubuntu 24.04). It asks for a UNIX username (lowercase, no spaces) and a password. The password does not echo; type it and press Enter twice. It is needed for every later `sudo`.
4. Back in a normal PowerShell:

```
wsl --update
wsl -l -v
```

Expect `Ubuntu-24.04  Running  2`. The last column must be 2; if it shows 1, run `wsl --set-version Ubuntu-24.04 2`.

Use Ubuntu 24.04, not 22.04. On 24.04 apt gives Verilator 5.020, the CI version. On 22.04 apt gives 4.038, which cannot build the testbench (no `--timing`, no `--binary`, no class `randomize`) and forces a source build (Appendix A, 20-40 min).

## 2. Windows: terminal and editor

1. Windows Terminal: preinstalled on Windows 11, Microsoft Store on Windows 10. Open it, dropdown next to the `+` tab, Ubuntu-24.04. In Settings (Ctrl+,) set Default profile to Ubuntu-24.04.
2. VS Code, in PowerShell:

```
winget install Microsoft.VisualStudioCode
```

If `winget` is missing, download the User Installer from code.visualstudio.com and run with defaults.

3. In VS Code, Extensions (Ctrl+Shift+X): install WSL (Microsoft) and Verilog-HDL/SystemVerilog (mshr-h). Close VS Code.
4. From now on open the project only by typing `code .` inside the repo folder in the Ubuntu terminal. The bottom-left corner must say `WSL: Ubuntu-24.04`; if it does not, you are editing through the Windows side and will hit the line-ending problem.

## 3. Ubuntu: packages

All commands from here run in the Ubuntu terminal.

```
sudo apt update && sudo apt upgrade -y
sudo apt install -y git make build-essential verilator iverilog gtkwave \
  python3-pip curl wget keychain
```

Check each tool:

```
verilator --version      # Verilator 5.020 ...
iverilog -V | head -1    # Icarus Verilog version 12.0 ...
git --version
make --version | head -1
g++ --version | head -1
```

If `verilator --version` prints 4.x you are on Ubuntu 22.04: go to Appendix A. Do not install Verilator through pip or conda; those builds differ from CI.

GTKWave check: run `gtkwave &`. A window should appear on the Windows desktop through WSLg. If nothing appears, in PowerShell run `wsl --update`, then `wsl --shutdown`, reopen Ubuntu and retry.

## 4. Git identity

Use the same email that is on your GitHub account (GitHub, Settings, Emails). Commits made with a different email are not linked to your profile, and author order is decided by counted merged contribution — a wrong email means your work is not counted.

```
git config --global user.name "Your Full Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global pull.ff only
```

| Setting | Effect |
|---|---|
| `user.name` / `user.email` | Stamped on every commit; must match GitHub |
| `init.defaultBranch main` | New repos start on `main` |
| `core.autocrlf input` | Converts CRLF to LF on commit, never the other way; belt and braces with `.gitattributes` |
| `pull.ff only` | `git pull` refuses to create a merge commit; if it refuses, rebase (section 7) |

Verify with `git config --global --list`.

## 5. SSH key and GitHub access

You create a key pair on the PC. The private half stays in `~/.ssh/`; the public half is pasted into your GitHub account. When git connects, GitHub challenges the private key. No password is sent and nothing is shared between people.

### 5.1 Generate the key (inside Ubuntu)

```
ssh-keygen -t ed25519 -C "you@example.com"
```

Press Enter to accept `~/.ssh/id_ed25519`. A passphrase is recommended; section 5.4 makes you type it once per boot. Result: `~/.ssh/id_ed25519` (private, never leaves this machine) and `~/.ssh/id_ed25519.pub` (public, the only thing you copy out).

### 5.2 Add the public key to your GitHub account

```
cat ~/.ssh/id_ed25519.pub
```

Copy the whole line (Ctrl+Shift+C in Windows Terminal). In the browser, logged into your own account: profile picture, Settings, SSH and GPG keys, New SSH key. Title `laptop-wsl`, Key type Authentication Key, paste, Add SSH key.

### 5.3 Test the connection

```
ssh -T git@github.com
```

First time only, ssh shows a host fingerprint. It must be exactly:

```
SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
```

That is GitHub's published ED25519 host key. If it matches, type `yes`. If it does not match, do not type yes — the network is intercepting SSH.

Expected: `Hi <your-username>! You've successfully authenticated, but GitHub does not provide shell access.` The "no shell access" part is normal; the username in the greeting is the test.

If it greets you with someone else's username, the key on this machine is registered to their account: `rm ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub` and redo 5.1 and 5.2.

If it hangs or times out (campus Wi-Fi often blocks port 22), route SSH over 443:

```
cat >> ~/.ssh/config <<'EOF'
Host github.com
  Hostname ssh.github.com
  Port 443
  User git
EOF
chmod 600 ~/.ssh/config
ssh -T git@github.com
```

The fingerprint on port 443 is the same. This config is permanent and harmless where port 22 works.

### 5.4 Type the passphrase once per boot

Skip if you set no passphrase.

```
echo 'eval "$(keychain --eval --quiet id_ed25519)"' >> ~/.bashrc
source ~/.bashrc
```

### 5.5 Accept the invite and clone

Accept the collaborator invite from the GitHub email, or at `https://github.com/zackkracky/noc-router-verification/invitations`. Without it, push always fails with `Permission ... denied`.

Clone with the SSH URL, not HTTPS:

```
mkdir -p ~/proj && cd ~/proj
git clone git@github.com:zackkracky/noc-router-verification.git
cd noc-router-verification
git remote -v          # both lines must start with git@github.com:
git log --oneline | head -3
code .
```

`~/proj` is inside the Ubuntu filesystem (rule 2). If you already cloned over HTTPS and git keeps asking for a username and password:

```
git remote set-url origin git@github.com:zackkracky/noc-router-verification.git
```

Checkpoint: `ssh -T git@github.com` greets you by name, `git remote -v` shows SSH URLs, VS Code says `WSL: Ubuntu-24.04`.

## 6. Toolchain smoke test

Repo-independent, so it works before anything else is set up. It compiles a tiny SystemVerilog module in Verilator's timing mode, builds the generated C++ and runs it.

```
mkdir -p /tmp/vt && cd /tmp/vt
cat > hello.sv <<'EOF'
module hello;                     // toolchain smoke test: clock, counter, PASS
  logic clk = 0;
  int unsigned n = 0;
  always #5 clk = ~clk;
  always @(posedge clk) begin
    n <= n + 1;
    if (n == 10) begin $display("PASS"); $finish; end
  end
endmodule
EOF
verilator --binary -Wall -Wno-fatal hello.sv --top-module hello -Mdir obj \
  && obj/Vhello
```

| You see | It means | Do |
|---|---|---|
| `PASS` | Verilator 5, g++ and make all work | done, go to section 7 |
| error about `--binary` or `--timing` | Verilator 4.x | Appendix A |
| `g++: not found` | build-essential missing | `sudo apt install -y build-essential` |
| `%Warning-...` lines only | normal, `-Wno-fatal` lets it continue | ignore for this test |

The real check, in the repo:

```
cd ~/proj/noc-router-verification && git pull
make help
make check SEEDS="1 2 3"
```

`make check` lints and simulates every `tb/tests/*.f` and writes `logs/summary.txt`; this is what CI runs. Single test: `make sim TEST=tb_fifo SEED=1`. Waveforms: `make sim TEST=tb_fifo SEED=1 WAVES=1` then `make waves TEST=tb_fifo`. On the lab machine add `SIM=xcelium`.

## 7. Daily workflow (nobody pushes to main)

Branch name is `<yourname>/<task>`. One task per branch, one PR per branch, squash-merged, branch deleted after.

```
git switch main && git pull              # start from fresh main
git switch -c revu/input-fifo            # branch: <name>/<task>
# edit files, then:
make check SEEDS="1 2 3"                 # green locally before pushing
git status                               # confirm only the files you meant
git add -A && git commit -m "input_fifo: FWFT read, count output, tb_fifo"
git push -u origin revu/input-fifo
```

The push output contains a "Create a pull request for ..." link; Ctrl+click it.

1. On GitHub: Compare and pull request. Fill the PR template. The reviewer is the owner of the block your change touches (CODEOWNERS pre-fills it).
2. Wait for CI to go green. Red means fix locally, commit, push again; the PR updates itself.
3. After approval: Squash and merge, then Delete branch.
4. Locally: `git switch main && git pull && git branch -d revu/input-fifo`.

If `main` moved while you worked:

```
git fetch
git rebase origin/main                   # replays your commits on top of new main
# fix conflicts: edit, git add <file>, git rebase --continue
git push --force-with-lease               # only ever on your own branch
```

Commit message style: `<block>: what changed, what test covers it`. Every RTL change comes with a test; every bug fix comes with the property or test that would have caught it. Process rules in full are in the README Process section.

## 8. Paste this into docs/SYNC.md

One line per machine.

```
echo "$(whoami) | $(lsb_release -ds) | $(verilator --version) | \
  $(iverilog -V 2>/dev/null | head -1) | git $(git --version | cut -d' ' -f3) | \
  $(ssh -T git@github.com 2>&1 | cut -d'!' -f1)"
```

Example: `revu | Ubuntu 24.04.2 LTS | Verilator 5.020 2024-01-01 | Icarus Verilog version 12.0 (stable) | git 2.43.0 | Hi revu-cbit`

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `wsl --install` fails, `0x80370102` | virtualization off | enable VT-x / SVM in BIOS (section 1 step 1) |
| `wsl --install` prints help text only | WSL already partly installed | `wsl --install -d Ubuntu-24.04` again, or `wsl --list --online` and install by name |
| Ubuntu window opens then closes | WSL kernel outdated | PowerShell: `wsl --update`, then `wsl --shutdown` |
| `Permission denied (publickey)` | key not on your account, or made outside WSL | `ls ~/.ssh/` must show `id_ed25519.pub`; redo 5.2; `ssh -vT git@github.com` shows which key is offered |
| `Connection timed out` on port 22 | port 22 blocked by network | port 443 config in 5.3 |
| `Host key verification failed` | fingerprint changed or mistyped | `ssh-keygen -R github.com`, reconnect, compare fingerprint again |
| `Repository not found` on clone | invite not accepted, or wrong URL | accept invite; check URL |
| `remote: Permission to ... denied` on push | invite not accepted, or pushing to `main` | accept invite; push your branch, not `main` |
| git asks for username/password | HTTPS remote | `git remote set-url` line in 5.5 |
| every file shows as modified after clone | CRLF conversion, repo under `/mnt/c` | reclone under `~/`; `core.autocrlf input` |
| `UNPROTECTED PRIVATE KEY FILE` | key under `/mnt/c` or wrong mode | keep key in `~/.ssh`; `chmod 600 ~/.ssh/id_ed25519` |
| `make` or sim very slow | repo under `/mnt/c` | move to `~/proj` |
| GTKWave opens no window | old WSL without WSLg | `wsl --update`, `wsl --shutdown` |
| `code .` opens nothing | VS Code not on PATH inside WSL | reinstall VS Code with "Add to PATH" ticked; open a new Ubuntu terminal |
| sudo password forgotten | — | PowerShell: `wsl -u root`, then `passwd <username>` |
| Ubuntu disk full, want a clean restart | — | PowerShell: `wsl --unregister Ubuntu-24.04` (deletes everything inside), then section 1 step 2 |

## Appendix A. Verilator from source (only if apt gave 4.x)

Reinstalling WSL with Ubuntu 24.04 is usually faster. If you must stay on 22.04:

```
sudo apt remove -y verilator
sudo apt install -y git help2man perl python3 make g++ libfl2 libfl-dev \
  zlib1g zlib1g-dev ccache autoconf flex bison
cd ~ && git clone https://github.com/verilator/verilator && cd verilator
git checkout v5.024 && autoconf && ./configure
make -j$(nproc) && sudo make install
verilator --version      # Verilator 5.024
```

20-40 min depending on CPU.

## Appendix B. Formal tools: Yosys, SymbiYosys, solvers, sv2v

Aashish now; everyone else by January when the formal cross-check starts. JasperGold on the lab machine is the primary formal flow; this suite reproduces a subset for the open-tool reproducibility claim. One tarball, no compilation.

```
cd ~
API=https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest
URL=$(curl -s $API | grep -o 'https://[^"]*linux-x64[^"]*\.tgz' | head -1)
wget "$URL" && tar xzf oss-cad-suite-linux-x64-*.tgz && rm oss-cad-suite-linux-x64-*.tgz
echo 'export PATH=$PATH:$HOME/oss-cad-suite/bin' >> ~/.bashrc
source ~/.bashrc
sby --help | head -3 && yosys -V && sv2v --version
which verilator          # must still print /usr/bin/verilator
```

~1.5 GB download, 2 GB unpacked. If the `curl` line returns nothing, download the latest linux-x64 `.tgz` by hand from github.com/YosysHQ/oss-cad-suite-build/releases into `~` and continue from `tar`.

The suite bundles its own Verilator and Icarus. It is appended to the end of `PATH` on purpose, so the apt Verilator (the CI version) stays the one `make` uses. Do not prepend it.

## Appendix C. Later, not now

| Tool | Who | When | Install |
|---|---|---|---|
| TeX Live + latexmk | Aashish, then all | paper draft | `sudo apt install -y texlive-latex-extra latexmk` |
| Vivado ML Standard (40 GB, Windows side) | Arnav | after Phase 2 exit | AMD website, free Standard edition, Artix-7 device only |
| matplotlib | Sachin, Aashish | with coverage merge | `pip install --user matplotlib` |
