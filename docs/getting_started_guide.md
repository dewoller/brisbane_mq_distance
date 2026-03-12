# Getting Started: From Zero to Running This Project

This guide walks you through everything from creating a GitHub account to downloading and running this project using Claude Code (an AI coding assistant).

## Step 1: Create a GitHub Account

1. Go to https://github.com
2. Click **Sign up** in the top right
3. Enter your email address, create a password, and choose a username
4. Complete the verification puzzle
5. Choose the **Free** plan (it has everything you need)
6. Check your email and click the verification link GitHub sends you

Once you have an account, give your GitHub **username** to the person who shared this project so they can add you as a collaborator.

## Step 2: Accept the Repository Invitation

After the project owner adds you as a collaborator:

1. Check your email for an invitation from GitHub
2. Click the link in the email to accept
3. You now have access to the repository at https://github.com/dewoller/brisbane_mq_distance

## Step 3: Install Required Software

You need three things installed on your computer:

### 3a. Install Git

**macOS:**

Git comes pre-installed. Open Terminal (search for "Terminal" in Spotlight) and type:
```bash
git --version
```
If it prompts you to install Xcode Command Line Tools, click **Install** and wait for it to finish.

**Windows:**

1. Download Git from https://git-scm.com/download/win
2. Run the installer, accepting all defaults
3. Open **Git Bash** (installed with Git) to use git commands

### 3b. Install R

**macOS:**
1. Go to https://cran.r-project.org/bin/macosx/
2. Download the `.pkg` file for your Mac (Apple Silicon or Intel)
3. Double-click the downloaded file and follow the installer

**Windows:**
1. Go to https://cran.r-project.org/bin/windows/base/
2. Click "Download R-4.x.x for Windows"
3. Run the installer, accepting all defaults

### 3c. Install Claude Code

Claude Code is an AI assistant that runs in your terminal. It can help you set up the project, troubleshoot errors, and understand the code.

1. First install Node.js from https://nodejs.org (download the LTS version)
2. Open your terminal and run:
```bash
npm install -g @anthropic-ai/claude-code
```
3. Launch Claude Code by typing:
```bash
claude
```
4. On first launch, it will ask you to log in to your Anthropic account (create one at https://console.anthropic.com if needed)

## Step 4: Configure Git with Your GitHub Account

Open your terminal (or Git Bash on Windows) and run these two commands, replacing with your actual name and the email you used for GitHub:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Step 5: Download the Project

In your terminal, navigate to where you want the project (e.g., your home folder or a projects folder):

```bash
cd ~
git clone https://github.com/dewoller/brisbane_mq_distance.git
cd brisbane_mq_distance
```

When prompted for credentials:
- **Username:** your GitHub username
- **Password:** you need a Personal Access Token (not your actual password)

### Creating a Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click **Generate new token** then **Generate new token (classic)**
3. Give it a name like "My laptop"
4. Set expiration to 90 days (or longer)
5. Check the **repo** scope checkbox
6. Click **Generate token**
7. **Copy the token immediately** (you will not see it again)
8. Use this token as your password when git asks

## Step 6: Use Claude Code to Set Up and Run the Project

This is where it gets easy. Start Claude Code inside the project folder:

```bash
cd brisbane_mq_distance
claude
```

Then ask Claude Code to help you. Here are some things you can say:

### Install all the R packages

> Install all the R packages this project needs

Claude Code will read the project files and run the install commands for you.

### Install system dependencies (macOS)

> Install the system libraries needed for the sf R package on my Mac

### Run the pipeline

> Run the targets pipeline

### Check results

> Show me what output files were generated

### If something goes wrong

> The pipeline failed at the mb_routes step. Can you help me debug it?

Claude Code can read error messages, look at the code, and suggest fixes.

## Step 7: View the Results

After the pipeline completes, results are in the `output/` folder:

- `output/full_matrix.csv` — Complete postcode x location travel matrix
- `output/summary_table.csv` — Summary statistics per location
- `output/candidate_ranking.csv` — Ranked candidate locations
- `output/candidate_comparison.csv` — Candidates vs existing locations
- `output/violin_*.png` — Travel time distribution plots
- `output/travel_time_map.html` — Interactive map (open in browser)
- `output/population_map.html` — Population distribution map (open in browser)
- `output/summary_table.html` — Formatted summary table (open in browser)

Open the HTML files by double-clicking them — they open in your web browser.

## Troubleshooting

### "sf" package fails to install

This is the most common issue. The sf package needs system libraries:

**macOS:** Run `brew install gdal proj geos udunits` in Terminal. If you do not have Homebrew, install it first from https://brew.sh

**Windows:** sf should install automatically. If not, try installing from binary:
```r
install.packages("sf", type = "binary")
```

### Git asks for password repeatedly

Set up credential caching so you only enter your token once:
```bash
git config --global credential.helper store
```
Next time you enter your token, it will be saved.

### OSRM server is unreachable

The routing step requires access to a private OSRM server on Tailnet. Contact the project owner if you cannot reach `http://totoro.magpie-inconnu.ts.net:5001`.

### Pipeline seems stuck

The first run downloads ~300 MB of ABS Census data. This can take a while on slow connections. Check the terminal output for download progress messages.
