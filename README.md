# 📊 CloudWatch Log Retention Manager

`cloudwatch-retention-update.sh` is a Bash script that audits AWS CloudWatch log groups with **no retention period set**, updates them to a **30-day retention**, and sends a **HTML email report** containing **color-coded tables**.

---

## 🔧 Features

✅ Identifies log groups **without retention**  
✅ Fetches **last log date**, **associated AWS service**, and **storage usage (in GB)**  
✅ Applies a **30-day retention policy**  
✅ Sends an **HTML email** via `sendmail` with:

- 📋 **Before Update Table**
- ✅ **After Update Table**

---

## 📁 Script Overview

- 📂 **Log Group Scan** — Uses `aws logs describe-log-groups` and `jq` to filter targets  
- ⏳ **Retention Status** — Detects `null` retention policies  
- 📅 **Last Log Timestamp** — Uses `describe-log-streams`  
- 💾 **Storage Usage (GB)** — Uses `cloudwatch:GetMetricStatistics` for `StoredBytes`  
- 📧 **HTML Email Report** — Sends two HTML tables (before & after) with colors

---

## 🚀 Usage

### Step 1: Make it executable
```bash
chmod +x cloudwatch-retention-update.sh

### Step 2: Make it executable
```bash
./cloudwatch-retention-update.sh

