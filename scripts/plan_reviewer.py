#!/usr/bin/env python3
import json
import os
import sys
import argparse
import urllib.request
import urllib.error
import re

def extract_json_block(text):
    match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', text, re.DOTALL)
    if match:
        return match.group(1)
    
    # Try finding any object-like structure as a fallback
    match = re.search(r'(\{.*\})', text, re.DOTALL)
    if match:
        return match.group(1)
        
    return text

def trigger_webhook(plan_json_path, prompt_text, webhook_url, webhook_secret, pr_number, repo):
    with open(plan_json_path, 'r') as f:
        plan_data = json.load(f)

    resource_changes = plan_data.get('resource_changes', [])
    
    # Simplify the plan for the webhook payload
    simplifed_plan = []
    for rc in resource_changes:
        addr = rc.get('address')
        actions = rc.get('change', {}).get('actions', [])
        before = rc.get('change', {}).get('before', {})
        after = rc.get('change', {}).get('after', {})
        
        simplifed_plan.append({
            "address": addr,
            "actions": actions,
            "before": before,
            "after": after,
        })
    
    body = {
        "repository": repo,
        "pull_request": pr_number,
        "original_request": prompt_text,
        "plan": simplifed_plan
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    if webhook_secret:
        headers["Authorization"] = f"Bearer {webhook_secret}"
        
    req = urllib.request.Request(
        webhook_url, 
        data=json.dumps(body).encode('utf-8'), 
        headers=headers, 
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Webhook triggered successfully. Status: {response.getcode()}")
            return True
    except urllib.error.HTTPError as e:
        print(f"HTTP Error triggering webhook: {e}")
        try:
            print(e.read().decode('utf-8'))
        except Exception:
            pass
        return False
    except Exception as e:
        print(f"Error triggering webhook: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Trigger Hermes webhook for plan review")
    parser.add_argument("--plan-json", required=True, help="Path to tofu plan json")
    parser.add_argument("--prompt-file", help="Path to original prompt text file")
    parser.add_argument("--pr-number", help="Pull request number")
    parser.add_argument("--repo", help="GitHub repository")
    args = parser.parse_args()

    webhook_url = os.environ.get("HERMES_WEBHOOK_URL")
    webhook_secret = os.environ.get("HERMES_WEBHOOK_SECRET")
    
    if not webhook_url:
        print("HERMES_WEBHOOK_URL environment variable is required")
        sys.exit(2)
        
    try:
        with open(args.prompt_file, 'r') as f:
            prompt_text = f.read()
    except Exception as e:
        print(f"Error reading prompt file: {e}")
        prompt_text = ""

    success = trigger_webhook(
        args.plan_json, 
        prompt_text, 
        webhook_url, 
        webhook_secret,
        args.pr_number,
        args.repo
    )
    
    if success:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
