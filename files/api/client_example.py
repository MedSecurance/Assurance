#!/usr/bin/env python3
"""
Example client for the O-ETB API.
This script demonstrates how to use the API to create a complete assurance case workflow.
"""

import requests
import json
import time
import sys

# Configuration
API_BASE_URL = "http://localhost:8080"
PATTERN_FILE = "../KB/PATTERNS/stm_patterns"
MODEL_ID = "2.0"
CASE_ID = "stm_system_example"


def api_request(endpoint, method="GET", data=None, timeout=60):
    """Make a request to the API"""
    url = f"{API_BASE_URL}/{endpoint}"
    
    if method == "GET":
        response = requests.get(url, timeout=timeout)
    elif method == "POST":
        headers = {"Content-Type": "application/json"}
        response = requests.post(url, json=data, headers=headers, timeout=timeout)
    else:
        raise ValueError(f"Unsupported method: {method}")
    
    if response.status_code != 200:
        print(f"Error: {response.status_code} - {response.text}")
        return None
    
    return response.json()


def check_api_health():
    """Check if the API is healthy"""
    response = api_request("health")
    if not response or response.get("status") != "healthy":
        print("Error: API is not healthy")
        if response:
            print(f"Details: {response.get('error', 'Unknown error')}")
        return False
    print(f"API is healthy - {response.get('version', 'unknown version')}")
    return True


def run_command(command, args=None, timeout=60):
    """Run an O-ETB command"""
    data = {"command": command, "timeout": timeout}
    if args:
        data["args"] = args
    
    response = api_request("command", method="POST", data=data, timeout=timeout)
    if not response or not response.get("success"):
        print(f"Error running command {command}: {response.get('error', 'Unknown error') if response else 'No response'}")
        return False
    
    print(f"Command output: {response.get('output', '')}")
    return True


def run_proc(proc_name, verbose=False, step_mode=False, timeout=300):
    """Run an O-ETB procedure"""
    data = {
        "proc_name": proc_name,
        "verbose": verbose,
        "step_mode": step_mode,
        "timeout": timeout
    }
    
    response = api_request("proc", method="POST", data=data, timeout=timeout)
    if not response or not response.get("success"):
        print(f"Error running procedure {proc_name}: {response.get('error', 'Unknown error') if response else 'No response'}")
        return False
    
    print(f"Procedure output: {response.get('output', '')}")
    return True


def instantiate_pattern(pattern_name, args, case_id, timeout=300):
    """Instantiate an assurance case pattern"""
    data = {
        "pattern_name": pattern_name,
        "args": args,
        "case_id": case_id,
        "timeout": timeout
    }
    
    response = api_request("instantiate_pattern", method="POST", data=data, timeout=timeout)
    if not response or not response.get("success"):
        print(f"Error instantiating pattern {pattern_name}: {response.get('error', 'Unknown error') if response else 'No response'}")
        return False
    
    print(f"Pattern instantiation output: {response.get('output', '')}")
    return True


def export_case(case_id, format="html"):
    """Export an assurance case"""
    data = {
        "case_id": case_id,
        "format": format
    }
    
    response = api_request("export_case", method="POST", data=data)
    if not response or not response.get("success"):
        print(f"Error exporting case {case_id}: {response.get('error', 'Unknown error') if response else 'No response'}")
        return False
    
    print(f"Export output: {response.get('output', '')}")
    return True


def run_complete_workflow():
    """Run a complete workflow to build and export an assurance case"""
    print("\n=== Starting complete workflow ===\n")
    
    # Check API health
    if not check_api_health():
        return False
    
    # 1. Load patterns
    print("\n--- Step 1: Loading patterns ---")
    if not run_command("load_patterns", args=[PATTERN_FILE]):
        return False
    
    # 2. Set model ID
    print("\n--- Step 2: Setting model ID ---")
    if not run_command("set_v", args=["ModelId", MODEL_ID]):
        return False
    
    # 3. Set case ID
    print("\n--- Step 3: Setting case ID ---")
    if not run_command("set_v", args=["CaseId", CASE_ID]):
        return False
    
    # 4. Load model
    print("\n--- Step 4: Loading model ---")
    if not run_command("load_model_v", args=["ModelId", "Policy", "_Platform", "_Configuration"]):
        return False
    
    # 5. Set system name
    print("\n--- Step 5: Setting system name ---")
    if not run_command("set_v", args=["SystemName", "stm_system"]):
        return False
    
    # 6. Set AC variable
    print("\n--- Step 6: Setting AC variable ---")
    ac_command = "set_v(AC, [ 'stm_safety'-[SystemName], 'person'-['Alicia', 'Assurance'], 'person'-['Roberto', 'Development'] ])."
    response = api_request("command", method="POST", data={"command": ac_command})
    if not response or not response.get("success"):
        print(f"Error setting AC variable: {response.get('error', 'Unknown error') if response else 'No response'}")
        return False
    print(f"Command output: {response.get('output', '')}")
    
    # 7. Instantiate pattern list
    print("\n--- Step 7: Instantiating pattern list ---")
    if not run_command("instantiate_pattern_list", args=["AC", "CaseId"]):
        return False
    
    # 8. Export as text
    print("\n--- Step 8: Exporting as text ---")
    if not export_case(CASE_ID, "txt"):
        return False
    
    # 9. Export as HTML
    print("\n--- Step 9: Exporting as HTML ---")
    if not export_case(CASE_ID, "html"):
        return False
    
    # 10. Detach case
    print("\n--- Step 10: Detaching case ---")
    if not run_command("detach_case"):
        return False
    
    print("\n=== Workflow completed successfully ===\n")
    return True


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print(f"Usage: {sys.argv[0]} [API_BASE_URL]")
        print("Example:")
        print(f"  {sys.argv[0]} http://localhost:8080")
        sys.exit(0)
    
    if len(sys.argv) > 1:
        API_BASE_URL = sys.argv[1]
    
    print(f"Using API at: {API_BASE_URL}")
    success = run_complete_workflow()
    sys.exit(0 if success else 1) 