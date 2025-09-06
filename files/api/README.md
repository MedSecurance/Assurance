# O-ETB API

This API provides a RESTful interface for interacting with the Open Evidential Tool Bus (O-ETB). It allows you to run O-ETB commands, execute procedures, instantiate patterns, and export assurance cases through HTTP requests.

## Endpoints

### Health Check

```
GET /health
```

Checks if the O-ETB is accessible and returns its version information.

**Response:**
```json
{
  "status": "healthy",
  "version": "O-ETB version 1.1.1"
}
```

### Root

```
GET /
```

Simple check to see if the API is running.

**Response:**
```json
{
  "message": "O-ETB API is running"
}
```

### Run Command

```
POST /command
```

Runs an arbitrary O-ETB command.

**Request Body:**
```json
{
  "command": "load_patterns",
  "args": ["../KB/PATTERNS/stm_patterns"],
  "timeout": 60
}
```

**Response:**
```json
{
  "success": true,
  "output": "*** loading patterns from file ../KB/PATTERNS/stm_patterns ... done.\n",
  "error": null
}
```

### Run Procedure

```
POST /proc
```

Runs a predefined O-ETB procedure.

**Request Body:**
```json
{
  "proc_name": "stm_inst",
  "step_mode": false,
  "verbose": true,
  "timeout": 300
}
```

**Response:**
```json
{
  "success": true,
  "output": "*** instantiating pattern stm_safety ... done.\n*** instantiating pattern hazard_mitigated ... done.\n...",
  "error": null
}
```

### Instantiate Pattern

```
POST /instantiate_pattern
```

Instantiates an assurance case pattern.

**Request Body:**
```json
{
  "pattern_name": "stm_safety",
  "args": ["stm_system"],
  "case_id": "stm_system_example",
  "timeout": 300
}
```

**Response:**
```json
{
  "success": true,
  "output": "*** instantiating pattern stm_safety ... done.\n",
  "error": null
}
```

### Export Case

```
POST /export_case
```

Exports an assurance case in the specified format.

**Request Body:**
```json
{
  "case_id": "stm_system_example",
  "format": "html"
}
```

**Response:**
```json
{
  "success": true,
  "output": "Exported to CAP/stm_system_example/index.html\n",
  "error": null
}
```

## Usage Examples

### Using curl

```bash
# Health check
curl -X GET http://localhost:8000/health

# Run a command
curl -X POST http://localhost:8000/command \
  -H "Content-Type: application/json" \
  -d '{"command": "version"}'

# Run a procedure
curl -X POST http://localhost:8000/proc \
  -H "Content-Type: application/json" \
  -d '{"proc_name": "stm_inst", "verbose": true}'

# Instantiate a pattern
curl -X POST http://localhost:8000/instantiate_pattern \
  -H "Content-Type: application/json" \
  -d '{"pattern_name": "stm_safety", "args": ["stm_system"], "case_id": "stm_system_example"}'

# Export a case
curl -X POST http://localhost:8000/export_case \
  -H "Content-Type: application/json" \
  -d '{"case_id": "stm_system_example", "format": "html"}'
```

### Using Python

```python
import requests
import json

# Base URL for the API
base_url = "http://localhost:8000"

# Run a command
response = requests.post(
    f"{base_url}/command",
    json={"command": "load_patterns", "args": ["../KB/PATTERNS/stm_patterns"]}
)
print(response.json())

# Run a procedure
response = requests.post(
    f"{base_url}/proc",
    json={"proc_name": "stm_inst", "verbose": True}
)
print(response.json())

# Instantiate a pattern
response = requests.post(
    f"{base_url}/instantiate_pattern",
    json={
        "pattern_name": "stm_safety",
        "args": ["stm_system"],
        "case_id": "stm_system_example"
    }
)
print(response.json())

# Export a case
response = requests.post(
    f"{base_url}/export_case",
    json={"case_id": "stm_system_example", "format": "html"}
)
print(response.json())
```

## Error Handling

All endpoints return a standard error format:

```json
{
  "success": false,
  "output": "",
  "error": "Error message describing what went wrong"
}
```

Common errors include:
- Command not found
- Invalid arguments
- Pattern not found
- Command timeout
- Internal O-ETB errors 