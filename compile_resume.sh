#!/bin/zsh

TEX_FILE="/Users/arafatkhan/Desktop/Resume/main.tex"
PDF_FILE="/Users/arafatkhan/Desktop/Resume/main.pdf"
XELATEX_CMD="/usr/local/texlive/2025/bin/universal-darwin/xelatex"
LOG_FILE="/Users/arafatkhan/Desktop/Resume/resume_compile.log"
WORKING_DIR="/Users/arafatkhan/Desktop/Resume"
SLEEP_INTERVAL=5 # seconds

echo "Starting persistent resume compiler for $TEX_FILE"
echo "Watching for changes every $SLEEP_INTERVAL seconds..."
echo "Log file: $LOG_FILE"
echo "Press Ctrl+C to stop."

# Ensure the log file exists and is writable
touch "$LOG_FILE"
chmod 664 "$LOG_FILE"

# Get initial modification times
# stat -f %m gets modification time as Unix epoch timestamp on macOS
# If main.tex doesn't exist yet, this will be empty.
LAST_MODIFIED_TEX=$(stat -f %m "$TEX_FILE" 2>/dev/null) 

while true; do
  # Check if TEX_FILE exists before trying to get its mod time
  if [ ! -f "$TEX_FILE" ]; then
    echo "$(date): $TEX_FILE not found. Waiting..." | tee -a "$LOG_FILE"
    sleep "$SLEEP_INTERVAL"
    continue # Skip to next iteration
  fi

  CURRENT_MODIFIED_TEX=$(stat -f %m "$TEX_FILE")

  # Compile if:
  # 1. PDF doesn't exist OR
  # 2. TEX_FILE is newer than PDF_FILE OR
  # 3. TEX_FILE's modification time has changed since the last check (covers cases where PDF might be newer but TEX changed)
  if [ ! -f "$PDF_FILE" ] || [ "$TEX_FILE" -nt "$PDF_FILE" ] || [ "$CURRENT_MODIFIED_TEX" != "$LAST_MODIFIED_TEX" ]; then
    echo "$(date): Change detected in $TEX_FILE or $PDF_FILE outdated/missing. Compiling..." | tee -a "$LOG_FILE"
    
    cd "$WORKING_DIR" || { 
      echo "$(date): ERROR - Failed to cd to $WORKING_DIR. Exiting." | tee -a "$LOG_FILE"; 
      exit 1; 
    }
    
    # First compilation pass
    # Using -halt-on-error to stop if the first pass fails badly
    if "$XELATEX_CMD" -interaction=nonstopmode -halt-on-error main.tex >> "$LOG_FILE" 2>&1; then
      echo "$(date): First compilation run successful." | tee -a "$LOG_FILE"
      # Second compilation pass for references
      if "$XELATEX_CMD" -interaction=nonstopmode -halt-on-error main.tex >> "$LOG_FILE" 2>&1; then
        echo "$(date): Second compilation run successful. PDF updated: $PDF_FILE" | tee -a "$LOG_FILE"
      else
        echo "$(date): ERROR - Second compilation run failed. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
      fi
    else
      echo "$(date): ERROR - First compilation run failed. Check $LOG_FILE for details." | tee -a "$LOG_FILE"
    fi
    # Update the last known modification time of main.tex
    LAST_MODIFIED_TEX="$CURRENT_MODIFIED_TEX"
  fi
  
  sleep "$SLEEP_INTERVAL"
done
