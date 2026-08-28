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

def evaluate_plan(plan_json_path, prompt_text, api_key, model="gpt-4o"):
    with open(plan_json_path, 'r') as f:
        plan_data = json.load(f)

    resource_changes = plan_data.get('resource_changes', [])
    
    # Simplify the plan for the LLM
    simplifed_plan = []
    for rc in resource_changes:
        addr = rc.get('address')
        actions = rc.get('change', {}).get('actions', [])
        before = rc.get('change', {}).get('before', {})
        after = rc.get('change', {}).get('after', {})
        
        # Omit huge binary or complex fields if necessary, 
        # but for OpenTofu baseline infrastructure, it usually fits fine.
        simplifed_plan.append({
            "address": addr,
            "actions": actions,
            "before": before,
            "after": after,
        })
    
    plan_str = json.dumps(simplifed_plan, indent=2)
    
    system_prompt = (
        "You are an infrastructure security and compliance reviewer.\n"
        "Your task is to evaluate an OpenTofu (Terraform) plan against the user's original implementation request.\n"
        "Criteria:\n"
        "1. INTENT MATCH: Does the plan achieve the requested state as described in the prompt?\n"
        "2. NO UNINTENDED DESTRUCTION: Are there destructive changes (delete/replace) to resources not implied by the prompt?\n"
        "3. SCOPE CONTAINMENT: Does it avoid modifying resources outside the requested scope?\n\n"
        "Respond with a JSON object containing exactly two fields (no other text):\n"
        "{\n"
        '  "approved": <true or false>,\n'
        '  "reason": "<short explanation of your decision>"\n'
        "}"
    )

    user_prompt = (
        f"Original User Request:\n{prompt_text}\n\n"
        f"OpenTofu Plan Changes:\n{plan_str}\n"
    )

    url = os.environ.get("OPENAI_API_BASE")
    if not url:
        if os.environ.get("OPENROUTER_API_KEY") and not os.environ.get("OPENAI_API_KEY"):
            url = "https://openrouter.ai/api/v1/chat/completions"
        else:
            url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
    }

    req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers=headers, method="POST")
    content = ""
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            content = result["choices"][0]["message"]["content"]
            
            clean_content = extract_json_block(content)
            decision = json.loads(clean_content)
            return decision
    except urllib.error.HTTPError as e:
        print(f"HTTP Error calling LLM API: {e}")
        try:
            print(e.read().decode('utf-8'))
        except Exception:
            pass
        sys.exit(2)
    except urllib.error.URLError as e:
        print(f"URL Error calling LLM API: {e}")
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON from LLM: {e}")
        if 'content' in locals():
            print(f"Raw response: {content}")
        sys.exit(2)

def main():
    parser = argparse.ArgumentParser(description="Evaluate OpenTofu plan using LLM")
    parser.add_argument("--plan-json", required=True, help="Path to tofu plan json")
    parser.add_argument("--prompt", help="Original prompt text")
    parser.add_argument("--prompt-file", help="Path to original prompt text file")
    parser.add_argument("--model", default=os.environ.get("LLM_MODEL", "gpt-4o"), help="Model to use")
    args = parser.parse_args()

    # Support either OPENAI_API_KEY or OPENROUTER_API_KEY (or ANTHROPIC_API_KEY if using Anthropic natively, but let's assume OpenAI compat)
    api_key = os.environ.get("OPENAI_API_KEY") or os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print("OPENAI_API_KEY or OPENROUTER_API_KEY environment variable is required")
        sys.exit(2)
        
    if args.prompt:
        prompt_text = args.prompt
    elif args.prompt_file:
        try:
            with open(args.prompt_file, 'r') as f:
                prompt_text = f.read()
        except Exception as e:
            print(f"Error reading prompt file: {e}")
            sys.exit(2)
    else:
        print("Either --prompt or --prompt-file is required")
        sys.exit(2)

    try:
        decision = evaluate_plan(args.plan_json, prompt_text, api_key, args.model)
    except Exception as e:
        print(f"Evaluation failed: {e}")
        sys.exit(2)
    
    print(f"Result: {'APPROVED' if decision.get('approved') else 'REJECTED'}")
    print(f"Reason: {decision.get('reason')}")

    if decision.get("approved"):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
