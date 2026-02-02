#!/bin/bash
# TopTracker Switcher Configuration
# Edit this file to customize project-to-port mappings

# Project port mapping function
# Add your projects and their localhost ports here
get_project_port() {
    local project="$1"
    case "$(echo "$project" | tr '[:upper:]' '[:lower:]')" in
        # Example mappings - customize these!
        *myproject*)        echo "3000" ;;
        *webapp*)           echo "3001" ;;
        *api*)              echo "8080" ;;
        *frontend*)         echo "5173" ;;  # Vite default
        *nextjs*)           echo "3000" ;;  # Next.js default
        # Add more projects as needed:
        # *clientname*)     echo "4000" ;;
        *)                  echo "" ;;
    esac
}

# TopTracker email (for multi-account support)
# Change this to your TopTracker email
TOPTRACKER_EMAIL="jay.develop10@gmail.com"

# Screenshot interval (TopTracker default is 15 minutes)
INTERVAL_SECONDS=900

# How many seconds before screenshot to switch windows
WARN_BEFORE=30

# Keep-alive: prevent idle detection by simulating minimal activity
# Set to 0 to disable, or number of seconds between nudges (e.g., 60 = every minute)
KEEPALIVE_INTERVAL=60
