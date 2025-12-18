#!/bin/bash

# Simple MCP stdio server in bash
# This server implements basic MCP protocol over stdio

# Function to send a JSON-RPC response
send_response() {
    local response="$1"
    echo "$response"
}

# Function to send an error response
send_error() {
    local id="$1"
    local code="$2"
    local message="$3"
    local error_response=$(cat <<EOF
{"jsonrpc":"2.0","id":$id,"error":{"code":$code,"message":"$message"}}
EOF
)
    send_response "$error_response"
}

# Function to handle initialize request
handle_initialize() {
    local id="$1"
    local response=$(cat <<EOF
{"jsonrpc":"2.0","id":$id,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"bash-mcp-server","version":"1.0.0"}}}
EOF
)
    send_response "$response"
}

# Function to handle tools/list request
handle_tools_list() {
    local id="$1"
    local response=$(cat <<EOF
{"jsonrpc":"2.0","id":$id,"result":{"tools":[{"name":"echo","description":"Echoes back the provided text","inputSchema":{"type":"object","properties":{"text":{"type":"string","description":"Text to echo back"}},"required":["text"]}},{"name":"get_time","description":"Returns the current date and time","inputSchema":{"type":"object","properties":{}}}]}}
EOF
)
    send_response "$response"
}

# Function to handle tools/call request
handle_tools_call() {
    local id="$1"
    local tool_name="$2"
    local arguments="$3"
    
    case "$tool_name" in
        "echo")
            local text=$(echo "$arguments" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)
            local response=$(cat <<EOF
{"jsonrpc":"2.0","id":$id,"result":{"content":[{"type":"text","text":"Echo: $text"}]}}
EOF
)
            send_response "$response"
            ;;
        "get_time")
            local current_time=$(date)
            local response=$(cat <<EOF
{"jsonrpc":"2.0","id":$id,"result":{"content":[{"type":"text","text":"Current time: $current_time"}]}}
EOF
)
            send_response "$response"
            ;;
        *)
            send_error "$id" -32601 "Unknown tool: $tool_name"
            ;;
    esac
}

# Main loop - read JSON-RPC requests from stdin
while IFS= read -r line; do
    # Extract method and id from the JSON request
    method=$(echo "$line" | grep -o '"method":"[^"]*"' | cut -d'"' -f4)
    id=$(echo "$line" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    case "$method" in
        "initialize")
            handle_initialize "$id"
            ;;
        "tools/list")
            handle_tools_list "$id"
            ;;
        "tools/call")
            tool_name=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
            arguments=$(echo "$line" | grep -o '"arguments":{[^}]*}' | cut -d':' -f2-)
            handle_tools_call "$id" "$tool_name" "$arguments"
            ;;
        "notifications/initialized")
            # No response needed for notifications
            ;;
        *)
            if [ -n "$id" ]; then
                send_error "$id" -32601 "Method not found: $method"
            fi
            ;;
    esac
done