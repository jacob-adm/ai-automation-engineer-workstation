# 🚀 Welcome to the AI Automation Engineer Workstation: The Quick Start Guide

> **"Quick Start" Onboarding Guide for New AI & Automation Engineers**  
> *Everything you need to know about your new workstation setup, written without boring jargon.*

Welcome aboard! If you're reading this, you just joined the team as an **AI Engineer** or **AI Automation Engineer**. 

Your job is super exciting: you build AI models, run test harnesses, and unleash autonomous coding agents to build software alongside you. But before you can build the future, you need a computer that is **fast, safe, organized, and reliable**.

That’s what this repository is. Running one script turns a blank Ubuntu machine into a superpower-packed command center.
 
> 💡 *Looking for the deep architectural guide that explains how agent harnesses work, threat models, supply chain defense, and systems engineering? Read **[The AI Automation Engineer's Field Manual (MANUAL.md)](MANUAL.md)**.*

---

## 🎮 Hands-On Walkthrough: Your First 30 Minutes on the Job

Before you start, choose how you want to experience this:

### 🚦 Choose Your Path: Test Drive vs. Install for Real

#### 🧪 Path 1: The "Test Drive" (Zero Risk, Safe Sandbox)
If you want to explore and try out all the tools **without touching or modifying your host computer** (perfect if you are on macOS, Windows, or testing before committing):

Windows: If you don't have WSL, and you installed Git for Windows to clone the repo, you already have a full Bash shell installed:

- Right-click inside the dotfiles directory in Windows File Explorer.
- Select "Open Git Bash here" (or search "Git Bash" in the Start Menu).

```bash
# 1. Clone the repository
git clone https://bitbucket.org/jadm11/ai-automation-engineer-workstation.git ~/ai-automation-engineer-workstation
cd ~/ai-automation-engineer-workstation

# 2. Jump into the isolated sandbox
./tests/sandbox.sh
```
*(Docker automatically builds a fresh Ubuntu 24.04 container, installs the dotfiles inside it, and drops you into an interactive `testuser@sandbox:~/dotfiles$` shell. When you type `exit`, the sandbox vanishes completely. Zero files on your host machine are touched).*

#### 🚀 Path 2: The "Install for Real" (Production Setup)
If you are on your actual workstation (an Ubuntu desktop/laptop, Windows WSL2, or a Cloud GPU box like RunPod / Lambda Labs / AWS EC2) and want this to be your daily driver:

```bash
# 1. Clone the repository
git clone https://bitbucket.org/jadm11/ai-automation-engineer-workstation.git ~/ai-automation-engineer-workstation
cd ~/ai-automation-engineer-workstation

# 2. Run the native installer
./install.sh -y

# 3. Reload your shell
source ~/.bashrc
```
*(This installs native packages, sets up `uv` and `pueue`, safely backs up any existing dotfiles to `~/.dotfiles_backup/`, and symlinks all 26 configurations into your home directory).*

---

### Step 0: Ready to Play? Jump into the Missions!
Whether you hopped into the Docker sandbox (Path 1) or ran the native installer (Path 2), here are your first 5 quick missions to test your new powers:

### Mission 1: Check in with the Robot Medic (doctor)
Open your terminal and type:
```bash
doctor
```
You should see a glorious wall of green checkmarks (`✓`) verifying all 45 tools, symlinks, and agent rules.

### Mission 2: Set Up Your Secret Vault (~/.secrets/ai.env) with `secret-run`
In AI engineering, we **never** store API keys in `.bashrc` or git repositories where untrusted scripts or subagents can leak them. Instead, you keep them in a locked private vault at `~/.secrets/ai.env`. Let's create your vault right now:

```bash
# 1. Create the locked vault directory (only you have permission to read it)
mkdir -p ~/.secrets && chmod 700 ~/.secrets

# 2. Initialize your vault file (put your real Gemini, Claude, or OpenAI key, or leave placeholders)
cat << 'EOF' > ~/.secrets/ai.env
GEMINI_API_KEY="AIzaSy-your-gemini-key-here"
GOOGLE_API_KEY="AIzaSy-your-gemini-key-here"
ANTHROPIC_API_KEY="sk-ant-your-claude-key-here"
OPENAI_API_KEY="sk-proj-your-openai-key-here"
EOF
chmod 600 ~/.secrets/ai.env

# 3. Run a test command inside the vault using secret-run
secret-run --env-file ~/.secrets/ai.env -- bash -c 'echo "Inside the vault, my key is loaded: ${GEMINI_API_KEY:0:12}..."'

# 4. Check your regular terminal outside the vault
echo "Outside the vault, my key is: '$GEMINI_API_KEY'"
```
Notice how outside the vault, it prints nothing! The key was loaded strictly for the test command and instantly vanished. Your regular shell stays 100% clean and protected from accidental leaks.

### Mission 3: Give an AI Agent Its Own Lego Table (Git worktree / agent-worktree)
Let's see how fast you can spin up an isolated workspace:
```bash
# 1. Create a quick test git repo
cd /tmp && mkdir -p playground && cd playground && git init -b main
echo "hello world" > readme.txt && git add . && git commit -m "first commit"

# 2. Spin up a separate table (worktree) for an agent
aw-new feature-login

# 3. Look at your active tables (worktrees)
aw-ls
```
You now have a clean `.worktrees/feature-login` directory where an agent can code without touching your `main` branch. When done:
```bash
aw-merge feature-login
cd /tmp && rm -rf playground
```

### Mission 4: Send a Job to the Waiter (Pueue background task queue)
Let's send a task to the background queue (the `pueue` daemon is already running automatically in the background):
```bash
# 1. Hand a 5-second task to the experiment queue
jexp sleep 5

# 2. Check the waiter's notepad (task list)
jls
```
You'll see your job queued and running smoothly in the background while your terminal stays 100% free!

### Mission 5: Test the Self-Healing Magic (doctor --fix)
Let's purposely break something and watch the medic (doctor) fix it:
```bash
# 1. Delete a configuration symlink on purpose
rm ~/.config/mcp/mcp.json

# 2. Ask the doctor what happened
doctor
# (Doctor will show a red ✗ for the missing link)

# 3. Tell the doctor to fix it!
doctor --fix

# 4. Check if it's back!
ls -l ~/.config/mcp/mcp.json
```
Boom! The doctor restored the link in less than a second. 

Type `exit` whenever you want to leave the sandbox.

---

## 📂 Where Does My Software Live? (The Storage Map)

When you develop software on Linux, where does everything actually go? Here is the mental map:

```
/home/<username>/
├── ai-automation-engineer-workstation/ # 🔧 THE BLUEPRINT (Configurations): Configs, scripts, and rules (this repo)
│
├── Development/                        # 🔨 THE WORKBENCH (Workspace): Where all your real projects live!
│   ├── customer-chatbot/      # A project repo
│   │   ├── app.py             # Your application code
│   │   ├── .venv/             # Python packages for THIS project only (Virtual Environment)
│   │   └── .worktrees/        # Hidden rooms (Git worktrees) where AI agents work without touching main
│   │       └── auth-fix/      # Agent is busy writing code in here!
│   │
│   └── vision-evaluator/      # Another project repo
│
└── .local/bin/                 # ⚡ SHORTCUTS (User Binaries): Where commands like 'doctor' and 'secret-run' live
```

### The Golden Rule of Storage:
1. **Never build projects inside `~/ai-automation-engineer-workstation/` (or `~/.dotfiles/`)**: That folder is only for your workstation settings.
2. **Always build projects in `~/Development/<project-name>`** (or `~/projects/<project-name>`): Every project gets its own git repository, its own `.venv` virtual environment, and its own `.worktrees/`.

---

## 🤖 Controlling AI Agents: How to Configure Input & Orchestrate Tasks

You are inside the command center. Now, how do you **actually prompt and orchestrate an AI agent** to build software, write presentations, generate documentation, build websites, or design brochures?

Here is the exact control manual:

```
               ┌────────────────────────────────────────────────────────┐
               │              THE 3-TIER AGENT INPUT SYSTEM             │
               └────────────────────────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
   🔒 1. API Keys & Vault      🧠 2. System Guidelines      📝 3. Project Context & Task
   (~/.secrets/ai.env)        (AGENTS.md / CLAUDE.md)       (spec.md / CLI prompt)
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     ▼
                    🤖 AI AGENT (Claude Code / Aider / etc.)
                                     │
         ┌───────────────┬───────────┴───┬───────────────┬───────────────┐
         ▼               ▼               ▼               ▼               ▼
    💻 Software     📊 PowerPoint    📚 Docs        🌐 Website     📄 Brochure
    (Web App/API)   (.pptx slides)   (Arch Guides)   (Landing Page)  (Print PDF)
```

---

### 🔑 Step 1: Your AI Credentials Vault is Ready!

Your private credentials vault was already initialized in **Mission 2** at `~/.secrets/ai.env`. 

Whenever you unleash an agent, [`secret-run`](bin/secret-run) loads these variables into a temporary subshell and destroys them the moment the agent finishes.

#### Need to update keys or switch to free local AI?
- **Cloud Models (Gemini, Claude, OpenAI)**: Simply edit `~/.secrets/ai.env` and paste your real API tokens.
- **100% Free Local AI (Offline via Ollama)**:
  Download and inspect the official installer:
  ```bash
  curl -fsSL https://ollama.com/install.sh -o /tmp/ollama-install.sh
  bash /tmp/ollama-install.sh
  ollama run qwen2.5-coder:7b
  echo 'OPENAI_BASE_URL="http://localhost:11434/v1"' >> ~/.secrets/ai.env
  echo 'OPENAI_API_KEY="ollama"' >> ~/.secrets/ai.env
  ```

---

### 📥 Step 2: How AI Agents Receive Their Input

Every coding agent has **three input channels**:

1. **System & Tool Memory (`AGENTS.md` / `CLAUDE.md`)**:
   - The installer already linked [`config/agents/AGENTS.md`](config/agents/AGENTS.md) to `~/.claude/CLAUDE.md` and `~/.config/agents/AGENTS.md`.
   - Whenever an agent boots up, it automatically reads this file. It learns how to use [`secret-run`](bin/secret-run), [`agent-worktree`](bin/agent-worktree), and [`pueue`](config/pueue/pueue.yml), and obeys security guardrails automatically.
2. **Project Specification Input (`spec.md`)**:
   - You provide your requirements in a Markdown file in your project folder. The agent reads this file to understand the architecture, data schemas, and design constraints.
3. **Interactive & Command Prompting**:
   - You can launch agents in **interactive chat mode** (back-and-forth pair programming) or **one-shot autonomous mode** (giving a specific task from your terminal).

---

### 🎮 Step 3: Provider Orchestration Commands (How to Run Each Provider)

Different LLM providers use different CLI orchestrators. Because `uv` / `uvx` is pre-installed in your environment, **[Aider](https://aider.chat)** runs on-demand with zero manual installation required for **Google Gemini**, **OpenAI**, **Ollama**, and **DeepSeek**. For **Anthropic Claude**, you can use **Claude Code** (`claude`) or Aider.

Here is the master command cheat sheet for each provider:

| Provider | Vault Variable (`~/.secrets/ai.env`) | Recommended Models | Autonomous One-Shot Command (`--yes` / `-p`) | Interactive Pair-Programming |
| :--- | :--- | :--- | :--- | :--- |
| **Google Gemini** | `GEMINI_API_KEY` | `gemini/gemini-3.8-flash`<br>`gemini/gemini-3.8-pro` | `secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "<prompt>" --yes` | `secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash` |
| **Anthropic Claude** | `ANTHROPIC_API_KEY` | `claude-3-7-sonnet`<br>`claude-3-5-haiku` | `secret-run -- claude -p "<prompt>"` | `secret-run -- claude` |
| **OpenAI** | `OPENAI_API_KEY` | `openai/gpt-4o`<br>`openai/gpt-4o-mini` | `secret-run -- uvx --from aider-chat aider --model openai/gpt-4o --message "<prompt>" --yes` | `secret-run -- uvx --from aider-chat aider --model openai/gpt-4o` |
| **100% Free Local AI (Ollama)** | `OPENAI_BASE_URL`<br>`OPENAI_API_KEY="ollama"` | `ollama/qwen2.5-coder:7b`<br>`ollama/llama3.3:70b` | `secret-run -- uvx --from aider-chat aider --model ollama/qwen2.5-coder:7b --message "<prompt>" --yes` | `secret-run -- uvx --from aider-chat aider --model ollama/qwen2.5-coder:7b` |
| **DeepSeek** | `DEEPSEEK_API_KEY` | `deepseek/deepseek-chat`<br>`deepseek/deepseek-reasoner` | `secret-run -- uvx --from aider-chat aider --model deepseek/deepseek-chat --message "<prompt>" --yes` | `secret-run -- uvx --from aider-chat aider --model deepseek/deepseek-chat` |

---

#### 📋 Quick Copy-Paste Blocks by Provider:

##### 🔷 Google Gemini (`GEMINI_API_KEY`)
Uses **Aider** via `uvx` (zero install needed, natively reads `GEMINI_API_KEY` from `~/.secrets/ai.env`):
```bash
# Autonomous One-Shot (builds files without prompting):
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Build the feature in spec.md" --yes

# Interactive Pair Programming:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash
```
*(Need deep architectural reasoning? Swap `--model gemini/gemini-3.8-flash` to `--model gemini/gemini-3.8-pro`).*

##### 🟠 Anthropic Claude (`ANTHROPIC_API_KEY`)
Uses **Claude Code** (`npm install -g @anthropic-ai/claude-code`):
```bash
# Autonomous One-Shot:
secret-run -- claude -p "Build the feature in spec.md"

# Interactive Pair Programming:
secret-run -- claude
```

##### 🟢 OpenAI (`OPENAI_API_KEY`)
Uses **Aider** via `uvx`:
```bash
# Autonomous One-Shot:
secret-run -- uvx --from aider-chat aider --model openai/gpt-4o --message "Build the feature in spec.md" --yes

# Interactive Pair Programming:
secret-run -- uvx --from aider-chat aider --model openai/gpt-4o
```

##### 🦙 100% Free Local AI (Ollama Offline)
Uses **Ollama** + **Aider** via `uvx` ($0.00 cost, 100% local privacy):
```bash
# Autonomous One-Shot:
secret-run -- uvx --from aider-chat aider --model ollama/qwen2.5-coder:7b --message "Build the feature in spec.md" --yes

# Interactive Pair Programming:
secret-run -- uvx --from aider-chat aider --model ollama/qwen2.5-coder:7b
```

##### 🐳 DeepSeek (`DEEPSEEK_API_KEY`)
Uses **Aider** via `uvx`:
```bash
# Autonomous One-Shot:
secret-run -- uvx --from aider-chat aider --model deepseek/deepseek-chat --message "Build the feature in spec.md" --yes

# Interactive Pair Programming:
secret-run -- uvx --from aider-chat aider --model deepseek/deepseek-chat
```

---

### 🎯 Step 4: The 5 Orchestration Recipes: From Prompt to Product

Here is how to orchestrate agents for the 5 biggest daily jobs (simply pick your provider command from Step 3):

#### 💻 Recipe 1: Developing Software & Seeing It Live

Let's watch an agent build a real web application inside an isolated worktree:

```bash
# 1. Go to your development workbench (project directory) and create a project repo
mkdir -p ~/Development/agent-dashboard && cd ~/Development/agent-dashboard
git init -b main && git commit --allow-empty -m "init"

# 2. Give the agent an isolated Lego table (Git worktree)
aw-new web-app
cd .worktrees/web-app

# 3. Write a 1-paragraph spec for your agent
cat << "EOF" > spec.md
Build an interactive AI Engineer Telemetry Dashboard using vanilla HTML/CSS and JavaScript.
- Include a sleek dark mode with glassmorphism.
- Show live CPU/GPU mock telemetry cards and an interactive test button.
- Save the app as index.html.
EOF

# 4. Unleash the agent with credentials loaded safely
# With Gemini:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Read spec.md and build the complete web app in index.html. Do not stop until verified." --yes

# Or with Claude Code:
secret-run -- claude -p "Read spec.md and build the complete web app in index.html. Do not stop until verified."
```

##### How do you actually SEE the software running?
Start your local server:
```bash
python3 -m http.server 8000
```
- **Scenario A (Local Mac/Ubuntu Desktop)**: Open your browser to 👉 **`http://localhost:8000`**.
- **Scenario B (VS Code Remote / Dev Containers)**: Click the *"Open in Browser"* popup in the bottom right corner of VS Code.
- **Scenario C (Docker Sandbox)**: Start the sandbox with port forwarding: `docker run --rm -it -p 8000:8000 dotfiles-sandbox /bin/bash -l`.
- **Scenario D (Cloud GPU Box)**: Forward port from your laptop: `ssh -L 8000:localhost:8000 user@cloud-ip`.

Once verified, merge the agent's work back into your main branch:
```bash
cd ~/Development/agent-dashboard
aw-merge web-app
```

---

#### 📊 Recipe 2: Making PowerPoint Presentations (`.pptx`)

You don't need Microsoft PowerPoint installed to create professional slide decks. Agents generate Markdown presentations, which convert into PowerPoint in one second using **Marp**:

```bash
cd ~/Development/my-project

# 1. Ask your agent to author the slides
# With Gemini:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Create a high-impact, 6-slide executive presentation on AI Agent Architecture using Marp Markdown format. Save to slides.md." --yes

# Or with Claude Code:
secret-run -- claude -p "Create a high-impact, 6-slide executive presentation on AI Agent Architecture using Marp Markdown format. Save to slides.md."

# 2. Convert directly to native PowerPoint (.pptx)
npx -y @marp-team/marp-cli slides.md --pptx -o architecture_deck.pptx

# Or create an interactive HTML presentation you can present in any browser:
npx -y @marp-team/marp-cli slides.md -o presentation.html
```

---

#### 📚 Recipe 3: Generating Technical Documentation & Architecture Guides

Need comprehensive documentation for an existing codebase? Point your agent at the repo:

```bash
cd ~/Development/my-project

# 1. Ask the agent to inspect the code and generate architecture docs with Mermaid diagrams
# With Gemini:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Analyze this entire repository. Create a docs/ARCHITECTURE.md file detailing system topology, data flow, component diagrams (using Mermaid), and an API reference table." --yes

# Or with Claude Code:
secret-run -- claude -p "Analyze this entire repository. Create a docs/ARCHITECTURE.md file detailing system topology, data flow, component diagrams (using Mermaid), and an API reference table."
```

---

#### 🌐 Recipe 4: Creating Websites & Landing Pages

Command an agent to build responsive, modern, production-grade landing pages:

```bash
cd ~/Development/my-website

# 1. Instruct the agent with design principles
# With Gemini:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Build a responsive landing page for an autonomous coding agent platform in index.html and style.css. Use modern typography (Google Fonts Outfit), smooth gradients, dark mode aesthetics, and an interactive FAQ accordion." --yes

# Or with Claude Code:
secret-run -- claude -p "Build a responsive landing page for an autonomous coding agent platform in index.html and style.css. Use modern typography (Google Fonts Outfit), smooth gradients, dark mode aesthetics, and an interactive FAQ accordion."

# 2. Preview live in browser
python3 -m http.server 8080
```

---

#### 📄 Recipe 5: Creating Printable Brochures & One-Pagers (PDF)

Command an agent to design marketing brochures or one-pagers formatted specifically for print or PDF export:

```bash
cd ~/Development/marketing

# 1. Ask the agent to build a print-styled brochure
cat << 'EOF' > prompt.txt
Design a clean, 2-column executive one-pager product brochure in brochure.html.
Include @media print CSS rules for standard Letter size (8.5in x 11in) with zero margins,
professional headers, feature callout boxes, and contact info.
EOF

# With Gemini:
secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "$(cat prompt.txt)" --yes

# Or with Claude Code:
secret-run -- claude -p "$(cat prompt.txt)"

# 2. Export directly to high-res PDF using headless browser
google-chrome --headless --disable-gpu --print-to-pdf=brochure.pdf brochure.html 2>/dev/null || \
chromium --headless --disable-gpu --print-to-pdf=brochure.pdf brochure.html 2>/dev/null || \
echo "Open brochure.html in your browser and press Cmd+P / Ctrl+P -> Save as PDF!"
```

---

### ⏳ Step 5: Orchestrating Multiple Agents in the Background (`pueue` / `jagent`)

What if you have **3 tasks at the same time** (e.g., an agent building tests, an agent writing docs, and an agent running a model eval)?

Use the built-in task queue (`jagent` and `jexp`) to run them in parallel without locking up your terminal:

```bash
# 1. Send Task 1 to the background agent queue (Gemini example)
jagent secret-run -- uvx --from aider-chat aider --model gemini/gemini-3.8-flash --message "Write complete unit tests for auth.py" --yes

# 2. Send Task 2 to the background agent queue (Claude Code example)
jagent secret-run -- claude -p "Create docs/API.md with full endpoint tables"

# 3. Check queue status
jls

# 4. Stream output from task 1 in real time
jfollow 1
```

Your agents work tirelessly in the background while you stay in full control.

---

## 🌟 The 7 Superpowers Explained Like You're 10 (Core Architecture & Tools)

Think of this setup as your superhero suit. Here are the 7 gadgets (tools and guardrails) built into your suit and why they exist:

```
               ┌────────────────────────────────────────────────────────┐
               │         YOUR AI WORKSTATION COMMAND CENTER             │
               └────────────────────────────────────────────────────────┘
                                    │
       ┌──────────────┬─────────────┼──────────────┬─────────────┐
       ▼              ▼             ▼              ▼             ▼
 🔒 Vault      🌲 Lego Rooms    ⏳ Waiter      🛡️ Food Taster  🚨 E-Stop
 (secret-run)  (agent-worktree) (pueue task)   (7-day uv)      (agent-stop)
```

---

### 1. 🔒 The Secret Vault (`secret-run`)
* **The Problem**: Imagine leaving your house keys and credit cards on the kitchen counter while three robot helpers are vacuuming and dusting. One careless robot might pick up your credit card and post a picture of it online! In AI, putting API keys (`OPENAI_API_KEY`, etc.) in global files means untrusted scripts or LLMs can accidentally leak them.
* **The Solution**: [`secret-run`](bin/secret-run) is like a locked metal briefcase (temporary scoped subshell environment). When a program needs the credit card, you hand it the briefcase for 5 seconds. The program pays the bill, the briefcase snaps shut, and the rest of your computer never sees the card.
* **How to use it**:
  ```bash
  secret-run -- python evaluate_model.py
  ```

---

### 2. 🌲 Separate Lego Tables (`agent-worktree` or `aw`)
* **The Problem**: Imagine you and two friends are building a massive Lego castle at the exact same kitchen table. If you're building the front gate and your friend starts building a spaceship on top of your bricks, everything gets smashed. In Git, when multiple AI agents work on the same folder at the same time, they break your files.
* **The Solution**: [`agent-worktree`](bin/agent-worktree) gives each AI agent its own folding table in a separate room (Git worktree inside a hidden `.worktrees/` folder). They can make a huge mess, test their ideas, and when their piece is finished, you snap it into the main castle (merge into main branch)!
* **How to use it**:
  ```bash
  aw-new robot-helper-1      # Creates a private room (Git worktree) for the agent
  aw-ls                      # See who is building what (active worktrees)
  aw-merge robot-helper-1    # Bring their work back into main (git merge & cleanup)
  ```

---

### 3. ⏳ The Restaurant Waiter (`pueue` / `jexp` / `jagent`)
* **The Problem**: If 10 people rush into a kitchen and all try to use the single stove at once, the pots boil over and the kitchen catches fire (in AI, your graphics card runs Out Of Memory: **CUDA OOM**).
* **The Solution**: `pueue` is your friendly waiter (background process manager & task queue). You can hand it 20 big AI experiments, and it lines them up calmly. It lets 2 cook at a time so your GPU stays cool and fast. You can go grab lunch, and check the waiter's notepad (task list) anytime.
* **How to use it**:
  ```bash
  jexp python run_eval.py    # Hand experiment to the waiter (task queue)
  jls                        # Look at the waiter's notepad (task list)
  jfollow 1                  # Watch recipe #1 cooking live (stream log output)
  ```

---

### 4. 🛡️ The 7-Day Food Taster (Supply Chain Quarantine / `UV_EXCLUDE_NEWER`)
* **The Problem**: In old medieval times, kings had "food tasters" to make sure nobody poisoned the soup before the king ate it. In Python, hackers sometimes upload brand new packages with sneakily disguised malware to steal developer tokens.
* **The Solution**: Our setup automatically tells Python's installer (`uv` via `UV_EXCLUDE_NEWER`): *"Don't touch any package that was uploaded less than 7 days ago."* If someone released a bad package yesterday, everyone else finds out first and cleans it up before your computer ever downloads it!

---

### 5. 🚨 The Big Red Emergency Button (`agent-stop`)
* **The Problem**: AI agents are brilliant, but sometimes they get confused and start chasing their own tail in a loop, burning through your tokens and money while typing frantically.
* **The Solution**: You have an instant kill-switch (emergency circuit breaker). Type `agent-stop` and every automated agent loop in your environment immediately freezes. When you've fixed the prompt, type `agent-resume` to start them back up.
* **How to use it**:
  ```bash
  agent-stop     # FREEZE EVERYTHING! (trip circuit breaker)
  agent-status   # See if the brakes are on (check circuit breaker sentinel)
  agent-resume   # Brakes off, back to work (clear circuit breaker)
  ```

---

### 6. 🩺 The Robot Medic (`doctor` & `doctor --fix`)
* **The Problem**: **The Spilled Coffee Principle**—What happens if you spill coffee on your laptop, or you accidentally delete half your configuration files? 
* **The Solution**: You shouldn't spend 3 days crying and re-installing things. You run [`doctor`](bin/doctor). It runs 45 medical tests (system and symlink verifications) on your system in 2 seconds. If anything is broken, [`doctor --fix`](bin/doctor) heals (self-repairs) it automatically.
* **How to use it**:
  ```bash
  doctor         # Check system health (diagnostic runner)
  doctor --fix   # Automatically heal missing symlinks and broken tools (self-repair)
  ```

---

### 7. 📜 House Rules on the Fridge (`AGENTS.md` & `CLAUDE.md`)
* **The Problem**: When you invite a babysitter over, you leave a note on the fridge saying: *"The baby sleeps at 8, pizza is in the freezer, and don't go into my bedroom."* Coding agents need the same clear boundaries.
* **The Solution**: We have [`config/agents/AGENTS.md`](config/agents/AGENTS.md). It is taped to the virtual fridge (global system instructions) for Claude Code, OpenCode, Antigravity, and Codex. It tells them:
  - *"Use our local tools like `secret-run` and `agent-worktree`."*
  - *"NEVER read `*.env` files or other agents' worktrees!"*
  - *"Keep your answers concise and write tests!"*

---

## ⚡ The Everyday Cheat Sheet: Spells & Shortcuts (Aliases & Commands)

Here are the most useful everyday commands organized by what you're trying to do:

### 🤖 AI Agent & Worktree Spells (Commands & Aliases)
| Command | What it does (in plain English) |
| :--- | :--- |
| `aw-new <name>` | Spin up an isolated `.worktrees/<name>` room (Git worktree) for an agent |
| `aw-ls` | List all active agent rooms (Git worktrees) and what branch they are on |
| `aw-merge <name>` | Merge the agent's work back into your branch and clean up |
| `aw-rm <name>` | Throw away an agent room (Git worktree) without keeping changes |
| `agent-stop` | **Emergency stop**: Freeze all automated agent loops (circuit breaker) |
| `agent-resume` | Unfreeze all agent loops (clear circuit breaker) |
| `mcplogs` | Check recent Model Context Protocol (MCP) server logs |
| `mcplogs --tail` | Stream MCP server logs live on screen |

### ⏳ Background Task Queue Spells (Pueue Commands & Aliases)
| Command | What it does |
| :--- | :--- |
| `jexp <cmd>` | Enqueue a heavy GPU/CPU model experiment (in experiments queue) |
| `jagent <cmd>` | Enqueue an agent task (in agents queue) |
| `jls` | See all running, queued, and finished tasks (pueue status) |
| `jfollow <id>` | Follow a task's output live (stream Pueue log) |
| `jkill <id>` | Cancel a running task (pueue kill) |

### 💻 System & Navigation Spells (Shell Aliases & Functions)
| Command | What it does |
| :--- | :--- |
| `doctor` | Run full 45-point health check |
| `doctor --fix` | Self-heal broken links and recover configuration |
| `dotfiles-update` | Pull latest updates, refresh symlinks, and self-heal |
| `edocker` | Verify or start Docker daemon if it went to sleep |
| `gpu` | Watch your GPU memory and temperatures live (1-sec refresh) |
| `ports` | See all network ports currently open on your machine |
| `pr-checkout <id>` | Checkout a GitHub Pull Request locally |
| `pr-checkout --worktree <id>` | Put a Pull Request in a separate worktree to review it safely |
| `..` / `...` / `....` | Jump up 1, 2, or 3 folder levels |
| `mkcd <dir>` | Make a folder and immediately `cd` into it |
| `extract <archive>` | Automatically uncompress `.tar.gz`, `.zip`, `.7z`, etc. |

---

## ❓ Frequently Asked Questions (FAQ)

### 🤖 Q1: How many agents can I run at the same time?
**Short answer:** Between 2 and 4 concurrent agents is the sweet spot.  
**Why?**
Think of agents like energetic interns (autonomous worker processes). If you hire 20 interns on the same computer:
1. **API Rate Limits (HTTP 429 Errors)**: OpenAI and Anthropic will block your requests if 10 agents hammer them at the same second.
2. **Context Bankruptcy**: 10 agents querying models simultaneously will burn through your API budget in 15 minutes!
3. **RAM & CPU Limits**: Each agent processes files, runs linters, and parses Git.
4. **Our Built-In Guardrails**:
   - The [`pueue`](config/pueue/pueue.yml) task queue is pre-configured with **`experiments` (max 2 parallel)** and **`agents` (max 4 parallel)** to protect your hardware.
   - `agent-guard-check` enforces a ceiling of **30 agent spawns per hour** (`AUTO_AGENT_MAX_PER_HOUR=30`) so runaway recursive scripts can't bankrupt you.

---

### 🏠 Q2: Can I run the AI locally without paying for API keys, and how?
**Short answer:** YES! You can run open-weights models (Llama 3, Qwen 2.5 Coder, DeepSeek) completely free and offline right on your machine.

**How to do it in 2 minutes:**
1. **Install Ollama** (the simplest local AI runner):
   Download and execute the official installer:
   ```bash
   curl -fsSL https://ollama.com/install.sh -o /tmp/ollama-install.sh
   bash /tmp/ollama-install.sh
   ```
2. **Download a smart coding model**:
   ```bash
   # For fast, lightweight coding (fits in 8GB RAM):
   ollama run qwen2.5-coder:7b
   
   # Or Llama 3:
   ollama run llama3.2
   ```
3. **Connect your Coding Agent to Local AI**:
   Ollama automatically runs an OpenAI-compatible server at `http://localhost:11434/v1`.
   In OpenCode or any OpenAI-compatible harness, set:
   ```bash
   export OPENAI_BASE_URL="http://localhost:11434/v1"
   export OPENAI_API_KEY="ollama"
   ```
   Now your agents generate code for $0.00, with 100% data privacy!

---

### 💻 Q3: Can I use VS Code on here?
**Short answer:** Absolutely! It's the most popular way to use this setup.

Here are the 3 best ways:
1. **VS Code Remote - SSH (Recommended for Remote/Cloud servers)**:
   - On your laptop, open VS Code.
   - Install the extension: **Remote - SSH**.
   - Press `Cmd+Shift+P` (or `Ctrl+Shift+P`), type `Remote-SSH: Connect to Host`, and enter your Ubuntu machine's IP.
   - You get the full graphical VS Code UI, while your code, terminal, and all your dotfiles tools (`doctor`, `aw`, `secret-run`) run directly on the Ubuntu server.
2. **VS Code Dev Containers (For Local Docker Sandboxes)**:
   - Install the **Dev Containers** extension in VS Code.
   - Click "Open Folder in Container" on this dotfiles repo. You are instantly pair-programming inside the container!
3. **Web Browser VS Code (`code-server`)**:
   - If you're on an iPad or Chromebook, you can install `code-server` on your Ubuntu machine (`curl -fsSL https://code-server.dev/install.sh -o /tmp/code-server-install.sh && sh /tmp/code-server-install.sh`, or via `npm install -g code-server`).
   - Open a browser tab to `http://<your-ip>:8080`, and you have full VS Code right inside Chrome!

---

### 📊 Q4: How can I create a PowerPoint presentation on here?
**Short answer:** You don't need Microsoft Office! You can write a presentation in simple Markdown and convert it into a gorgeous `.pptx` or `.html` slide deck in one command using **Marp**.

#### The 3-Step AI PowerPoint Workflow:
1. **Ask your AI agent to write the slides**:
   > *"Write a 6-slide presentation about our AI Architecture in Marp markdown format."*
2. **Save it as `presentation.md`**:
   ```markdown
   ---
   marp: true
   theme: uncover
   class: invert
   ---
   # 🤖 Autonomous AI Agents
   ### By the AI Engineering Team
   ---
   # Why Worktrees?
   - Agents need isolated directories
   - No Git collisions
   - Clean merges with `aw-merge`
   ---
   # The Secret Vault
   - Zero ambient API keys
   - Temporary subshells with `secret-run`
   ---
   # 🚀 Thank You!
   Questions?
   ```
3. **Convert directly to PowerPoint (`.pptx`)**:
   ```bash
   npx @marp-team/marp-cli presentation.md --pptx -o presentation.pptx
   ```
   *(Or make a clickable web slide deck: `npx @marp-team/marp-cli presentation.md -o presentation.html`)*.

---

### 🛠️ Q5: How do I add my personal, machine-specific settings without committing them to git?
**A:** Use `~/.dotfiles.local` for shell variables and `~/.bash_aliases.local` for custom personal aliases. Both files are automatically loaded by `.bashrc` and are completely ignored by git.

---

### 🛡️ Q6: Python says a brand new package cannot be found even though it's on PyPI!
**A:** Remember the **7-Day Food Taster (Supply Chain Quarantine / `UV_EXCLUDE_NEWER`)**! By default, `UV_EXCLUDE_NEWER` hides packages released within the last 7 days to protect you from zero-day malicious packages. If you truly need a brand new package right now, you can temporarily override it with:
```bash
uv pip install --exclude-newer $(date -u +"%Y-%m-%dT%H:%M:%SZ") <package-name>
```

---

### 🔄 Q7: How do I update my entire setup when the team pushes changes to the dotfiles repo?
**A:** Run a single command:
```bash
dotfiles-update
```
It pulls the latest git commits, refreshes your symlinks, updates `uv`, and runs `doctor --fix`.

---

## 🙏 Standing on the Shoulders of Giants: Credits & Inspo

Special thanks to the open-source community whose dotfiles inspired these patterns:
- **[yulonglin/dotfiles](https://github.com/yulonglin/dotfiles)**: Pioneered AI agent guardrails, circuit breaker sentinels, supply chain quarantine, and task queues.
- **[atxtechbro/dotfiles](https://github.com/atxtechbro/dotfiles)**: Pioneered vendor-agnostic MCP configuration, Docker daemon validation, and PR review workflows.
- **[jplhughes/dotfiles](https://github.com/jplhughes/dotfiles)** & **[drmowinckels/dotfiles](https://github.com/drmowinckels/dotfiles)**: Modular shell configurations and developer ergonomics.

---

*Now you're fully equipped to build awesome AI systems. Happy coding! 🚀*
