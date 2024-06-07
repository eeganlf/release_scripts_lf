#!/bin/bash
# This script creates a course repository, an assoicated team with the parent team of Course Maintainers, 
# and adds a user to the team. It is meant for use in lftraining
# Run this script with the course number (e.g. LFS307) and the github username of the user to invite to the associated team that is created

# Check if the repository name and GitHub username are provided as arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <repository-name> <github-username>"
    echo "Please provide the repository name and GitHub username as arguments."
    exit 1
fi

repo_name=$1
team_name=$repo_name
username=$2

# Create a new repository using the GitHub template
gh repo create lftraining/$repo_name --template lftraining/ILT-course-template --private

# Create a new team with the same name as the repository
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /orgs/lftraining/teams \
  -f name=$team_name \
  -f permission='push' \
  -f notification_setting='notifications_enabled' \
  -f privacy='closed' \
  -F parent_team_id=7100545
  #  -f description='A great team' \
#  course-maintainers id: 7100545
# Invite the user to the team
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /orgs/lftraining/teams/$team_name/memberships/$username \
  -f role='maintainer' 

# Associate the team with the repository
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /orgs/lftraining/teams/$team_name/repos/lftraining/$repo_name \
  -f permission='push' 

# Clone the newly created repository using SSH
git clone git@github.com:lftraining/$repo_name.git

# Change to the repository directory
cd $repo_name

git submodule update --init --recursive

# Rename COURSENUMBER.tex to the repository name
mv COURSENUMBER.tex $repo_name.tex

# Replace COURSENUMBERHERE with the repository name only in the \newcommand{\course} line
sed -i "/\\\\newcommand{\\\\course}/{s/COURSENUMBERHERE/$repo_name/}" $repo_name.tex

# Stage the changes
git add .

# Commit the changes
git commit -m "Initialize repository with customized .tex file"

# Push the changes back to GitHub using SSH
git push origin main

echo "Repository $repo_name created, configured, and pushed to GitHub successfully."
echo "Team $team_name created, user $username invited, and associated with the repository."


