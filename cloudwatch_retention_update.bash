#!/bin/bash

# Config
EMAIL_TO="your-email@example.com"
EMAIL_FROM="noreply@example.com"
EMAIL_SUBJECT="CloudWatch Log Groups Retention Update Report"
TMP_HTML="/tmp/cloudwatch_report.html"
TMP_UPDATED="/tmp/updated_log_groups.txt"
LOG_FILE="/var/log/cloudwatch_retention_update.log"
RETENTION_DAYS=30
REGION="us-east-1" # Change if needed

# Initialize
echo "---- $(date) ----" >> "$LOG_FILE"
> "$TMP_HTML"
> "$TMP_UPDATED"

# Start HTML body
cat <<EOF >> "$TMP_HTML"
<html><head>
<style>
table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #4CAF50; color: white; }
tr:nth-child(even) { background-color: #f2f2f2; }
</style>
</head><body>
<h2>CloudWatch Log Groups with No Retention Policy - Updated to $RETENTION_DAYS Days</h2>
<h3>Before Update</h3>
<table>
<tr><th>Log Group Name</th><th>Current Retention</th><th>Last Log Date</th><th>AWS Service</th><th>Storage (GB)</th></tr>
EOF

# Fetch log groups with no retention
LOG_GROUPS=$(aws logs describe-log-groups --region "$REGION" --query 'logGroups[?retentionInDays==null]' --output json)

# Process each log group
echo "$LOG_GROUPS" | jq -c '.[]' | while read -r log_group; do
    NAME=$(echo "$log_group" | jq -r '.logGroupName')
    CURRENT_RETENTION="None"

    # Last log event time
    LAST_EPOCH=$(aws logs describe-log-streams \
        --region "$REGION" \
        --log-group-name "$NAME" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --query 'logStreams[0].lastEventTimestamp' \
        --output text 2>/dev/null)

    if [[ "$LAST_EPOCH" == "None" || -z "$LAST_EPOCH" ]]; then
        LAST_LOG_DATE="N/A"
    else
        LAST_LOG_DATE=$(date -d @"$((LAST_EPOCH / 1000))" "+%Y-%m-%d %H:%M:%S")
    fi

    # Determine AWS Service Name
    if [[ "$NAME" == "/aws/"* ]]; then
        SERVICE=$(echo "$NAME" | cut -d'/' -f3)
    else
        SERVICE="Custom/Other"
    fi

    # Estimate storage used (CloudWatch metric - EstimatedStoredBytes)
    METRIC_DATA=$(aws cloudwatch get-metric-statistics \
        --region "$REGION" \
        --namespace "AWS/Logs" \
        --metric-name "StoredBytes" \
        --dimensions Name=LogGroupName,Value="$NAME" \
        --statistics Sum \
        --start-time "$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --period 604800 \
        --output json)

    STORAGE_BYTES=$(echo "$METRIC_DATA" | jq -r '.Datapoints[0].Sum // 0')
    STORAGE_GB=$(awk "BEGIN {printf \"%.2f\", $STORAGE_BYTES / (1024*1024*1024)}")

    # Add to before table
    echo "<tr><td>$NAME</td><td>$CURRENT_RETENTION</td><td>$LAST_LOG_DATE</td><td>$SERVICE</td><td>${STORAGE_GB} GB</td></tr>" >> "$TMP_HTML"

    # Set retention
    aws logs put-retention-policy --region "$REGION" --log-group-name "$NAME" --retention-in-days "$RETENTION_DAYS" >> "$LOG_FILE" 2>&1

    # Add to after update list
    echo "$NAME|$RETENTION_DAYS|$LAST_LOG_DATE|$SERVICE|$STORAGE_GB" >> "$TMP_UPDATED"
done

# Close first table
echo "</table>" >> "$TMP_HTML"

# Start second table
echo "<h3>After Update</h3><table>" >> "$TMP_HTML"
echo "<tr><th>Log Group Name</th><th>New Retention</th><th>Last Log Date</th><th>AWS Service</th><th>Storage (GB)</th></tr>" >> "$TMP_HTML"

# Read updated info
while IFS='|' read -r NAME NEW_RET LAST_DATE SERVICE STORAGE_GB; do
    echo "<tr><td>$NAME</td><td>${NEW_RET} Days</td><td>$LAST_DATE</td><td>$SERVICE</td><td>${STORAGE_GB} GB</td></tr>" >> "$TMP_HTML"
done < "$TMP_UPDATED"

# Close HTML
cat <<EOF >> "$TMP_HTML"
</table>
<br><p>Regards,<br>CloudOps Team</p>
</body></html>
EOF

# Send email
{
    echo "From: $EMAIL_FROM"
    echo "To: $EMAIL_TO"
    echo "Subject: $EMAIL_SUBJECT"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/html"
    echo ""
    cat "$TMP_HTML"
} | sendmail -t

# Clean up
rm -f "$TMP_HTML" "$TMP_UPDATED"
