# /bin/bash
function ninety_days_ago {
    date -v-90d -u "+%Y-%m-%dT%H:%M:%SZ"
}
ORG="$(git remote get-url origin | sed -n 's/.*:\/\/github.com\/\([^\/]*\)\/.*/\1/p')"
REPO="$(git remote get-url origin | sed 's/.*\/\([^ ]*\)\.git/\1/')"
TOKEN="$(cat ~/.ssh/github_token)"
# Initialize an empty array to hold all branches
branches=()
# Initialize the page number
page=1
# Loop until no more pages
while true; do
    # Get the branches for this page
    page_branches=$(curl -s -H "Authorization: token $TOKEN" \
                          -H "Accept: application/vnd.github.v3+json" \
                          "https://api.github.com/repos/${ORG}/${REPO}/branches?page=$page&per_page=100" | \
                          jq -r '.[].name')
    # If no branches were returned, we're done
    if [[ -z "$page_branches" ]]; then
        break
    fi
    # Add the branches from this page to the array
    branches+=($page_branches)
    # Increment the page number
    ((page++))
done
# Sort and remove duplicates
branches=$(echo "${branches[@]}" | tr ' ' '\n' | sort | uniq)
# Initialize an empty array to hold all committers
committers=()
# Iterate over all branches and get the committers separated by a | - also make sure the date is from when the actually pushed to the branch
for branch in $branches; do
    # echo "branch = $branch"
    commits=$(curl -s -H "Authorization: token $TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    https://api.github.com/repos/${ORG}/${REPO}/commits?since=$(ninety_days_ago)&sha=${branch})
    
    # Remove control characters
    commits=$(echo "$commits" | tr -d '\000-\031')

    # Check for errors
    if echo "$commits" | jq -e '.[0] | type == "object" and has("message")' > /dev/null; then
        echo "Error fetching commits for branch $branch: $(echo "$commits" | jq -r '.message')"
        continue
    fi

    # Extract the author login and add it to the committers array only add unique committers
    committers+=($(echo "$commits" | jq -r '.[].author.login' | sort | uniq | tr '\n' '|'))
done
# print the committers' names excluding duplicates and assign to a variable
committers=$(echo "${committers[@]}" | tr ' ' '\n' | sort | uniq | tr '|' '\n')

# Print the branches
echo "Branches:"
echo "$branches" | tr ' ' '\n' | column
# Print the committers
echo "Committers:"
echo "$committers" | tr '|' '\n' | column
# Print the number of unique committers. Delimiter is | and not \n because the committers array is a single string
echo "Number of unique committers: $(echo "$committers" | tr '|' '\n' | sort | uniq | wc -l)"
