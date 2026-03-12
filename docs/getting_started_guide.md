# Getting Started: From Zero to Running This Project

This guide walks you through downloading and running this project. The project is public on GitHub so no account or invitation is needed to download it.

## Step 1: Install Required Software

You need three things installed on your computer:

### 1a. Install Git

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

### 1b. Install R

**macOS:**
1. Go to https://cran.r-project.org/bin/macosx/
2. Download the `.pkg` file for your Mac (Apple Silicon or Intel)
3. Double-click the downloaded file and follow the installer

**Windows:**
1. Go to https://cran.r-project.org/bin/windows/base/
2. Click "Download R-4.x.x for Windows"
3. Run the installer, accepting all defaults

### 1c. Install Claude Code

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

## Step 2: Download the Project

In your terminal, navigate to where you want the project (e.g., your home folder or a projects folder):

```bash
cd ~
git clone https://github.com/dewoller/brisbane_mq_distance.git
cd brisbane_mq_distance
```

No login or credentials are needed — the repository is public.

## Step 3: Use Claude Code to Set Up and Run the Project

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

## Step 4: View the Results

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

### OSRM server is unreachable

The routing step requires access to a private OSRM server on Tailnet. Contact the project owner if you cannot reach `http://totoro.magpie-inconnu.ts.net:5001`.

### Pipeline seems stuck

The first run downloads ~300 MB of ABS Census data. This can take a while on slow connections. Check the terminal output for download progress messages.
