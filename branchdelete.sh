# Delete all the branches which are older than 30 days 
#!/bin/bash
# Set the path to the release.json file
releaseJsonFile="branches.json"
# List all the branches from the release.json file
repoList=($(jq -r '.config[].repo | select(. != null)' "$releaseJsonFile"))
for repo in "${repoList[@]}"; do
    # Clone the repository
    repo_name=$(basename "$repo" .git)
    if ! git clone "$repo" "$repo_name"; then
        echo "Failed to clone repository: $repo"
        continue
    fi
    cd "$repo_name" || { echo "Failed to change directory to $repo_name"; exit 1; }
    echo "Current directory: $(pwd)" 
    git branch -r
    thirty_days_ago_timestamp=$(date -d "-30 days" "+%s")
    # Iterate over each branch
    while IFS= read -r branch; do
        branch=$(echo "$branch" | tr -d '[:space:]')  # Remove extra spaces
        if [ -n "$branch" ]; then  # Check if branch is not empty
            echo "Processing branch: $branch"  
            # Skip protected branches (master and release/*.*)
            if [[ "$branch" == "origin/master" || "$branch" == origin/release/*.* ]]; then
                echo "Skipping protected branch: $branch"
                continue
            fi
            git checkout -q "$branch"  # Checkout the branch
            last_commit_date=$(git log -1 --format="%cd" --date=iso-strict 2>/dev/null)
            if [ -n "$last_commit_date" ]; then
                last_commit_timestamp=$(date -d "$last_commit_date" "+%s")
                if [ "$last_commit_timestamp" -lt "$thirty_days_ago_timestamp" ]; then
                    echo "Branch to delete: $branch"
                    remote_branch=$(echo "${branch#origin/}")
                    git push origin --delete "$remote_branch"
                    echo "Branch deleted : $branch"
                else
                    echo "Branch created after threshold date: $branch"
                fi
            else
                echo "Branch $branch not found or does not have commits"
            fi
            
            # Output the last commit date
            echo "Last commit date: $last_commit_date"
        fi
    done < <(git branch -r | grep -v HEAD)
    cd ..
    rm -rf "$repo_name"
done
