#!/usr/bin/env python3
"""
Example agent script for interacting with the O-ETB Evidence Management System.

This script demonstrates uploading a file, downloading it, and verifying the content.
It also demonstrates the JSON-specific functionality for direct JSON upload and download.
"""

import os
import sys
import json
import time
import requests
import hashlib

# Constants
API_BASE_URL = "http://172.17.0.1:8000"
CATEGORY = "test"
JSON_CATEGORY = "threats"
TEST_FILE_CONTENT = b"valid"
TEST_FILENAME = "simple_result.txt"
TEST_SHA256 = hashlib.sha256(TEST_FILE_CONTENT).hexdigest()
SAMPLE_JSON_PATH = "/Assurance/KB/AGENTS/get_threats_OUTPUT.json"

# Colors for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
ENDC = "\033[0m"

class TestResult:
    def __init__(self, name, passed, message=None):
        self.name = name
        self.passed = passed
        self.message = message

    def __str__(self):
        status = f"{GREEN}PASS{ENDC}" if self.passed else f"{RED}FAIL{ENDC}"
        result = f"{status} - {self.name}"
        if self.message and not self.passed:
            result += f"\n  {RED}Error: {self.message}{ENDC}"
        return result


def run_test(name, func, *args, **kwargs):
    print(f"{BLUE}Running: {name}{ENDC}")
    try:
        result = func(*args, **kwargs)
        if isinstance(result, tuple) and len(result) == 2:
            success, message = result
            return TestResult(name, success, None if success else message)
        return TestResult(name, True)
    except Exception as e:
        return TestResult(name, False, str(e))


def test_upload_file():
    """Test uploading a file to the evidence store."""
    url = f"{API_BASE_URL}/upload/{CATEGORY}"
    
    # Create a temporary file for testing
    with open(TEST_FILENAME, "wb") as f:
        f.write(TEST_FILE_CONTENT)
    
    try:
        with open(TEST_FILENAME, "rb") as f:
            files = {"file": (TEST_FILENAME, f)}
            data = {"comment": "Test file uploaded by example agent"}
            response = requests.post(url, files=files, data=data)
        
        if response.status_code != 200:
            return False, f"Upload failed with status code {response.status_code}: {response.text}"
        
        data = response.json()
        if not data.get("status") == "success":
            return False, f"Upload response indicates failure: {data}"
        
        if "filename" not in data or "version_id" not in data or "timestamp" not in data:
            return False, f"Upload response missing expected fields: {data}"
        
        # Store the filename and version_id for later tests
        global uploaded_filename, uploaded_version_id
        uploaded_filename = data["filename"]
        uploaded_version_id = data["version_id"]
        
        reported_hash = data.get("sha256_hash", "")
        if reported_hash != TEST_SHA256:
            return False, f"Uploaded file hash mismatch. Expected: {TEST_SHA256}, Got: {reported_hash}"
        
        return True, None
    finally:
        # Clean up temporary test file
        if os.path.exists(TEST_FILENAME):
            os.remove(TEST_FILENAME)


def test_upload_json():
    """Test uploading JSON data directly to the evidence store."""
    url = f"{API_BASE_URL}/upload-json/{JSON_CATEGORY}"
    
    # Load the sample JSON file
    try:
        # Check if sample JSON file exists
        if not os.path.exists(SAMPLE_JSON_PATH):
            return False, f"Sample JSON file not found at {SAMPLE_JSON_PATH}"
        
        with open(SAMPLE_JSON_PATH, "r") as f:
            json_data = json.load(f)
            
        # Compute hash of the JSON data for verification
        json_content = json.dumps(json_data, indent=2).encode('utf-8')
        json_hash = hashlib.sha256(json_content).hexdigest()
        
        # Upload the JSON data
        headers = {"Content-Type": "application/json"}
        params = {
            "comment": "Test threats data uploaded by example agent",
            "original_filename": "threats_data.json"
        }
        
        response = requests.post(
            url, 
            json=json_data,
            params=params,
            headers=headers
        )
        
        if response.status_code != 200:
            return False, f"JSON upload failed with status code {response.status_code}: {response.text}"
        
        data = response.json()
        if not data.get("status") == "success":
            return False, f"JSON upload response indicates failure: {data}"
        
        # Store the filename and version_id for later tests
        global json_filename, json_version_id
        json_filename = data["filename"]
        json_version_id = data["version_id"]
        
        reported_hash = data.get("sha256_hash", "")
        
        print(f"  Uploaded JSON file: {json_filename} (version {json_version_id})")
        print(f"  JSON data contains {len(json_data.get('threats', []))} threat entries")
        
        return True, None
    except Exception as e:
        return False, f"Error uploading JSON data: {str(e)}"


def test_download_json_as_file():
    """Test downloading the JSON data as a regular file."""
    url = f"{API_BASE_URL}/download/{JSON_CATEGORY}/{json_filename}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"Download JSON file failed with status code {response.status_code}: {response.text}"
    
    # Parse the JSON content to verify it's valid
    try:
        json_data = json.loads(response.content)
        
        # Verify it's the expected JSON structure
        if "threats" not in json_data or not isinstance(json_data["threats"], list):
            return False, f"Downloaded JSON does not have the expected structure"
        
        print(f"  Downloaded JSON file contains {len(json_data.get('threats', []))} threat entries")
        
        return True, None
    except json.JSONDecodeError as e:
        return False, f"Downloaded content is not valid JSON: {str(e)}"


def test_download_json_parsed():
    """Test downloading the JSON data as parsed JSON directly."""
    url = f"{API_BASE_URL}/download/{JSON_CATEGORY}/{json_filename}?as_json=true"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"Download parsed JSON failed with status code {response.status_code}: {response.text}"
    
    # The response should already be parsed JSON
    json_data = response.json()
    
    # Verify it's the expected JSON structure
    if "threats" not in json_data or not isinstance(json_data["threats"], list):
        return False, f"Downloaded JSON does not have the expected structure"
    
    print(f"  Downloaded parsed JSON contains {len(json_data.get('threats', []))} threat entries")
    
    # Verify hash header is still included
    if not response.headers.get("X-SHA256-Hash"):
        return False, f"X-SHA256-Hash header missing from JSON response"
    
    return True, None


def test_list_evidence():
    """Test listing evidence in the category."""
    url = f"{API_BASE_URL}/list/{CATEGORY}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"List evidence failed with status code {response.status_code}: {response.text}"
    
    data = response.json()
    
    # Check if the uploaded file appears in the listing
    if uploaded_filename not in data:
        return False, f"Uploaded file '{uploaded_filename}' not found in listing: {data}"
    
    # Find our uploaded file version
    versions = data[uploaded_filename]
    version_found = False
    for version in versions:
        if version.get("version_id") == uploaded_version_id:
            version_found = True
            if version.get("sha256_hash") != TEST_SHA256:
                return False, f"Listed file hash mismatch. Expected: {TEST_SHA256}, Got: {version.get('sha256_hash')}"
    
    if not version_found:
        return False, f"Uploaded version {uploaded_version_id} not found in listing for {uploaded_filename}: {versions}"
    
    return True, None


def test_list_json_evidence():
    """Test listing JSON evidence in the JSON category."""
    url = f"{API_BASE_URL}/list/{JSON_CATEGORY}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"List JSON evidence failed with status code {response.status_code}: {response.text}"
    
    data = response.json()
    
    # Check if the uploaded JSON file appears in the listing
    if json_filename not in data:
        return False, f"Uploaded JSON file '{json_filename}' not found in listing: {data}"
    
    # Find our uploaded JSON file version
    versions = data[json_filename]
    version_found = False
    for version in versions:
        if version.get("version_id") == json_version_id:
            version_found = True
            if not version.get("is_json", False):
                return False, f"Listed JSON file not marked as JSON"
    
    if not version_found:
        return False, f"Uploaded JSON version {json_version_id} not found in listing for {json_filename}: {versions}"
    
    return True, None


def test_download_latest():
    """Test downloading the latest version of the file."""
    url = f"{API_BASE_URL}/download/{CATEGORY}/{uploaded_filename}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"Download latest failed with status code {response.status_code}: {response.text}"
    
    content = response.content
    
    # Verify content matches the original
    if content != TEST_FILE_CONTENT:
        return False, f"Downloaded content does not match original. Expected: {TEST_FILE_CONTENT}, Got: {content}"
    
    # Verify hash header
    if response.headers.get("X-SHA256-Hash") != TEST_SHA256:
        return False, f"Download hash header mismatch. Expected: {TEST_SHA256}, Got: {response.headers.get('X-SHA256-Hash')}"
    
    return True, None

def write_download_latest():
    """Test downloading the latest version of the file."""
    url = f"{API_BASE_URL}/download/{CATEGORY}/{uploaded_filename}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"Download latest failed with status code {response.status_code}: {response.text}"
    
    content = response.content
    
    # Verify content matches the original
    if content != TEST_FILE_CONTENT:
        return False, f"Downloaded content does not match original. Expected: {TEST_FILE_CONTENT}, Got: {content}"
    
    # Verify hash header
    if response.headers.get("X-SHA256-Hash") != TEST_SHA256:
        return False, f"Download hash header mismatch. Expected: {TEST_SHA256}, Got: {response.headers.get('X-SHA256-Hash')}"
    
    return content.decode('ascii')

def test_download_specific_version():
    """Test downloading a specific version of the file."""
    url = f"{API_BASE_URL}/download/{CATEGORY}/{uploaded_filename}?version_id={uploaded_version_id}"
    
    response = requests.get(url)
    
    if response.status_code != 200:
        return False, f"Download specific version failed with status code {response.status_code}: {response.text}"
    
    content = response.content
    
    # Verify content matches the original
    if content != TEST_FILE_CONTENT:
        return False, f"Downloaded content does not match original. Expected: {TEST_FILE_CONTENT}, Got: {content}"
    
    # Verify hash header
    if response.headers.get("X-SHA256-Hash") != TEST_SHA256:
        return False, f"Download hash header mismatch. Expected: {TEST_SHA256}, Got: {response.headers.get('X-SHA256-Hash')}"
    
    return True, None


def test_upload_second_version():
    """Test uploading a second version of the same file."""
    url = f"{API_BASE_URL}/upload/{CATEGORY}"
    
    # Create a modified test file for the second version
    second_content = b"This is the second version of the test file."
    second_hash = hashlib.sha256(second_content).hexdigest()
    
    # Create a temporary file for testing
    with open(TEST_FILENAME, "wb") as f:
        f.write(second_content)
    
    try:
        with open(TEST_FILENAME, "rb") as f:
            files = {"file": (TEST_FILENAME, f)}
            data = {
                "comment": "Second version of test file",
                "original_filename": TEST_FILENAME
            }
            response = requests.post(url, files=files, data=data)
        
        if response.status_code != 200:
            return False, f"Upload second version failed with status code {response.status_code}: {response.text}"
        
        data = response.json()
        if data.get("status") != "success":
            return False, f"Upload second version response indicates failure: {data}"
        
        # Verify filename is the same but version_id is incremented
        if data.get("filename") != uploaded_filename:
            return False, f"Second version has different filename. Expected: {uploaded_filename}, Got: {data.get('filename')}"
        
        if data.get("version_id") <= uploaded_version_id:
            return False, f"Second version ID not incremented. First version: {uploaded_version_id}, Second version: {data.get('version_id')}"
        
        # Store the second version ID
        global second_version_id
        second_version_id = data.get("version_id")
        
        # Verify reported hash
        if data.get("sha256_hash") != second_hash:
            return False, f"Second version hash mismatch. Expected: {second_hash}, Got: {data.get('sha256_hash')}"
        
        return True, None
    finally:
        # Clean up temporary test file
        if os.path.exists(TEST_FILENAME):
            os.remove(TEST_FILENAME)


def test_version_specific_delete():
    """Test deleting a specific version of the evidence."""
    # Delete the first version
    url = f"{API_BASE_URL}/delete/{CATEGORY}/{uploaded_filename}?version_id={uploaded_version_id}"
    
    response = requests.delete(url)
    
    if response.status_code != 200:
        return False, f"Delete specific version failed with status code {response.status_code}: {response.text}"
    
    # Verify it was deleted by trying to download it (should fail)
    download_url = f"{API_BASE_URL}/download/{CATEGORY}/{uploaded_filename}?version_id={uploaded_version_id}"
    download_response = requests.get(download_url)
    
    if download_response.status_code != 404:
        return False, f"Deleted version still downloadable with status code {download_response.status_code}"
    
    # Verify second version is still available
    second_download_url = f"{API_BASE_URL}/download/{CATEGORY}/{uploaded_filename}?version_id={second_version_id}"
    second_download_response = requests.get(second_download_url)
    
    if second_download_response.status_code != 200:
        return False, f"Undeleted version not downloadable with status code {second_download_response.status_code}"
    
    return True, None


def test_delete_all_versions():
    """Test deleting all versions of a file."""
    # Delete all versions
    url = f"{API_BASE_URL}/delete/{CATEGORY}/{uploaded_filename}"
    
    response = requests.delete(url)
    
    if response.status_code != 200:
        return False, f"Delete all versions failed with status code {response.status_code}: {response.text}"
    
    # Verify all versions are deleted by listing the category
    list_url = f"{API_BASE_URL}/list/{CATEGORY}"
    list_response = requests.get(list_url)
    
    if list_response.status_code != 200:
        return False, f"List after delete failed with status code {list_response.status_code}: {list_response.text}"
    
    data = list_response.json()
    
    # The uploaded file should no longer be in the listing
    if uploaded_filename in data:
        return False, f"File still present after delete all versions: {data}"
    
    return True, None


def test_delete_json_evidence():
    """Test deleting the JSON evidence."""
    url = f"{API_BASE_URL}/delete/{JSON_CATEGORY}/{json_filename}"
    
    response = requests.delete(url)
    
    if response.status_code != 200:
        return False, f"Delete JSON evidence failed with status code {response.status_code}: {response.text}"
    
    # Verify JSON evidence is deleted by listing the category
    list_url = f"{API_BASE_URL}/list/{JSON_CATEGORY}"
    list_response = requests.get(list_url)
    
    if list_response.status_code != 200:
        return False, f"List after JSON delete failed with status code {list_response.status_code}: {list_response.text}"
    
    data = list_response.json()
    
    # The uploaded JSON file should no longer be in the listing
    if json_filename in data:
        return False, f"JSON file still present after delete: {data}"
    
    return True, None


def main():
    # Variables to store upload results for subsequent tests
    global uploaded_filename, uploaded_version_id, second_version_id, json_filename, json_version_id
    uploaded_filename = None
    uploaded_version_id = None
    second_version_id = None
    json_filename = None
    json_version_id = None
    
    print(f"{YELLOW}O-ETB Evidence Management System - Example Agent{ENDC}")
    print(f"{YELLOW}================================================={ENDC}")
    print(f"API Base URL: {API_BASE_URL}")
    print(f"Test Category: {CATEGORY}")
    print(f"JSON Test Category: {JSON_CATEGORY}")
    print(f"Test File: {TEST_FILENAME}")
    print(f"Test File SHA-256: {TEST_SHA256}")
    print(f"Sample JSON File: {SAMPLE_JSON_PATH}")
    print()
    
    # Wait for the server to be ready
    max_retries = 5
    retry_interval = 2
    
    for attempt in range(max_retries):
        try:
            health_response = requests.get(f"{API_BASE_URL}/list/{CATEGORY}")
            if health_response.status_code == 200:
                break
        except requests.exceptions.ConnectionError:
            pass
        
        print(f"Waiting for server (attempt {attempt + 1}/{max_retries})...")
        time.sleep(retry_interval)
    else:
        print(f"{RED}Server not responding after {max_retries} attempts. Exiting.{ENDC}")
        return 1
    
    # Standard file tests
    standard_tests = [
        run_test("Upload File", test_upload_file),
        run_test("List Evidence", test_list_evidence),
        run_test("Download Latest Version", test_download_latest),
        run_test("Download Specific Version", test_download_specific_version),
        run_test("Upload Second Version", test_upload_second_version),
        run_test("Delete Specific Version", test_version_specific_delete),
        run_test("Delete All Versions", test_delete_all_versions),
    ]
    
    # JSON specific tests
    json_tests = [
        run_test("Upload JSON Data", test_upload_json),
        run_test("List JSON Evidence", test_list_json_evidence),
        run_test("Download JSON as File", test_download_json_as_file),
        run_test("Download JSON Parsed", test_download_json_parsed),
        run_test("Delete JSON Evidence", test_delete_json_evidence),
    ]
    
    # Combine all tests
    all_tests = standard_tests + json_tests
    
    # Print results
    print("\nTest Results:")
    print("============")
    
    passed = 0
    for test in all_tests:
        print(test)
        if test.passed:
            passed += 1
    
    print(f"\nSummary: {passed}/{len(all_tests)} tests passed")


    print(f"\n\nNOW TEST REAL LIFE SCENARIO.")
    print(f"Upload file to centralDB, download, read and write as evidance with simple message 'valid'.")
    print(f"The message is then passed to simple_agent.pl to pass the test.")
    test_upload_file() # Upload test file again

    with open('/Assurance/KB/AGENTS/simple_result.txt', 'w') as f:
        f.write(write_download_latest()) # Write the content of the latest version to pass simple_agent.pl
    
    print(f"\nPython gateway script completed.\n")
    # Return exit code based on test results
    return 0 if passed == len(all_tests) else 1


if __name__ == "__main__":
    sys.exit(main()) 