#!/bin/bash

# Calculator using rofi
# Supports basic math operations and functions

if ! command -v bc &> /dev/null; then
    rofi -e "bc (calculator) is required"
    exit 1
fi

HISTORY_FILE="$HOME/.cache/rofi-calculator-history"
mkdir -p "$(dirname "$HISTORY_FILE")"

# Function to add calculation to history
add_to_history() {
    local calc="$1"
    local result="$2"
    local entry="$calc = $result"
    
    # Remove duplicates and add to top
    if [[ -f "$HISTORY_FILE" ]]; then
        grep -Fxv "$entry" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null || true
        echo "$entry" > "$HISTORY_FILE"
        head -n 49 "${HISTORY_FILE}.tmp" >> "$HISTORY_FILE" 2>/dev/null || true
        rm -f "${HISTORY_FILE}.tmp"
    else
        echo "$entry" > "$HISTORY_FILE"
    fi
}

# Build options with history and functions
options="🧮 Calculator - Enter expression\n📊 Functions: sin, cos, tan, sqrt, log, ln\n📋 Constants: pi=3.14159, e=2.71828\n🗑️  Clear History"

if [[ -f "$HISTORY_FILE" ]]; then
    options+="\n--- Recent Calculations ---"
    while IFS= read -r line; do
        options+="\n📈 $line"
    done < "$HISTORY_FILE"
fi

while true; do
    input=$(echo -e "$options" | rofi -dmenu -i -p "Calculator" -filter "$filter")
    
    # Handle special commands
    case "$input" in
        "🗑️  Clear History")
            rm -f "$HISTORY_FILE"
            rofi -e "Calculator history cleared"
            exit 0
            ;;
        📈*)
            # Copy result from history
            result=$(echo "$input" | sed 's/📈 .* = //')
            echo -n "$result" | xclip -selection clipboard 2>/dev/null || true
            rofi -e "Result copied to clipboard: $result"
            exit 0
            ;;
        "")
            exit 0
            ;;
    esac
    
    # Skip if it's a menu option
    if [[ "$input" =~ ^(🧮|📊|📋) ]]; then
        continue
    fi
    
    # Clean and prepare expression
    expression=$(echo "$input" | tr -d '🧮📊📋📈🗑️' | sed 's/Calculator - Enter expression//' | sed 's/Functions:.*//' | sed 's/Constants:.*//' | sed 's/Clear History//' | tr -d '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    if [[ -z "$expression" ]]; then
        continue
    fi
    
    # Replace common functions and constants
    expression=$(echo "$expression" | sed 's/pi/3.14159265359/g' | sed 's/\be\b/2.71828182846/g')
    
    # Validate expression (basic security)
    if [[ "$expression" =~ [^0-9+\-*/().,\ sincoantqlgre] ]]; then
        rofi -e "Invalid characters in expression"
        continue
    fi
    
    # Calculate result
    if result=$(echo "scale=6; $expression" | bc -l 2>/dev/null); then
        # Clean up result (remove trailing zeros)
        result=$(echo "$result" | sed 's/\.0*$//' | sed 's/\.\([0-9]*[1-9]\)0*/.\1/')
        
        # Show result and ask what to do
        action=$(echo -e "📋 Copy Result: $result\n🔄 New Calculation\n📝 Copy Expression\n💾 Save to History" | rofi -dmenu -p "$expression = $result")
        
        case "$action" in
            "📋 Copy Result:"*)
                echo -n "$result" | xclip -selection clipboard 2>/dev/null || true
                add_to_history "$expression" "$result"
                rofi -e "Result copied: $result"
                exit 0
                ;;
            "📝 Copy Expression")
                echo -n "$expression" | xclip -selection clipboard 2>/dev/null || true
                add_to_history "$expression" "$result"
                rofi -e "Expression copied: $expression"
                exit 0
                ;;
            "💾 Save to History")
                add_to_history "$expression" "$result"
                rofi -e "Saved to history: $expression = $result"
                exit 0
                ;;
            "🔄 New Calculation")
                add_to_history "$expression" "$result"
                filter=""
                continue
                ;;
            *)
                add_to_history "$expression" "$result"
                exit 0
                ;;
        esac
    else
        rofi -e "Error: Invalid expression '$expression'"
        filter="$expression"
    fi
done