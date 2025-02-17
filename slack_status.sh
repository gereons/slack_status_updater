#!/bin/bash
CONFIG_FILE="$HOME/.slack_status.conf"
SAVE_FILE="$HOME/.slack_status.saved"

# Colors
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

# Simple setup command
if [[ $1 == "setup" ]]; then
    echo "${green}Slack status updater setup${reset}"
    echo "${green}==========================${reset}"
    echo
    echo "You need to have your slack api token ready. If you don't have one,"
    echo "go to https://github.com/mivok/slack_status_updater and follow the"
    echo "instructions there for creating a new slack app."
    echo
    read -r -p "${green}Enter your slack token: ${reset}" TOKEN
    cat > "$CONFIG_FILE" <<EOF
# vim: ft=sh
# Configuration file for slack_status
TOKEN=$TOKEN

PRESET_EMOJI_test=":white_check_mark:"
PRESET_TEXT_test="Testing status updater"

PRESET_EMOJI_zoom=":zoom:"
PRESET_TEXT_zoom="In a zoom meeting"
EOF
    echo
    echo "A default configuration has been created at ${green}$CONFIG_FILE.${reset}"
    echo "you can edit that file to add additional presets. Otherwise you"
    echo "are good to go!"
    exit 0
fi

if [[ -f "$CONFIG_FILE" ]]; then
    . "$CONFIG_FILE"
else
    echo "${green}Slack status updater${reset}"
    echo "${green}====================${reset}"
    echo
    echo "Set your slack status based on preconfigured presets"
    echo
    echo "No configuration file found at $CONFIG_FILE"
    echo "Run $0 setup to create one"
    exit 1
fi

PRESET="$1"
shift
ADDITIONAL_TEXT="$*"

if [[ -z $PRESET ]]; then
    echo "Usage: $0 PRESET [ADDITIONAL TEXT]"
    echo
    echo "Set your slack status based on preconfigured presets"
    echo ""
    echo "If you provide additional text, then it will be appended to the"
    echo "preset status."
    echo
    echo "Presets are defined in ${green}$CONFIG_FILE${reset}"
    echo
    echo "Run '${green}$0 setup${reset}' to create a new configuration file"
    exit 1
fi

if [[ $PRESET == "none" ]]; then
    EMOJI=""
    TEXT=""
    echo "Resetting slack status to blank"
elif [[ $PRESET == "save" ]]; then
    RESPONSE=$(curl -s --data token="$TOKEN" https://slack.com/api/users.profile.get)

    STATUS_EMOJI=$(echo $RESPONSE | jq -r .profile.status_emoji)    
    STATUS_TEXT=$(echo $RESPONSE | jq -r .profile.status_text)
    cat >$SAVE_FILE <<EOF
STATUS_EMOJI="$STATUS_EMOJI"
STATUS_TEXT="$STATUS_TEXT"
EOF

    echo "Saved current status to $SAVE_FILE"

    exit 0
elif [[ $PRESET == "restore" ]]; then
    if [ -r $SAVE_FILE ]; then
        . $SAVE_FILE
        EMOJI=$STATUS_EMOJI
        TEXT=$STATUS_TEXT
        rm $SAVE_FILE
        echo "Updating status to: ${yellow}$EMOJI ${green}$TEXT${reset}"
    else
        echo "${red}$SAVE_FILE not found!${reset}"
        exit 1
    fi
else
    eval "EMOJI=\$PRESET_EMOJI_$PRESET"
    eval "TEXT=\$PRESET_TEXT_$PRESET"

    if [[ -z $EMOJI || -z $TEXT ]]; then
        echo "${yellow}No preset found:${reset} $PRESET"
        echo
        echo "If this wasn't a typo, then you will want to add the preset to"
        echo "the config file at ${green}$CONFIG_FILE${reset} and try again."
        exit 1
    fi

    if [[ -n "$ADDITIONAL_TEXT" ]]; then
        TEXT="$TEXT $ADDITIONAL_TEXT"
    fi

    echo "Updating status to: ${yellow}$EMOJI ${green}$TEXT${reset}"
fi

PROFILE="{\"status_emoji\":\"$EMOJI\",\"status_text\":\"$TEXT\"}"
RESPONSE=$(curl -s --data token="$TOKEN" \
    --data-urlencode profile="$PROFILE" \
    https://slack.com/api/users.profile.set)
if echo "$RESPONSE" | grep -q '"ok":true,'; then
    echo "${green}Status updated ok${reset}"
else
    echo "${red}There was a problem updating the status${reset}"
    echo "Response: $RESPONSE"
fi
