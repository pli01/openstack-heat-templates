# Send success status to OpenStack WaitCondition
function notify_success() {
    export http_proxy=$http_proxy
    export https_proxy=$http_proxy
    export no_proxy=$no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

# Send success status to OpenStack WaitCondition
function notify_failure() {
    export http_proxy=$http_proxy
    export https_proxy=$http_proxy
    export no_proxy=$no_proxy

    $wc_notify --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}
