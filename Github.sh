#!/bin/bash

# Function to get user details
get_user_details() {
    user_response=$(curl -s -u "$username:$access_token" "https://api.github.com/users/$target_username")
    name=$(echo "$user_response" | jq -r '.name')
    user_username=$(echo "$user_response" | jq -r '.login')
    followers=$(echo "$user_response" | jq -r '.followers')
    following=$(echo "$user_response" | jq -r '.following')
    gists=$(echo "$user_response" | jq -r '.public_gists')
    location=$(echo "$user_response" | jq -r '.location')
    bio=$(echo "$user_response" | jq -r '.bio')
    company=$(echo "$user_response" | jq -r '.company')
    repos_response=$(curl -s -u "$username:$access_token" "https://api.github.com/users/$target_username/repos")
    total_repos=$(echo "$repos_response" | jq '. | length')
    total_size=0
    for row in $(echo "${repos_response}" | jq -r '.[] | @base64'); do
        _jq() {
            echo "$row" | base64 --decode | jq -r "$1"
        }
        repo_size=$(_jq '.size')
        total_size=$(echo "$total_size + $repo_size" | bc)
    done
    total_size_in_mb=$(echo "scale=2; $total_size/1024" | bc)
    starred_repos_response=$(curl -s -u "$username:$access_token" "https://api.github.com/users/$target_username/starred")
    star_repos_count=$(echo "$starred_repos_response" | jq '. | length')
    star_repos_total_size=0
    for row in $(echo "${starred_repos_response}" | jq -r '.[] | @base64'); do
        _jq() {
            echo "$row" | base64 --decode | jq -r "$1"
        }
        repo_size=$(_jq '.size')
        star_repos_total_size=$(echo "$star_repos_total_size + $repo_size" | bc)
    done
    star_repos_total_size_in_mb=$(echo "scale=2; $star_repos_total_size/1024" | bc)
          
    echo "User Details:"
    [ ! -z "$name" ] && [ "$name" != "null" ] && echo "Name                           : $name"
    [ ! -z "$user_username" ] && [ "$user_username" != "null" ] && echo "Username                       : $user_username"
    [ ! -z "$total_repos" ] && [ "$total_repos" != "null" ] && echo "Total Repos                    : $total_repos"
    [ ! -z "$total_size_in_mb" ] && [ "$total_size_in_mb" != "null" ] && echo "Total Size                     : $total_size_in_mb MB"
    [ ! -z "$star_repos_count" ] && [ "$star_repos_count" != "null" ] && echo "Star Repos                     : $star_repos_count"
    [ ! -z "$star_repos_total_size_in_mb" ] && [ "$star_repos_total_size_in_mb" != "null" ] && echo "Total Size of Star Repos       : $star_repos_total_size_in_mb MB"
    [ ! -z "$followers" ] && [ "$followers" != "null" ] && echo "Followers                      : $followers"
    [ ! -z "$following" ] && [ "$following" != "null" ] && echo "Following                      : $following"
    [ ! -z "$gists" ] && [ "$gists" != "null" ] && echo "Public Gists                   : $gists"
    [ ! -z "$location" ] && [ "$location" != "null" ] && echo "Location                       : $location"

    [ ! -z "$company" ] && [ "$company" != "null" ] && echo "Company                        : $company"
    echo
    [ ! -z "$bio" ] && [ "$bio" != "null" ] && echo "$bio"
    echo
}



# Function to clone repositories
clone_repos() {
    for row in $(echo "$1" | jq -r '.[] | @base64'); do
        _jq() {
            echo "$row" | base64 --decode | jq -r "$1"
        }

        repo_name=$(_jq '.name')
        repo_size=$(echo "scale=2; $(_jq '.size')/1024" | bc)
        owner=$(_jq '.owner.login')
        created_at=$(_jq '.created_at')
        updated_at=$(_jq '.updated_at')
        stars=$(_jq '.stargazers_count')
        forks=$(_jq '.forks_count')
        language=$(_jq '.language // "N/A"')
        description=$(_jq '.description // "N/A"')
        # Modification here to accommodate the owner's folder
        clone_folder="$2/$owner/$repo_name"


        echo "Repository Name: $repo_name"
        echo "Description    : $description"
        echo "Size           : $repo_size MB"
        echo "Owner          : $owner"
        echo "Language       : $language"
        echo "Created At     : $created_at"
        echo "Updated At     : $updated_at"
        echo "Stars          : $stars"
        echo "Forks          : $forks"

        echo

        if [ "$3" == "ask" ]; then
            read -p "Do you want to clone it? (y/n): " answer
        else
            answer="y"
        fi

        if [ "$answer" == "y" ]; then
            # Clone the repository using Git
            repo_url=$(_jq '.clone_url')
            git clone "$repo_url" "$clone_folder"

            # Check if cloning was successful
            if [ $? -eq 0 ]; then
                echo "Repository '$repo_name' cloned successfully!"
                echo
            else
                echo "Failed to clone the repository '$repo_name'."
                echo
            fi
        else
            echo "Skipping repository '$repo_name'."
            echo
        fi
    done
}

clone_all_user_repositories() {
    read -p "Enter the GitHub username whose repositories you want to clone: " target_username
    echo
    get_user_details "$target_username"
    api_url="https://api.github.com/users/$target_username/repos?per_page=10000"
    response=$(curl -s -u "$username:$access_token" "$api_url")

    read -p "Do you want to clone all repositories at once or ask for permission for each repo? (all/ask): " clone_choice
    echo
    folder="cloned/$target_username"

    mkdir -p "$folder"

    clone_repos "$response" "$folder" "$clone_choice"
}

clone_all_stars_user_repositories() {
    read -p "Enter the GitHub username whose starred repositories you want to clone: " target_username
    echo
    get_user_details "$target_username"
    api_url="https://api.github.com/users/$target_username/starred?per_page=10000"
    response=$(curl -s -u "$username:$access_token" "$api_url")

    read -p "Do you want to clone all starred repositories at once or ask for permission for each repo? (all/ask): " clone_choice
    echo

    # Changes made here
    clone_repos "$response" "cloned" "$clone_choice"
}


# Check if auth.json file exists
if [ -f "auth.json" ]; then
    # Read username and access token from auth.json
    username=$(jq -r '.username' auth.json)
    access_token=$(jq -r '.access_token' auth.json)
else
    # Prompt the user to enter GitHub username and access token
    read -p "Enter your GitHub username: " username
    read -p "Enter your GitHub access token: " access_token

    # Validate username and access token
    if [ -z "$username" ] || [ -z "$access_token" ]; then
        echo "Invalid username or access token. Exiting..."
        exit 1
    fi

    # Store username and access token in auth.json
    echo "{\"username\":\"$username\",\"access_token\":\"$access_token\"}" > auth.json
fi

clear

# Display welcome message
echo "Welcome, $username!"

search_github() {
    read -p "Enter your search query: " query

    echo "Searching GitHub for: $query"

    page=1
    per_page=3

    while true; do
        # Make API call to search repositories based on the query
        results=$(curl -s "https://api.github.com/search/repositories?q=$query&per_page=$per_page&page=$page" | jq -r '.items[] | {name, description, owner: .owner.login, language, size, stargazers_count, forks_count, created_at, updated_at} | @base64')

        # Check if there are any search results
        if [ -z "$results" ]; then
            echo "No repositories found for: $query"
            return
        fi

        clear
        echo "Page: $page"
        echo "Search Results for: $query"
        echo "----------------------------"

        i=0
        echo "$results" | while read -r encoded_repo; do
            decoded_repo=$(echo "$encoded_repo" | base64 --decode)
            repo_name=$(echo "$decoded_repo" | jq -r '.name')
            owner=$(echo "$decoded_repo" | jq -r '.owner')
            description=$(echo "$decoded_repo" | jq -r '.description // "N/A"')
            language=$(echo "$decoded_repo" | jq -r '.language // "N/A"')
            size_kb=$(echo "$decoded_repo" | jq -r '.size / 1024')
            size_mb=$(printf "%.2f" "$size_kb")
            stars=$(echo "$decoded_repo" | jq -r '.stargazers_count')
            forks=$(echo "$decoded_repo" | jq -r '.forks_count')
            created_date=$(echo "$decoded_repo" | jq -r '.created_at | fromdateiso8601 | strftime("%Y-%m-%d")')
            updated_date=$(echo "$decoded_repo" | jq -r '.updated_at | fromdateiso8601 | strftime("%Y-%m-%d")')
            
            echo "[$((i+1))] $repo_name"
            echo "Description  : $description"
            echo "Owner        : $owner"
            echo "Language     : $language"
            echo "Size         : ${size_mb} MB"
            echo "Stars        : $stars"
            echo "Forks        : $forks"
            echo "Created Date : $created_date"
            echo "Updated Date : $updated_date"
            echo "----------------------------"
            ((i++))
        done

        echo "Select a repository number to clone or press Enter for the next page."
        echo "Press 0 to go back to the main menu."
        
        read -p "Enter a number: " input

        if [ -z "$input" ]; then
            # If Enter is pressed, go to the next page
            ((page++))
        elif [ "$input" -eq 0 ]; then
            # If 0 is pressed, go back to the main menu
            return
        elif [ "$input" -le $per_page ]; then
            # Otherwise, decode the selected repository and clone it
            selected_repo=$(echo "$results" | sed -n "$input"p)
            decoded_repo=$(echo "$selected_repo" | base64 --decode)
            repo_name=$(echo "$decoded_repo" | jq -r '.name')
            owner=$(echo "$decoded_repo" | jq -r '.owner')
            clone_url="https://github.com/$owner/$repo_name.git"
            access_token=$(jq -r '.token' auth.json)

            # Set the access token as an environment variable for git
            export GITHUB_TOKEN=$access_token
            git clone "$clone_url" "cloned/$owner/$repo_name"

            # Unset the environment variable after the clone is done
            unset GITHUB_TOKEN
            
            echo "Repository cloned successfully!"
            read -p "Press Enter to continue."
        fi
    done
}



# Main menu
while true; do
    clear


    echo "                Welcome to the Github CLI!"
    echo "        This tool is the part of hackroxs project."
    echo
    echo "------------------ Hackeroxs Main Menu ------------------"
    echo
    echo "1 - Search GitHub"
    echo "2 - Clone all repositories of a user into a single folder"
    echo "3 - Clone all starred repositories of a user into a single folder"
    echo "4 - Logout"
    echo "5 - Help"
    echo "0 - Exit"
    echo

    read -p "Enter your choice: " choice

    case $choice in
        1)
            search_github
            ;;
        2)
            clone_all_user_repositories
            ;;
        3)
            clone_all_stars_user_repositories
            ;;
        4)
            # Remove auth.json to logout
            rm -f auth.json
            echo "Logged out. Exiting..."
            exit 0
            ;;
        5)
            echo "Help menu:"
            echo "======================================"
            echo "GitHub Repository Management Tool: Quick Guide"
            echo ""
            echo "Prerequisites:"
            echo "   - Install jq, curl, and git."
            echo "   - Run the script."
            echo "   - Input GitHub username & access token when prompted."
            echo ""
            echo "Usage:"
            echo "   a) Run the script."
            echo "   b) Choose an option:"
            echo "      1. Search GitHub repositories."
            echo "      2. Clone all repos of a user."
            echo "      3. Clone starred repos of a user."
            echo "      4. Logout (clears credentials)."
            echo "      5. Help."
            echo ""
            echo "Tips:"
            echo "   - Check token permissions if there are issues."
            echo "   - Ensure enough disk space before cloning."
            echo "======================================"
            
            read -p "Press Enter to return to the main menu..." keypress
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Try again."
            ;;
    esac
done
