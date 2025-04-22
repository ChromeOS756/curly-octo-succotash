#!/bin/bash

START_TIME=$(TZ=Etc/UTC date +"%d:%m:%Y:%H:%M")

# actually required for gh cli
# shellcheck disable=SC2034
GH_TOKEN=$2

REPO=$3
WORKFLOW_FILE=$4
BRANCH=$5

NAME=$6

WEBHOOK_URL=$7

firstTime=1

alreadyDone=0

sudo pkill provjobd

sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

getWebhookData() {
    output="{\"username\": \"$NAME\", "
    output+="\"embeds\": [ "
    
    if [ "$1" == "start" ]; then
        output+="{\"title\": \"Loop Script is running!\", "
        output+="\"description\": \""
    else
        output+="{\"title\": \"Loop Script is stopping in 30 minutes!\", "
        output+="\"description\": \""
        output+="Hostname has been renamed to: $2\\n\\n"
    fi

    output+="$REPO on $BRANCH, workflow file $WORKFLOW_FILE\\n\\n"

    output+="Sent at:\\n$(date) (server time)\\n"
    output+="$(TZ=Etc/UTC date)"
    output+="\\n$(TZ=America/Los_Angeles date)"
    output+="\\n$(TZ=Asia/Tokyo date)"
    output+="\\n$(TZ=Asia/Bangkok date)\", "

    if [ "$1" == "start" ]; then
        output+="\"color\": 5763719} ]}"
    else
        output+="\"color\": 15105570} ]}"
    fi

    echo "$output"
}

requestWebhook() {
    curl \
        -X POST \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --data "$(getWebhookData "$1" "$2")" \
        "$WEBHOOK_URL"
}

check() {
    node checkTime.js "$START_TIME"
    exitCode=$?

    if [ $exitCode -eq 0 ]
    then
        alreadyDone=1

        ip=$(tailscale ip --4)

        hostname="old-$NAME-$RANDOM"

        sudo tailscale up --hostname="$hostname" --advertise-exit-node --ssh

        gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/repos/ChromeOS756/$REPO/actions/workflows/$WORKFLOW_FILE/dispatches" \
            -f "ref=$BRANCH" -f "inputs[runNext]=true" \
            -f "inputs[oldTailscaleHostname]=$ip" \
            -f "inputs[name]=$NAME"

        # this may cause issues if the new runtime starts in less than 10 seconds
        # (pretty unlikely but stil possible...)
        # usually it takes around 45 seconds to reach the rsync step
        sleep 10

        requestWebhook stop "$hostname"

        cd /mnt/globalData/toBackup || return

        if [ -f postruntime.sh ]; then
            . postruntime.sh
        fi
    fi
}

if [ "$1" == "true" ]; then
    requestWebhook start
fi

while true
do
    if [ "$firstTime" != 1 ] && [ "$alreadyDone" != 1 ] && [ "$1" == "true" ]; then
        check
    fi

    ping -c 1 google.com 
    curl google.com

    if [ "$firstTime" != 1 ]; then
        sleep 10
    else
        sleep 120

        firstTime=0
    fi
done
