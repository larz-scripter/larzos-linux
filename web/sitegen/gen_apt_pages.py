#!/usr/bin/env python3
"""Generate /larzos-linux/apt/ (hub) + /larzos-linux/apt/<pkg>/ pages for larzos.com.

Facts here were checked against the published debs (dpkg-deb -c/-e), the live
Packages index, and by running the examples with larzscript 1.41.0.
Regenerates the larzos.com apt pages (add a package = add an entry to PKGS).
Usage: gen_apt_pages.py <saved rocket-fuel-calculator index.html> <outdir>
Deploy: copy <outdir>/larzos-linux/apt/ to /var/www/larzos/larzos-linux/apt/ (see the larzos.com publishing notes).
"""
import html, json, os, sys

SITE = "https://larzos.com"
BASE = "/larzos-linux/apt/"
REPO_URL = "https://github.com/larz-scripter/larzos-linux"
KEYRING = "/usr/share/keyrings/larzos-archive-keyring.gpg"
LASTMOD = "2026-09-21"

ADD_REPO = f"""curl -fsSL {SITE}/apt/KEY.asc | sudo gpg --dearmor -o {KEYRING}
echo "deb [signed-by={KEYRING}] {SITE}/apt stable main" | sudo tee /etc/apt/sources.list.d/larzos.list
sudo apt update"""

E = html.escape


def code(s):
    return "<pre><code>" + E(s) + "</code></pre>"


# ---------------------------------------------------------------- packages
PKGS = [
    dict(
        slug="larzscript", kind="ok", arch="amd64, arm64", deb_kb=2004,
        depends="none", tagline="the money-native programming language",
        meta="Install the Larzscript interpreter with apt on Debian or Ubuntu (amd64, arm64). One static binary, no dependencies: run .lz files, a REPL, a formatter and a C emitter.",
        lede="<code>larzscript</code> is a general-purpose programming language with payments, wallets and metering built into the grammar. The apt package is a single statically-linked binary &mdash; no Python, no runtime, nothing else to pull in.",
        what=[
            "<code>larzscript file.lz</code> runs a program; <code>larzscript -e \"print(1 + 2)\"</code> runs a one-liner; <code>larzscript repl</code> is an interactive REPL; <code>larzscript fmt</code> formats source; <code>--emit-c</code> emits portable C.",
            "Money is part of the language: <code>wallet</code>, <code>price</code>, <code>pay</code> and <code>require</code> are keywords, so a payment can&rsquo;t half-settle.",
            "It is also a normal scripting language &mdash; functions, dicts, f-strings, modules &mdash; and it is what the rest of the LarzOS tools are written in.",
        ],
        files=["/usr/bin/larzscript"],
        example=("""fn fib(n) {
    if n < 2 { return n }
    return fib(n - 1) + fib(n - 2)
}
let words = "the cat the dog the bird".split(" ")
let counts = {}
for w in words { counts[w] = counts.get(w, 0) + 1 }
print(f"fib(10) = {fib(10)}, counts = {counts}")""",
                 "Save as <code>demo.lz</code>, run <code>larzscript demo.lz</code>. Output:",
                 "fib(10) = 55, counts = {the: 3, cat: 1, dog: 1, bird: 1}"),
        example2=("""wallet customer = $20.00
wallet platform
price premium = $9.00

fn buy(buyer) {
    require buyer.balance >= premium, "not enough funds"
    pay premium from buyer to platform
    print(f"paid {premium}; customer has {customer.balance}, platform has {platform.balance}")
}
buy(customer)""", "Money as syntax. Output:",
                  "paid $9.00; customer has $11.00, platform has $9.00"),
        notes=[
            "Installs exactly one file and changes nothing else on the machine &mdash; safe on any Debian or Ubuntu system.",
            "Not on Debian/Ubuntu? Grab the static binary (<code>larzscript-linux-x86_64</code> or <code>larzscript-linux-aarch64</code>) from the <a href=\"https://github.com/larz-scripter/larzscript/releases\">larzscript releases</a>, or run <code>curl -fsSL https://raw.githubusercontent.com/larz-scripter/larzscript/main/install.sh | sh</code>.",
        ],
        related=["larzsh", "larz-system", "larz"],
        gh=("larz-scripter/larzscript", "larzscript on GitHub"),
        faq=[("Does larzscript need Python or any other runtime?", "No. The apt package ships one statically-linked binary with no dependencies."),
             ("Which architectures does the apt package support?", "amd64 and arm64. On other architectures, build it from source &mdash; it is one C file &mdash; or use a release binary from GitHub.")],
    ),
    dict(
        slug="larzsh", kind="ok", arch="all", deb_kb=2,
        depends="larzscript", tagline="an interactive shell written in Larzscript",
        meta="apt install larzsh: an interactive shell whose builtins are Larzscript. Unknown commands fall through to /bin/sh, so pipes and redirection work. Debian and Ubuntu.",
        lede="<code>larzsh</code> is a small interactive shell whose builtins are Larzscript. Anything it doesn&rsquo;t recognise is handed to a real <code>/bin/sh -c</code>, so your normal commands, pipes, redirection and <code>&amp;&amp;</code>/<code>||</code> keep working.",
        what=[
            "Interactive prompt in the form <code>user@host:dir larz$</code>.",
            "<code>larzsh script.lz</code> runs a Larzscript program and exits &mdash; the same binary is a shell and a script runner.",
            "If the interpreter is ever missing, <code>/usr/bin/larzsh</code> falls back to <code>/bin/sh</code> instead of locking you out.",
        ],
        files=["/usr/bin/larzsh", "/usr/lib/larzos/larzsh.lz"],
        example=("""$ larzsh
LarzOS shell (larzsh) - type 'help'
larz@box:/home/larz larz$ echo hello | tr a-z A-Z
HELLO""", None, None),
        notes=["Installing it does not change your login shell; run <code>larzsh</code> to try it."],
        related=["larzscript", "larz", "larz-desktop"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Will larzsh replace bash?", "No. It is installed alongside your shell and only starts when you run <code>larzsh</code>.")],
    ),
    dict(
        slug="larz", kind="ok", arch="all", deb_kb=8,
        depends="larzscript, larz-system", tagline="one command for packages, config, money and AI",
        meta="apt install larz: the LarzOS command-line tool. Install software, preview and apply a declarative system.lz, snapshot and roll back config, ask an AI router. Debian and Ubuntu.",
        lede="<code>larz</code> is the single verb for a LarzOS machine: software, the declarative system spec, configuration generations, a wallet with budgets, an AI router, and fleet commands. On any other Debian or Ubuntu box it is a convenient front end to <code>apt</code> and <code>larz-system</code>.",
        what=[
            "<b>Software:</b> <code>larz install|remove|search &lt;pkg&gt;</code>, <code>larz update</code>, <code>larz upgrade</code>, <code>larz list</code>.",
            "<b>This machine:</b> <code>larz plan</code>, <code>larz apply</code>, <code>larz rollback</code>, <code>larz status</code>, <code>larz snapshot</code>, <code>larz generations</code>, <code>larz switch &lt;n&gt;</code>, <code>larz diff</code>.",
            "<b>Money:</b> <code>larz wallet</code>, <code>larz budget</code>, <code>larz spend</code>. <b>AI:</b> <code>larz ai</code>, <code>larz do</code>, <code>larz explain</code>, <code>larz why</code>. <b>Health:</b> <code>larz doctor</code>.",
            "Ships a man page (<code>man larz</code>) and bash completion.",
        ],
        files=["/usr/bin/larz", "/usr/lib/larzos/larz.lz", "/usr/share/man/man1/larz.1", "/usr/share/bash-completion/completions/larz"],
        example=("""larz install ripgrep          # software
larz plan                     # preview changes to /etc/larzos/system.lz
sudo larz apply               # converge the machine
larz snapshot before-upgrade  # save a configuration generation
larz switch 3                 # roll the whole config back""", "Full reference: <a href=\"/larzos-linux/larz/\">the larz command</a>.", None),
        notes=["Read-only verbs (<code>plan</code>, <code>status</code>, <code>list</code>, <code>diff</code>, <code>doctor</code>) change nothing. <code>apply</code> and <code>switch</code> change the machine &mdash; run <code>larz plan</code> first, and read <a href=\"/larzos-linux/apt/larz-system/\">the larz-system note</a> about the stock <code>system.lz</code>."],
        related=["larz-system", "larz-ai", "larzscript"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Does larz replace apt?", "No. <code>larz install</code> resolves against the LarzOS apt repo first; <code>apt</code> keeps working directly.")],
    ),
    dict(
        slug="larz-system", kind="ok", arch="all", deb_kb=23,
        depends="larzscript", tagline="declarative Linux configuration in one system.lz file",
        meta="apt install larz-system: describe a Linux machine in one Larzscript file (hostname, users, packages, services, audio, GUI), preview with plan, converge with apply. Debian and Ubuntu.",
        lede="<code>larz-system</code> reads a <code>system.lz</code> file &mdash; ordinary Larzscript that can compute values and branch on the host &mdash; diffs it against the live machine, and converges the machine onto it. Same idea as NixOS or Guix, with a Debian executor underneath.",
        what=[
            "<code>larz-system plan</code> previews every change, module by module, and touches nothing. <code>sudo larz-system apply</code> makes it real and records the applied spec in <code>/var/lib/larzos/spec.json</code>.",
            "Modules: <code>hostname</code>, <code>locale</code>, <code>users</code>, <code>packages</code>, <code>systemd</code>, <code>services</code>, <code>audio</code> (PipeWire), <code>ai</code>, <code>budget</code>, <code>gui</code> and <code>branding</code>.",
            "Also installs <code>larz-pkg</code> to build your own <code>.deb</code> files from <code>package.lz</code> recipes.",
        ],
        files=["/usr/bin/larz-system", "/usr/bin/larz-pkg", "/usr/bin/larz-install", "/etc/larzos/system.lz", "/etc/larzos/wallet.toml", "/usr/lib/larzos/&hellip; (the engine and modules)"],
        example=("""import "larzos" as larzos

larzos.system({
  "hostname": "buildbox",
  "users":    [ { "name": "dev", "groups": ["sudo"] } ],
  "packages": ["git", "ripgrep", "tmux"],
  "services": { "ssh": "enabled" },
})""", "Save as <code>/etc/larzos/system.lz</code>, then <code>larz-system plan</code> and <code>sudo larz-system apply</code>.", None),
        notes=[
            "<b>Edit the stock spec before you apply it on a machine that is not LarzOS.</b> The default <code>/etc/larzos/system.lz</code> sets the hostname to <code>larzos</code> and its plan installs <code>larz-claude-code</code>, and the <code>branding</code> module can install <code>larz-branding</code> (which rebrands the host). Installing the package changes none of that &mdash; only <code>apply</code> does &mdash; and <code>larz-system plan</code> shows exactly what would happen.",
            "The <code>packages</code> module installs missing packages via <code>apt-get</code>; it does not remove any.",
        ],
        related=["larz", "larzscript", "larz-gui"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Is larz-system safe to install on an existing server?", "Installing it only drops files. Nothing on the machine changes until you run <code>apply</code>, and <code>plan</code> previews the change first. Edit the stock <code>system.lz</code> before applying &mdash; it sets the hostname to <code>larzos</code>.")],
    ),
    dict(
        slug="larz-ai", kind="ok", arch="all", deb_kb=5,
        depends="larzscript, larz-system, curl", tagline="a local AI router your apps can call",
        meta="apt install larz-ai: a local HTTP router (127.0.0.1:8199) that picks a model per task and proxies chat to a gateway or a local Ollama model, with per-model cost metering.",
        lede="<code>larz-aid</code> is a small daemon that binds <code>127.0.0.1:8199</code>. Apps ask it which model to use for a task and let it make the call, so routing, keys, budgets and receipts live in one place instead of in every app.",
        what=[
            "<code>larz-aid route &lt;task&gt;</code> &mdash; which backend and model would serve a task. <code>larz-aid chat</code> / <code>ask</code> &mdash; one-shot completions. <code>larz-aid models</code> &mdash; configured local models. <code>larz-aid pull &lt;model&gt;</code> &mdash; fetch a local Ollama model. <code>larz-aid serve</code> &mdash; run the HTTP router.",
            "Config is <code>/etc/larzos/ai.toml</code>: gateway URL, default/code/fast model names, an optional local Ollama backend, and USD-per-million-token pricing used to meter spend against the <code>ai</code> budget.",
            "Ships a hardened systemd unit (<code>larz-ai.service</code>: <code>NoNewPrivileges</code>, <code>ProtectSystem=strict</code>, <code>ProtectHome</code>).",
        ],
        files=["/usr/bin/larz-aid", "/usr/lib/larzos/larz-aid.lz", "/etc/larzos/ai.toml", "/lib/systemd/system/larz-ai.service"],
        example=("""$ larz-aid route code
gateway  drlarz-coder
$ larz-aid models
(no local models configured)
$ sudo systemctl enable --now larz-ai   # run the router as a service""", "Real output from a fresh install.", None),
        notes=[
            "Installing does not start or enable the service.",
            "Out of the box, chat requests go to the configured gateway (<code>https://gateway.larzos.com</code>), so prompts leave the machine. Point <code>ollama</code> at a local backend in <code>ai.toml</code> to keep them local.",
        ],
        related=["larz", "larz-system", "larz-claude-code"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Do my prompts leave my machine?", "With the default config, gateway completions are sent to the configured gateway. Configure a local Ollama backend in <code>/etc/larzos/ai.toml</code> to serve models locally.")],
    ),
    dict(
        slug="larz-claude-code", kind="caution", arch="all", deb_kb=5,
        depends="nodejs, npm, ca-certificates, git", tagline="Claude Code plus a larz code wrapper",
        meta="apt install larz-claude-code: installs Anthropic's Claude Code CLI via npm and adds a larz-code wrapper. Read what it changes before installing on a non-LarzOS machine.",
        lede="This package installs <a href=\"https://www.anthropic.com/claude-code\">Claude Code</a> &mdash; Anthropic&rsquo;s terminal coding agent &mdash; with <code>npm install -g @anthropic-ai/claude-code</code> when it configures, and adds <code>larz-code</code> (also <code>larz code</code>), a thin wrapper with first-run hints and optional gateway routing. LarzOS is not affiliated with Anthropic; you sign in with your own account or an <code>ANTHROPIC_API_KEY</code>.",
        what=[
            "<code>larz-code</code> starts Claude Code in the current directory (man page: <code>man larz-code</code>). If <code>claude</code> is already on your PATH the installer leaves it alone.",
            "Config in <code>/etc/larzos/claude-code.toml</code> can route Claude Code through a gateway; both config files are conffiles, so your edits survive upgrades.",
        ],
        files=["/usr/bin/larz-code", "/etc/larzos/claude-code.toml", "/etc/claude-code/CLAUDE.md", "/usr/share/man/man1/larz-code.1"],
        example=("""sudo apt install larz-claude-code
cd my-project
larz code""", "First run signs you in.", None),
        notes=[
            "<b>System-wide instructions.</b> The package writes <code>/etc/claude-code/CLAUDE.md</code>, telling Claude Code that Larzscript is the default language when a task doesn&rsquo;t name one, and to install software with <code>larz install</code>. Outside LarzOS you probably want to edit or empty that file (it is a conffile, so your changes persist).",
            "<b>Network on install.</b> The post-install step runs <code>npm install -g</code>; if you are offline it prints how to retry.",
            "<b>Removal.</b> Removing or purging the package also runs <code>npm uninstall -g @anthropic-ai/claude-code</code>, even if you installed Claude Code yourself first.",
        ],
        related=["larz-ai", "larz", "larz-desktop"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Does this include an Anthropic account or API key?", "No. You sign in with your own account or set <code>ANTHROPIC_API_KEY</code>. LarzOS does not proxy a key it doesn&rsquo;t have.")],
    ),
    dict(
        slug="larz-gui", kind="ok", arch="all", deb_kb=1,
        depends="dbus-x11, openbox, tint2, pcmanfm, lxterminal, rofi, tigervnc-standalone-server, imagemagick, feh",
        tagline="a lightweight Openbox desktop served over VNC",
        meta="apt install larz-gui: metapackage for a lightweight graphical desktop (Openbox, tint2, PCManFM, rofi) served over TigerVNC. Made for phones, containers and headless servers.",
        lede="<code>larz-gui</code> is a metapackage: it ships no files of its own and pulls in a small desktop &mdash; Openbox, tint2, PCManFM, LXTerminal, rofi &mdash; plus TigerVNC. It exists for machines with no native display, such as proot on Android, containers and cloud boxes.",
        what=[
            "Everything it installs is stock Debian/Ubuntu software; removing <code>larz-gui</code> leaves those packages for <code>apt autoremove</code>.",
            "Pair it with the <code>gui</code> block in <a href=\"/larzos-linux/apt/larz-system/\">system.lz</a> to have <code>larz-system</code> write the theme and VNC config. Run <code>vncpasswd</code> once before starting it.",
        ],
        files=["(no files &mdash; dependencies only)"],
        example=("""sudo apt install larz-gui
vncpasswd""", None, None),
        notes=["Safe on any Debian or Ubuntu system; it only adds packages."],
        related=["larz-system", "larz-desktop", "larzsh"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[],
    ),
    dict(
        slug="larz-desktop", kind="warn", arch="all", deb_kb=1,
        depends="larz-branding, larz, larzsh, larz-ai, larz-system, larz-claude-code, pipewire, pipewire-jack, wireplumber, rtkit",
        tagline="the full LarzOS setup in one metapackage",
        meta="apt install larz-desktop: the LarzOS metapackage (larz, larzsh, larz-ai, larz-system, Claude Code, low-latency PipeWire audio). It also rebrands the host - read this first.",
        lede="<code>larz-desktop</code> is the &ldquo;give me LarzOS&rdquo; metapackage: the <code>larz</code> command, the Larzscript shell, the AI router, <code>larz-system</code>, Claude Code, and a low-latency PipeWire audio stack. It ships no files itself.",
        what=[
            "Depends on every LarzOS tool <em>including</em> <a href=\"/larzos-linux/apt/larz-branding/\">larz-branding</a> and <a href=\"/larzos-linux/apt/larz-claude-code/\">larz-claude-code</a> &mdash; so installing it also rebrands the host and adds Claude Code.",
            "Audio comes from <code>pipewire</code>, <code>pipewire-jack</code>, <code>wireplumber</code> and <code>rtkit</code>.",
        ],
        files=["(no files &mdash; dependencies only)"],
        example=("""# on an existing machine you want to keep as-is, pick just the tools:
sudo apt install larzscript larz larz-system

# on a fresh or dedicated machine, the whole thing:
sudo apt install larz-desktop""", None, None),
        notes=["<b>On a machine you care about, install the individual tools instead.</b> <code>larz-desktop</code> is meant for LarzOS itself and fresh, dedicated boxes. It changes <code>/etc/os-release</code>, GRUB and more &mdash; see <a href=\"/larzos-linux/apt/larz-branding/\">larz-branding</a> for the full list and how to undo it."],
        related=["larz-branding", "larz-claude-code", "larz-gui"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[],
    ),
    dict(
        slug="larz-branding", kind="warn", arch="all", deb_kb=36,
        depends="larzscript", tagline="stamps the LarzOS identity onto a Debian/Ubuntu system",
        meta="apt install larz-branding: makes a Debian or Ubuntu machine present as LarzOS (os-release, MOTD, GRUB, Plymouth, dpkg vendor). Reversible. Know what it changes first.",
        lede="<code>larz-branding</code> makes the machine present as LarzOS: <code>os-release</code>, login banner, MOTD, GRUB, a Plymouth boot theme, the dpkg vendor and the logo. Debian or Ubuntu stays underneath. <b>It rewrites system identity files the moment it is configured</b>, so install it deliberately.",
        what=[
            "On install, <code>larz-rebrand apply</code> writes <code>/usr/lib/os-release</code> (the <code>/etc/os-release</code> symlink follows), <code>/etc/issue</code>, <code>/etc/issue.net</code>, <code>/etc/lsb-release</code>, <code>/etc/motd</code>, <code>/etc/machine-info</code>, an <code>/etc/update-motd.d/00-larzos</code> hook, a GRUB drop-in at <code>/etc/default/grub.d/99-larzos.cfg</code>, <code>/etc/profile.d/larzos.sh</code>, and points <code>/etc/dpkg/origins/default</code> at a LarzOS vendor file.",
            "It activates the Plymouth theme if Plymouth is present and runs <code>update-grub</code> if <code>/boot/grub</code> exists.",
            "After branding, <code>os-release</code> reports <code>ID=larzos</code> and <code>ID_LIKE=debian</code>. Scripts that branch on <code>ID=ubuntu</code> will no longer match.",
        ],
        files=["/usr/bin/larz-rebrand", "/usr/lib/larzos/larz-rebrand.lz", "/usr/share/larzos/branding/&hellip; (os-release, issue, MOTD, GRUB, Plymouth theme, logo)"],
        example=("""larz-rebrand status     # what is branded right now
sudo larz-rebrand restore   # put the originals back""", None, None),
        notes=[
            "<b>Reversible.</b> Before replacing a file it keeps a one-time <code>.pre-larzos</code> backup. <code>larz-rebrand restore</code> puts the originals back, and removing the package runs the same restore.",
            "Don&rsquo;t install this on a machine whose identity other tooling depends on unless you are prepared to restore it.",
        ],
        related=["larz-desktop", "larz-system", "larzscript"],
        gh=("larz-scripter/larzos-linux", "larzos-linux on GitHub"),
        faq=[("Can I undo larz-branding?", "Yes. Run <code>sudo larz-rebrand restore</code> or remove the package; both restore the original files from the <code>.pre-larzos</code> backups.")],
    ),
]
SHORT = {
    "larzscript": "Install the Larzscript interpreter with apt on Debian or Ubuntu (amd64, arm64). One static binary, no dependencies: scripts, REPL, formatter.",
    "larzsh": "apt install larzsh: an interactive shell with Larzscript builtins. Unknown commands fall through to /bin/sh, so pipes and redirection work.",
    "larz": "apt install larz: one command to install software, preview and apply a declarative system.lz, roll back config and ask an AI router. Debian, Ubuntu.",
    "larz-system": "apt install larz-system: describe a Linux machine in one file (hostname, users, packages, services), preview with plan, converge with apply.",
    "larz-ai": "apt install larz-ai: a local HTTP router on 127.0.0.1:8199 that picks a model per task, proxies chat to a gateway or Ollama and meters cost.",
    "larz-claude-code": "apt install larz-claude-code: installs Anthropic's Claude Code via npm plus a larz-code wrapper. What it changes on a non-LarzOS machine.",
    "larz-gui": "apt install larz-gui: a lightweight Openbox desktop served over TigerVNC, for phones, containers and headless servers. Debian and Ubuntu.",
    "larz-desktop": "apt install larz-desktop: the full LarzOS metapackage (larz, larzsh, AI router, Claude Code, PipeWire). It also rebrands the host: read first.",
    "larz-branding": "apt install larz-branding: makes Debian or Ubuntu present as LarzOS (os-release, MOTD, GRUB, Plymouth). Reversible; know what it changes.",
}
for _p in PKGS:
    _p["meta"] = SHORT[_p["slug"]]
BY = {p["slug"]: p for p in PKGS}

KIND = {
    "ok": ("Safe on any Debian/Ubuntu", "ok"),
    "caution": ("Read first: adds system-wide config", "caution"),
    "warn": ("Rebrands the host: read first", "warn"),
}

STYLE = """<style>
  main{max-width:860px}
  h1{font-size:clamp(28px,5vw,42px);line-height:1.12}
  .lede{font-size:clamp(16px,2.4vw,19px);color:var(--muted);margin-top:14px}
  h2{margin-top:44px;font-size:24px}
  h3{margin-top:26px;font-size:16px}
  table{border-collapse:collapse;width:100%;margin-top:16px;font-size:14px}
  th,td{border:1px solid var(--border);padding:9px 11px;text-align:left;vertical-align:top}
  th{background:var(--card)}
  pre{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px;overflow-x:auto;font-size:13px;line-height:1.55}
  code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
  p code,li code,td code{background:var(--card);border:1px solid var(--border);border-radius:5px;padding:1px 5px;font-size:.92em}
  ul{line-height:1.8}
  .muted{color:var(--muted)}
  .crumbs{font-size:13px;color:var(--muted);margin-bottom:18px}
  .crumbs a{color:var(--muted)}
  .badge{display:inline-block;font-size:12px;font-weight:700;border-radius:999px;padding:3px 10px;border:1px solid var(--border);background:var(--card)}
  .badge.ok{color:#3ecf8e;border-color:#3ecf8e55}
  .badge.caution{color:#f5b942;border-color:#f5b94255}
  .badge.warn{color:#ff6b6b;border-color:#ff6b6b55}
  .meta{display:flex;flex-wrap:wrap;gap:8px 18px;margin-top:16px;font-size:13px;color:var(--muted)}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px;margin-top:16px}
  .grid a{display:block;background:var(--card);border:1px solid var(--border);border-radius:12px;padding:14px 16px;text-decoration:none;color:var(--text)}
  .grid a:hover{border-color:var(--accent)}
  .grid b{display:block;font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
  .grid span{display:block;font-size:13px;color:var(--muted);margin-top:4px}
  .out{margin-top:-8px}
  .note{border-left:3px solid var(--accent);padding:2px 0 2px 14px;margin:14px 0}
  .note.caution{border-color:#f5b942}.note.warn{border-color:#ff6b6b}
  details{border-top:1px solid var(--border);padding:12px 0}
  summary{cursor:pointer;font-weight:600}
  hr{border:0;border-top:1px solid var(--border);margin:36px 0}
  @media(max-width:600px){.tbl{overflow-x:auto}}
</style>"""


def head(title, desc, canon, ld):
    scripts = "\n".join('<script type="application/ld+json">' + json.dumps(x, ensure_ascii=False, separators=(",", ":")) + "</script>" for x in ld)
    return f"""<!doctype html>
<html lang="en">
<head><!--LZCRIT--><meta name="color-scheme" content="dark"><style>html{{background:#0b0f1a;color-scheme:dark}}body{{background:#0b0f1a;color:#e8edf5}}</style><!--/LZCRIT-->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{E(title)}</title>
<meta name="description" content="{E(desc, quote=True)}">
<link rel="canonical" href="{canon}">
<meta property="og:title" content="{E(title, quote=True)}">
<meta property="og:description" content="{E(desc, quote=True)}">
<meta property="og:type" content="website">
<meta property="og:url" content="{canon}">
<meta property="og:site_name" content="Larz OS">
<meta name="twitter:card" content="summary">
<meta name="robots" content="index,follow,max-snippet:-1">
<link rel="stylesheet" href="/assets/content.css">
{scripts}
{STYLE}
</head>
"""


def crumb_ld(items):
    return {"@context": "https://schema.org", "@type": "BreadcrumbList",
            "itemListElement": [{"@type": "ListItem", "position": i + 1, "name": n, "item": u} for i, (n, u) in enumerate(items)]}


def crumbs_html(items):
    parts = [f'<a href="{u.replace(SITE, "")}">{E(n)}</a>' for n, u in items[:-1]] + [E(items[-1][0])]
    return '<p class="crumbs">' + " &rsaquo; ".join(parts) + "</p>"


def faq_ld(qas):
    import re
    strip = lambda s: html.unescape(re.sub(r"<[^>]+>", "", s))
    return {"@context": "https://schema.org", "@type": "FAQPage",
            "mainEntity": [{"@type": "Question", "name": strip(q), "acceptedAnswer": {"@type": "Answer", "text": strip(a)}} for q, a in qas]}


def install_block(pkg):
    return f"""<h2>Install</h2>
<p>One line &mdash; adds the signed LarzOS apt repo, then installs <code>{pkg}</code>:</p>
{code(f"curl -fsSL {SITE}/larzos-linux/install.sh | sudo sh -s -- {pkg}")}
<p>Or add the repo yourself once (details on the <a href="{BASE}">apt repository page</a>) and use plain <code>apt</code> from then on:</p>
{code(ADD_REPO)}
{code(f"sudo apt install {pkg}")}"""


def pkg_page(p):
    slug = p["slug"]
    canon = f"{SITE}{BASE}{slug}/"
    title = f"apt install {slug} — {p['tagline']}"
    if len(title) > 68:
        title = f"apt install {slug} on Debian & Ubuntu"
    crumbs = [("Larz OS", SITE + "/"), ("LarzOS (Linux)", SITE + "/larzos-linux/"), ("apt packages", SITE + BASE), (slug, canon)]
    app = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": slug,
           "description": p["meta"], "url": canon, "applicationCategory": "DeveloperApplication",
           "operatingSystem": "Debian, Ubuntu (Linux)", "license": "https://opensource.org/licenses/MIT",
           "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
           "author": {"@type": "Organization", "name": "LarzOS", "url": SITE + "/"},
           "isPartOf": {"@type": "WebPage", "url": SITE + BASE}, "installUrl": SITE + "/larzos-linux/install.sh"}
    ld = [app, crumb_ld(crumbs)]
    if p["faq"]:
        ld.append(faq_ld(p["faq"]))
    label, cls = KIND[p["kind"]]
    b = [crumbs_html(crumbs),
         f"<h1><code>apt install {slug}</code></h1>",
         f'<p class="lede">{p["lede"]}</p>',
         f'<p><span class="badge {cls}">{label}</span></p>',
         f'<div class="meta"><span>Architecture: <b>{p["arch"]}</b></span><span>Depends: <b>{p["depends"]}</b></span><span>Licence: <b>MIT</b></span></div>',
         install_block(slug),
         "<h2>What you get</h2><ul>" + "".join(f"<li>{w}</li>" for w in p["what"]) + "</ul>"]
    ex, cap, out = p["example"]
    b.append("<h2>Example</h2>")
    b.append(code(ex))
    if cap:
        b.append(f"<p>{cap}</p>")
    if out:
        b.append(code(out).replace("<pre>", '<pre class="out">', 1))
    if p.get("example2"):
        e2, c2, o2 = p["example2"]
        b.append(code(e2)); b.append(f"<p>{c2}</p>"); b.append(code(o2).replace("<pre>", '<pre class="out">', 1))
    b.append("<h2>Files it installs</h2><ul>" + "".join(f"<li>{'<code>'+f+'</code>' if f.startswith('/') and '&hellip;' not in f else f}</li>" for f in p["files"]) + "</ul>")
    nc = "warn" if p["kind"] == "warn" else ("caution" if p["kind"] == "caution" else "")
    b.append("<h2>Before you install it elsewhere</h2>" + "".join(f'<div class="note {nc}"><p>{n}</p></div>' for n in p["notes"]))
    b.append(f"<h2>Uninstall</h2>{code(f'sudo apt remove {slug}')}")
    if p["faq"]:
        b.append("<h2>FAQ</h2>" + "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in p["faq"]))
    rel = "".join(f'<a href="{BASE}{r}/"><b>{r}</b><span>{BY[r]["tagline"]}</span></a>' for r in p["related"])
    b.append(f'<h2>Related tools</h2><div class="grid">{rel}</div>')
    b.append(f'<hr><p class="muted">Source: <a href="https://github.com/{p["gh"][0]}">{p["gh"][1]}</a> &middot; all packages: <a href="{BASE}">LarzOS apt repository</a> &middot; <a href="/larzos-linux/">LarzOS overview</a>.</p>')
    return title, p["meta"], canon, ld, "\n".join(b)


def hub_page():
    canon = SITE + BASE
    title = "apt install larzscript — LarzOS apt repo for Debian & Ubuntu"
    desc = "A signed apt repo of Larzscript and Linux tools: the larzscript language, declarative system config, a shell, an AI router. Works on any Debian or Ubuntu."
    crumbs = [("Larz OS", SITE + "/"), ("LarzOS (Linux)", SITE + "/larzos-linux/"), ("apt packages", canon)]
    faq = [
        ("Do I need to run LarzOS to use these packages?", "No. They are ordinary .deb packages from a signed apt repository and install on any Debian- or Ubuntu-family Linux (amd64 or arm64) with apt. Most of them only add files and change nothing else."),
        ("Which packages are safe on a machine I want to keep as it is?", "larzscript, larzsh, larz, larz-system, larz-ai and larz-gui only add files or packages. larz-claude-code adds system-wide Claude Code instructions. larz-branding and larz-desktop rebrand the host (os-release, GRUB and more) and should be installed deliberately."),
        ("Is the repository signed?", "Yes. The Release file is signed with the LarzOS Archive Signing Key (larz@larzos.com); the commands on this page install the key into a dedicated keyring and pin the repo to it with signed-by."),
        ("Which architectures are supported?", "amd64 and arm64. The larzscript package ships a binary for each; the rest are architecture-independent."),
        ("What about Fedora, Arch, macOS or Windows?", "The apt packages target Debian and Ubuntu. On other systems, download a static larzscript binary from the GitHub releases page (Linux x86_64 and aarch64, macOS, Windows) or use its install script."),
        ("How do I remove the repository?", "Delete /etc/apt/sources.list.d/larzos.list and /usr/share/keyrings/larzos-archive-keyring.gpg, then run sudo apt update."),
    ]
    items = [{"@type": "ListItem", "position": i + 1, "url": f"{canon}{p['slug']}/", "name": p["slug"]} for i, p in enumerate(PKGS)]
    ld = [
        {"@context": "https://schema.org", "@type": "CollectionPage", "name": "LarzOS apt repository", "url": canon,
         "description": desc, "isPartOf": {"@type": "WebSite", "name": "Larz OS", "url": SITE + "/"},
         "mainEntity": {"@type": "ItemList", "itemListElement": items}},
        crumb_ld(crumbs), faq_ld(faq),
    ]
    rows = ""
    for p in PKGS:
        label, cls = KIND[p["kind"]]
        rows += f'<tr><td><a href="{BASE}{p["slug"]}/"><code>{p["slug"]}</code></a></td><td>{p["tagline"][0].upper() + p["tagline"][1:]}</td><td>{p["arch"]}</td><td><span class="badge {cls}">{label}</span></td></tr>\n'
    cards = "".join(f'<a href="{BASE}{p["slug"]}/"><b>{p["slug"]}</b><span>{p["tagline"]}</span></a>' for p in PKGS)
    b = f"""{crumbs_html(crumbs)}
<h1>apt install Larzscript &amp; Linux tools</h1>
<p class="lede">The LarzOS apt repository is a signed <code>.deb</code> repo of tools for building things on Linux: the <a href="{BASE}larzscript/">Larzscript language</a>, <a href="{BASE}larz-system/">declarative system config</a>, a <a href="{BASE}larzsh/">shell</a>, an <a href="{BASE}larz-ai/">AI router</a> and more. It runs on LarzOS, and on <b>any Debian or Ubuntu</b> machine (amd64 or arm64) &mdash; you don&rsquo;t need the whole distro.</p>

<h2>Add the repo (once)</h2>
{code(ADD_REPO)}
<p>Then install whatever you need:</p>
{code("sudo apt install larzscript larz-system")}
<p>Prefer one line? <code>curl -fsSL {SITE}/larzos-linux/install.sh | sudo sh -s -- larzscript</code> does the same, and it refuses to run on non-Debian systems. You can read the <a href="/larzos-linux/install.sh">install script</a> first.</p>

<h2>Every package</h2>
<div class="tbl"><table>
<tr><th>Package</th><th>What it is</th><th>Arch</th><th>On a non-LarzOS machine</th></tr>
{rows}</table></div>
<div class="grid">{cards}</div>

<h2>Build something with it</h2>
<ul>
<li><b>Script anything.</b> <code>sudo apt install larzscript</code>, write a <code>.lz</code> file, run it. One static binary, no runtime. <a href="{BASE}larzscript/">Examples</a>.</li>
<li><b>Describe a machine in one file.</b> <code>larz-system</code> turns a <code>system.lz</code> into hostname, users, packages, services, audio and a VNC desktop &mdash; preview with <code>plan</code>, then <code>apply</code>. <a href="{BASE}larz-system/">How it works</a>.</li>
<li><b>Put money in the language.</b> Wallets, prices and <code>pay</code>/<code>require</code> are syntax, so payment logic can&rsquo;t half-settle. <a href="{BASE}larzscript/">See the wallet example</a>.</li>
<li><b>Give your apps one AI endpoint.</b> <code>larz-aid</code> listens on <code>127.0.0.1:8199</code> and routes each task to a gateway or local model, metering cost. <a href="{BASE}larz-ai/">Details</a>.</li>
<li><b>Ship your own tool.</b> A package is a <code>package.lz</code> recipe; <code>larz-pkg</code> builds the <code>.deb</code>. See the <a href="{REPO_URL}/blob/main/docs/design.md">design notes</a> and the <a href="{REPO_URL}">larzos-linux repo</a>.</li>
</ul>

<h2>Read this before installing on a machine you care about</h2>
<div class="note"><p><b>Most packages only add files.</b> <code>larzscript</code>, <code>larzsh</code>, <code>larz</code>, <code>larz-system</code>, <code>larz-ai</code> and <code>larz-gui</code> change nothing until you use them.</p></div>
<div class="note caution"><p><b><a href="{BASE}larz-claude-code/">larz-claude-code</a></b> installs Claude Code through npm and writes system-wide instructions to <code>/etc/claude-code/CLAUDE.md</code>.</p></div>
<div class="note warn"><p><b><a href="{BASE}larz-branding/">larz-branding</a> and <a href="{BASE}larz-desktop/">larz-desktop</a></b> rewrite <code>os-release</code>, GRUB and other identity files (reversible with <code>larz-rebrand restore</code>). <code>larz-desktop</code> pulls in both, so install the individual tools instead unless the machine is dedicated.</p></div>
<div class="note"><p><b>The stock <code>/etc/larzos/system.lz</code> sets the hostname to <code>larzos</code>.</b> Edit it, and run <code>larz-system plan</code>, before you <code>apply</code>.</p></div>

<h2>FAQ</h2>
{"".join(f"<details><summary>{E(q)}</summary><p>{E(a)}</p></details>" for q, a in faq)}

<hr>
<p class="muted">Source and issues: <a href="{REPO_URL}">github.com/larz-scripter/larzos-linux</a> (MIT). Language: <a href="https://github.com/larz-scripter/larzscript">github.com/larz-scripter/larzscript</a>. Overview: <a href="/larzos-linux/">LarzOS</a> &middot; <a href="/larzos-linux/larz/">the larz command</a> &middot; <a href="/larzos-linux/different/">what makes it different</a>.</p>"""
    return title, desc, canon, ld, b


def main():
    rocket = open(sys.argv[1], encoding="utf-8").read()
    out = sys.argv[2]
    top = rocket[rocket.index("<body"):rocket.index("<main")]
    tail = rocket[rocket.index("<!--LZA-->"):]
    assert "<!--LZNAV-->" in tail and "<!--LZFOOT-->" in tail
    pages = [("index.html", hub_page())] + [(f"{p['slug']}/index.html", pkg_page(p)) for p in PKGS]
    for rel, (title, desc, canon, ld, body) in pages:
        path = os.path.join(out, "larzos-linux", "apt", rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(head(title, desc, canon, ld) + top + "<main>\n" + body + "\n\n</main>\n" + tail)
        print(f"{len(title):3d} {len(desc):3d} {canon}")


if __name__ == "__main__":
    main()
