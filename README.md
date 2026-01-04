# nix-clawdbot

> Declarative Clawdbot. Bulletproof by default.
>
> macOS only. Linux/Windows are out of scope for now.
>
> <sub>Questions? Join the Clawdbot Discord and ask in **#nix-packaging**: https://discord.com/channels/1456350064065904867/1457003026412736537</sub>

## Table of Contents

- [What You Get](#what-you-get)
- [Why Nix?](#why-nix)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Plugins](#plugins)
- [Configuration](#configuration)
- [Advanced](#advanced)
- [Reference](#reference)
- [Philosophy](#philosophy)

---

## What You Get

```
Me: "what's on my screen?"
Bot: *takes screenshot, describes it*

Me: "play some jazz"
Bot: *opens Spotify, plays jazz*

Me: "transcribe this voice note"
Bot: *runs whisper, sends you text*
```

You talk to Telegram, your Mac does things.

**One flake, everything works.** Gateway, macOS app, whisper, spotify, camera tools - all wired up and pinned.

**Plugins are self-contained.** Each plugin declares its CLI tools in Nix. You enable it, the build and wiring happens automatically.

**Bulletproof.** Nix locks every dependency. No version drift, no surprises. `home-manager switch` to update, `home-manager generations` to rollback instantly.

---

## Why Nix?

You've probably installed tools before. Homebrew, pip, npm - they work until they don't.

**What you deal with today:**
- Update one thing, break another ("but it worked yesterday")
- Reinstall everything after a macOS upgrade
- "Works on my machine" when sharing setups
- No easy way to undo a bad update

**What Nix gives you:**
- Every dependency pinned to exact versions. Forever.
- Update breaks something? `home-manager switch --rollback` - back in 30 seconds.
- Share your config file, get the exact same setup on another Mac.
- Tools don't pollute your system - they live in isolation.

You don't need to learn Nix deeply. You describe what you want, Nix figures out how to build it.

<details>
<summary><strong>How it actually works</strong></summary>

![On declarative build systems](docs/images/on-declarative-build-systems.png)

Nix is a **declarative package manager**. Instead of running commands to install things, you write a config file that says "I want these tools at these versions." Nix reads that file and builds everything in `/nix/store` - isolated from your system.

**The hashing magic:** Every package in Nix is identified by a cryptographic hash of *all* its inputs - source code, dependencies, build flags, everything. Change anything, get a different hash. This means:
- Two machines with the same hash have *identical* builds. Byte-for-byte.
- Old versions stick around (different hash = different path). Nothing gets overwritten.
- Rollback is instant - just point to the old hash.

**Key terms you'll see:**
- **Flake**: A config file (`flake.nix`) that pins all your dependencies. Think `package-lock.json` but for your entire system.
- **Home Manager**: Manages your user config (dotfiles, apps, services) through Nix.
- **`home-manager switch`**: The command that applies your config. Run it after any change.

</details>

---

## Quick Start

### Option 1: Let your agent set it up (recommended)

Copy this entire block and paste it to Claude, Cursor, or your preferred AI assistant:

```text
I want to set up nix-clawdbot on my Mac.

Repository: github:clawdbot/nix-clawdbot

What nix-clawdbot is:
- Batteries-included Nix package for Clawdbot (AI assistant gateway)
- Installs gateway + macOS app + tools (whisper, spotify, cameras, etc)
- Runs as a launchd service, survives reboots

What I need you to do:
1. Check if Determinate Nix is installed (if not, install it)
2. Create a local flake at ~/code/clawdbot-local using templates/agent-first/flake.nix
3. Create a docs dir next to the config (e.g., ~/code/clawdbot-local/documents) with AGENTS.md, SOUL.md, TOOLS.md
   - If ~/.clawdbot/workspace already has these files, adopt them into the documents dir first
3. Help me create a Telegram bot (@BotFather) and get my chat ID (@userinfobot)
4. Set up secrets (bot token, Anthropic key) - plain files at ~/.secrets/ is fine
5. Fill in the template placeholders and run home-manager switch
6. Verify: launchd running, bot responds to messages

My setup:
- macOS version: [FILL IN]
- CPU: [arm64 / x86_64]
- Home Manager config name: [FILL IN or "I don't have Home Manager yet"]

Reference the README and templates/agent-first/flake.nix in the repo for the module options.
```

Your agent will install Nix, create your config, and get Clawdbot running. You just answer its questions.

**What happens next:**
1. Your agent sets everything up and runs `home-manager switch`
2. You message your Telegram bot for the first time
3. Clawdbot runs its **bootstrap ritual** - it asks you playful questions: *"Who am I? What am I? Who are you?"* - to learn its identity and yours
4. Once you've named it and introduced yourself, the bootstrap is done. You're up and running.

<details>
<summary><strong>Option 2: Manual setup</strong></summary>

If you prefer to understand each step:

1. **Install Determinate Nix** (if you haven't already):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Create your local config directory:**
   ```bash
   mkdir -p ~/code/clawdbot-local && cd ~/code/clawdbot-local
   ```

3. **Copy the starter template:**
   ```bash
   nix flake init -t github:clawdbot/nix-clawdbot#agent-first
   ```

4. **Fill in the placeholders** in `flake.nix`:
   - Your macOS username (`whoami`)
   - Your system (`aarch64-darwin` for Apple Silicon, `x86_64-darwin` for Intel)
   - Paths to your secrets (Telegram bot token, Anthropic API key)
   - Your Telegram user ID (get it from @userinfobot)

5. **Apply the config:**
   ```bash
   home-manager switch --flake .#yourusername
   ```

6. **Verify it's running:**
   ```bash
   launchctl print gui/$UID/com.steipete.clawdbot.gateway | grep state
   ```

</details>

---

## How It Works

```
You (Telegram) --> Gateway --> Tools --> Your Mac does things
```

**Gateway**: The brain. A service running on your Mac that receives your Telegram messages and decides what to do. Managed by launchd (macOS's built-in service manager) so it survives reboots.

**Plugins**: Bundles that contain two things:
1. **CLI tools** - actual programs that do stuff (take screenshots, control Spotify, transcribe audio)
2. **Skills** - markdown files that teach the AI *how* to use those tools

When you enable a plugin, Nix installs the tools and wires up the skills to Clawdbot automatically - the gateway learns what it can do.

**Skills**: Instructions for the AI. A skill file says "when the user wants X, run this command." The AI reads these to know what it can do.

<details>
<summary><strong>Under the hood</strong></summary>

When you run `home-manager switch`:

1. Nix reads your `flake.nix` and resolves all plugin sources (GitHub repos, local paths)
2. For each plugin, Nix looks for a `clawdbotPlugin` output that declares:
   - What CLI packages to install
   - What skill files to copy
   - What environment variables it needs
3. Tools go on your PATH, skills get symlinked to `~/.clawdbot/workspace/skills/`
4. A launchd service is created/updated to run the gateway
5. The gateway starts, loads skills, connects to Telegram

All state lives in `~/.clawdbot/`. Logs at `/tmp/clawdbot/clawdbot-gateway.log`.

</details>

---

## Plugins

Plugins extend what Clawdbot can do. Each plugin bundles tools and teaches the AI how to use them.

### First-party plugins

These ship with nix-clawdbot. Toggle them in your config:

```nix
programs.clawdbot.firstParty = {
  summarize.enable = true;   # Summarize web pages, PDFs, videos
  peekaboo.enable = true;    # Take screenshots
  oracle.enable = false;     # Web search
  poltergeist.enable = false; # Control your Mac's UI
  sag.enable = false;        # Text-to-speech
  camsnap.enable = false;    # Camera snapshots
  gogcli.enable = false;     # Google Calendar
  bird.enable = false;       # Twitter/X
  sonoscli.enable = false;   # Sonos control
  imsg.enable = false;       # iMessage
};
```

| Plugin | What it does |
|--------|--------------|
| `summarize` | Summarize URLs, PDFs, YouTube videos |
| `peekaboo` | Screenshot your screen |
| `oracle` | Search the web |
| `poltergeist` | Click, type, control macOS UI |
| `sag` | Text-to-speech |
| `camsnap` | Take photos from connected cameras |
| `gogcli` | Google Calendar integration |
| `bird` | Twitter/X integration |
| `sonoscli` | Control Sonos speakers |
| `imsg` | Send/read iMessages |

### Adding community plugins

Tell your agent: *"Add the plugin from github:owner/repo-name"*

Or add it manually to your config:

```nix
plugins = [
  { source = "github:owner/repo-name"; }
];
```

Then run `home-manager switch` to install.

### Plugins with configuration

Some plugins need settings (auth files, preferences). Here's a simplified example:

```nix
# Example: a padel court booking plugin (simplified for illustration)
plugins = [
  {
    source = "github:example/padel-cli";
    config = {
      env = {
        PADEL_AUTH_FILE = "~/.secrets/padel-auth";  # where your login token lives
      };
      settings = {
        default_city = "Barcelona";
        preferred_times = [ "18:00" "20:00" ];
      };
    };
  }
];
```

- `config.env` - paths to secrets/auth files the plugin needs
- `config.settings` - preferences (rendered to `config.json` for the plugin)

<details>
<summary><strong>For plugin developers</strong></summary>

Want to make your tool available as a Clawdbot plugin? Here's the contract.

**Minimum structure:**

```
your-plugin/
  flake.nix          # Declares the plugin
  skills/
    your-skill/
      SKILL.md       # Instructions for the AI
```

**Your `flake.nix` must export `clawdbotPlugin`:**

```nix
{
  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = builtins.currentSystem; };
    in {
      clawdbotPlugin = {
        name = "hello-world";
        skills = [ ./skills/hello-world ];
        packages = [ pkgs.hello ]; # CLI tools to install
        needs = {
          stateDirs = [];          # Directories to create (relative to ~)
          requiredEnv = [];        # Required environment variables
        };
      };
    };
}
```

**Your `SKILL.md` teaches the AI:**

```md
---
name: hello-world
description: Prints hello world.
---

Use the `hello` CLI to print a greeting.
```

See `examples/hello-world-plugin` for a complete working example.

---

**Full plugin authoring prompt** - paste this to your AI agent to make any repo nix-clawdbot-native:

```text
Goal: Make this repo a nix-clawdbot-native plugin with the standard contract.

Contract to implement:
1) Add clawdbotPlugin output in flake.nix:
   - name
   - skills (paths to SKILL.md dirs)
   - packages (CLI packages to put on PATH)
   - needs (stateDirs + requiredEnv)

Example:
clawdbotPlugin = {
  name = "my-plugin";
  skills = [ ./skills/my-plugin ];
  packages = [ self.packages.${system}.default ];
  needs = {
    stateDirs = [ ".config/my-plugin" ];
    requiredEnv = [ "MYPLUGIN_AUTH_FILE" ];
  };
};

2) Make the CLI explicitly configurable by env (no magic defaults):
   - Support an auth file env (e.g., MYPLUGIN_AUTH_FILE)
   - Honor XDG_CONFIG_HOME or a plugin-specific config dir env

3) Provide AGENTS.md in the plugin repo:
   - Plain-English explanation of knobs + values
   - Generic placeholders only (no real secrets)
   - Explain where credentials live (e.g., /run/agenix/...)

4) Update SKILL.md to call the CLI by its PATH name.

Standard plugin config shape (Nix-native, no JSON strings):

plugins = [
  {
    source = "github:owner/my-plugin";
    config = {
      env = {
        MYPLUGIN_AUTH_FILE = "/run/agenix/myplugin-auth";
      };
      settings = {
        name = "EXAMPLE_NAME";
        enabled = true;
        retries = 3;
        tags = [ "alpha" "beta" ];
        window = { start = "08:00"; end = "18:00"; };
        options = { mode = "fast"; level = 2; };
      };
    };
  }
];

Config flags the host will use:
- `config.env` for required env vars (e.g., MYPLUGIN_AUTH_FILE)
- `config.settings` for typed config keys (rendered to config.json in the first stateDir)

CI note:
- If the repo uses Garnix, add the plugin build to its `garnix.yaml` (or equivalent) so CI verifies it.

Why: explicit, minimal, fail-fast, no inline JSON strings.
Deliverables: flake output, env overrides, AGENTS.md, skill update.
```

</details>

---

## Configuration

> **Note:** You probably don't need to write this yourself. Your AI agent handles this when you use the [Quick Start](#quick-start) copypasta. These examples are here for reference.

### What Clawdbot needs (minimum)

1. **Telegram bot token** - create via [@BotFather](https://t.me/BotFather), save to a file
2. **Your Telegram user ID** - get from [@userinfobot](https://t.me/userinfobot)
3. **Anthropic API key** - from [console.anthropic.com](https://console.anthropic.com), save to a file

That's it. Everything else has sensible defaults.

### Minimal config (single instance)

The simplest setup:

```nix
{
  programs.clawdbot = {
    enable = true;
    providers.telegram = {
      enable = true;
      botTokenFile = "/run/agenix/telegram-bot-token"; # any file path works
      allowFrom = [ 12345678 ];  # your Telegram user ID
    };
    providers.anthropic = {
      apiKeyFile = "/run/agenix/anthropic-api-key"; # any file path works
    };

    # Built-ins (tools + skills) shipped via nix-steipete-tools.
    plugins = [
      { source = "github:clawdbot/nix-steipete-tools?dir=tools/summarize"; }
    ];
  };
}
```

Then: `home-manager switch --flake .#youruser`

### Sensible defaults config

Uses `instances.default` to unlock per-group mention rules. If `instances` is set, you don't need `programs.clawdbot.enable`.

```nix
{
  programs.clawdbot = {
    documents = ./documents;
    instances.default = {
      enable = true;
      package = pkgs.clawdbot; # batteries-included
      stateDir = "~/.clawdbot";
      workspaceDir = "~/.clawdbot/workspace";

      providers.telegram = {
        enable = true;
        botTokenFile = "/run/agenix/telegram-bot-token";
        allowFrom = [
          12345678         # you (DM)
          -1001234567890   # couples group (no @mention required)
          -1002345678901   # noisy group (require @mention)
        ];
        groups = {
          "*" = { requireMention = true; };
          "-1001234567890" = { requireMention = false; }; # couples group
          "-1002345678901" = { requireMention = true; };  # noisy group
        };
      };

      providers.anthropic.apiKeyFile = "/run/agenix/anthropic-api-key";

      launchd.enable = true;

      # Plugins (prod: pinned GitHub). Built-ins are via nix-steipete-tools.
      # MVP target: repo pointers resolve to tools + skills automatically.
      plugins = [
        { source = "github:clawdbot/nix-steipete-tools?dir=tools/oracle"; }
        { source = "github:clawdbot/nix-steipete-tools?dir=tools/peekaboo"; }
        { source = "github:joshp123/xuezh"; }
        {
          source = "github:joshp123/padel-cli";
          config = {
            env = { PADEL_AUTH_FILE = "/run/agenix/padel-auth"; };
            settings = {
              default_location = "CITY_NAME";
              preferred_times = [ "18:00" "20:00" ];
              preferred_duration = 90;
              venues = [
                {
                  id = "VENUE_ID";
                  alias = "VENUE_ALIAS";
                  name = "VENUE_NAME";
                  indoor = true;
                  timezone = "TIMEZONE";
                }
              ];
            };
          };
        }
      ];
    };
  };
}
```

---

## Advanced

### Docker (headless gateway)

For running a Telegram-only, headless gateway in Docker. The macOS app is separate.

Build the image with Determinate Nix:

```bash
# macOS host (reliable):
nix build .#clawdbot-docker --system aarch64-linux
docker load < result

# Linux host (fast streaming load):
nix run .#clawdbot-docker-stream --system aarch64-linux | docker load
```

Run it (state lives in a mounted volume at /data):

```bash
docker run --rm -p 18789:18789 -v clawdbot-data:/data \
  -e CLAWDBOT_TELEGRAM_BOT_TOKEN="$BOT_TOKEN" \
  -e CLAWDBOT_TELEGRAM_ALLOW_FROM="12345678,-1001234567890" \
  -e CLAWDBOT_ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/clawdbot/clawdbot-gateway:latest
```

Swap updates with zero downtime: start a new container on the same volume, then stop the old one.

### Dual-instance setup (prod + dev)

Use a shared base config and override only what's different. After changing local plugin or gateway code, re-run `home-manager switch` to rebuild.

```nix
# flake inputs (pin prod + app)
inputs = {
  nix-clawdbot.url = "github:clawdbot/nix-clawdbot?ref=v0.1.0"; # pins macOS app + gateway bundle
};

let
  prod = {
    enable = true;
    # Prod gateway pin (comes from nix-clawdbot input @ v0.1.0 above).
    package = inputs.nix-clawdbot.packages.${pkgs.system}.clawdbot-gateway;
    providers.telegram.enable = true;
    providers.telegram.botTokenFile = "/run/agenix/telegram-prod";
    providers.telegram.allowFrom = [ 12345678 ];
    providers.anthropic.apiKeyFile = "/run/agenix/anthropic-api-key";
    plugins = [ { source = "github:owner/your-plugin"; } ];
  };
in {
  # Pinned macOS app (POC: no local app builds, uses nix-clawdbot @ v0.1.0 above).
  programs.clawdbot.appPackage =
    inputs.nix-clawdbot.packages.${pkgs.system}.clawdbot-app;
  programs.clawdbot.documents = ./documents;
  programs.clawdbot.instances = {
    prod = prod;
    dev = prod // {
      # Dev uses the same pinned macOS app (from nix-clawdbot input),
      # but overrides the gateway package to a local checkout.
      providers.telegram.botTokenFile = "/run/agenix/telegram-dev";
      gatewayPort = 18790;
      # Local gateway checkout (path). App stays pinned.
      gatewayPath = "/Users/you/code/clawdbot";
      # Local plugin overrides prod if names collide (last wins).
      plugins = prod.plugins ++ [
        { source = "path:/Users/you/code/your-plugin"; }
        {
          source = "github:joshp123/padel-cli";
          config = {
            env = { PADEL_AUTH_FILE = "/run/agenix/padel-auth-dev"; };
            settings = {
              default_location = "CITY_NAME";
              preferred_times = [ "18:00" ];
              preferred_duration = 90;
              venues = [];
            };
          };
        }
      ];
    };
  };
}
```

### Plugin collisions

Plugins are keyed by their declared `name`. If two plugins declare the same name, the **last entry wins** (use this to override a prod plugin with a local dev one).

---

## Reference

### Commands

```bash
# Check service
launchctl print gui/$UID/com.steipete.clawdbot.gateway | grep state

# View logs
tail -50 /tmp/clawdbot/clawdbot-gateway.log

# Restart
launchctl kickstart -k gui/$UID/com.steipete.clawdbot.gateway

# Rollback
home-manager generations  # list
home-manager switch --rollback  # revert
```

### Packages

| Package | Contents |
| --- | --- |
| `clawdbot` (default) | Gateway + app + full toolchain |
| `clawdbot-gateway` | Gateway CLI only |
| `clawdbot-app` | macOS app only |
| `clawdbot-docker` | OCI image tarball (gateway + tools) |
| `clawdbot-docker-stream` | OCI image stream (fast load) |

### What we manage vs what you manage

| Component | Nix manages | You manage |
| --- | --- | --- |
| Gateway binary | ✓ | |
| macOS app | ✓ | |
| Launchd service | ✓ | |
| Tools (whisper, etc) | ✓ | |
| Telegram bot token | | ✓ |
| Anthropic API key | | ✓ |
| Chat IDs | | ✓ |

### Included tools

**Core**: nodejs, pnpm, git, curl, jq, python3, ffmpeg, ripgrep

**AI/ML**: openai-whisper, sag (TTS)

**Media**: spotify-player, sox, camsnap

**macOS**: peekaboo, blucli

**Integrations**: gogcli, wacli, bird, mcporter

---

## Philosophy

The Zen of ~~Python~~ Clawdbot, ~~by~~ shamelessly stolen from Tim Peters

Beautiful is better than ugly.
Explicit is better than implicit.
Simple is better than complex.
Complex is better than complicated.
Flat is better than nested.
Sparse is better than dense.
Readability counts.
Special cases aren't special enough to break the rules.
Although practicality beats purity.
Errors should never pass silently.
Unless explicitly silenced.
In the face of ambiguity, refuse the temptation to guess.
There should be one-- and preferably only one --obvious way to do it.
Although that way may not be obvious at first unless you're Dutch.
Now is better than never.
Although never is often better than *right* now.
If the implementation is hard to explain, it's a bad idea.
If the implementation is easy to explain, it may be a good idea.
Namespaces are one honking great idea -- let's do more of those!

---

## Upstream

Wraps [Clawdbot](https://github.com/clawdbot/clawdbot) by Peter Steinberger.

## License

AGPL-3.0
