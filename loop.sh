#!/bin/bash

START_TIME=$(( $(date +%s) / 60 ))

firstTime=1

alreadyDone=0

# sudo pkill -9 provjobd

sudo sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

getWebhookData() {
    local output="{\"username\": \"$NAME\", "
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
    if shouldRestart; then
        alreadyDone=1

        local ip
        ip=$(tailscale ip --4)

        local hostname="old-$NAME-$RANDOM"

        sudo tailscale up --hostname="$hostname" --advertise-exit-node --ssh

        sleep 15 # interestingly, tailscale takes a while to update the hostname

        gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/repos/ChromeOS756/$REPO/actions/workflows/$WORKFLOW_FILE/dispatches" \
            -f "ref=$BRANCH" -f "inputs[runNext]=true" \
            -f "inputs[oldTailscaleHostname]=$ip" \
            -f "inputs[name]=$NAME" \
            -f "inputs[method]=$METHOD"

        if [ "$METHOD" == "aria2" ]; then
            sleep 45
        else
            sleep 10
        fi

        requestWebhook stop "$hostname"

        cd /mnt/globalData/toBackup || return

        if [ -f postruntime.sh ]; then
            . postruntime.sh
        fi

        if [ "$METHOD" == "aria2" ]; then
            cd /mnt/globalData || return

            sudo tar cf temp.tar toBackup/
            sudo mv temp.tar archive.tar # is this necessary?

            http-server -rd false -p 5000 &
        fi
    fi
}

shouldRestart() {
    local target_minutes=$((START_TIME + 330))  # 5 hours 30 minutes = 330 minutes

    local current_minutes=$(( $(date +%s) / 60 ))

    echo target minutes is $target_minutes
    echo current current is $current_minutes

    if [[ "$current_minutes" -eq "$target_minutes" ]]; then
        return 0
    else
        return 1
    fi
}

if [ "$IS_GLOBAL" == "true" ]; then
    requestWebhook start
fi

while true
do
    if [ "$firstTime" != 1 ] && [ "$alreadyDone" != 1 ] && [ "$IS_GLOBAL" == "true" ]; then
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
