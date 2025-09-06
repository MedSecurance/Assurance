from fastapi import FastAPI, HTTPException, Depends, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import json
from typing import List, Dict, Any, Optional

app = FastAPI(
    title="O-ETB API",
    description="API for running O-ETB commands and interacting with the Evidential Tool Bus",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class CommandRequest(BaseModel):
    command: str
    args: Optional[List[str]] = []
    timeout: Optional[int] = 60

class ProcRequest(BaseModel):
    proc_name: str
    step_mode: Optional[bool] = False
    verbose: Optional[bool] = False
    timeout: Optional[int] = 300

class PatternRequest(BaseModel):
    pattern_name: str
    args: List[Any]
    case_id: str
    timeout: Optional[int] = 300

class CommandResponse(BaseModel):
    success: bool
    output: str
    error: Optional[str] = None

# Helper function to run O-ETB commands
def run_etb_command(cmd: str, timeout: int = 60) -> CommandResponse:
    try:
        etb_path = "./etb"
        result = subprocess.run(
            [etb_path, "-c", cmd],
            capture_output=True,
            text=True,
            cwd="/Assurance/BUILD",
            timeout=timeout
        )
        if result.returncode != 0:
            return CommandResponse(
                success=False,
                output=result.stdout,
                error=result.stderr
            )
        return CommandResponse(
            success=True,
            output=result.stdout
        )
    except subprocess.TimeoutExpired:
        return CommandResponse(
            success=False,
            output="",
            error=f"Command timed out after {timeout} seconds"
        )
    except Exception as e:
        return CommandResponse(
            success=False,
            output="",
            error=str(e)
        )

# Routes
@app.get("/")
async def root():
    return {"message": "O-ETB API is running"}

@app.post("/command", response_model=CommandResponse)
async def run_command(request: CommandRequest):
    """Run an arbitrary O-ETB command"""
    cmd = request.command
    if request.args:
        # Format args properly for the command
        args_str = ", ".join([f"'{arg}'" if isinstance(arg, str) else str(arg) for arg in request.args])
        cmd = f"{cmd}({args_str})."
    else:
        cmd = f"{cmd}."
    
    return run_etb_command(cmd, request.timeout)

@app.post("/proc", response_model=CommandResponse)
async def run_proc(request: ProcRequest):
    """Run a predefined O-ETB procedure"""
    cmd_parts = ["proc", request.proc_name]
    
    # Add options
    if request.step_mode:
        cmd_parts.append("step")
    elif request.verbose:
        cmd_parts.append("verbose")
    
    # Format the command
    cmd = "({}).".format(", ".join(cmd_parts))
    
    return run_etb_command(cmd, request.timeout)

@app.post("/instantiate_pattern", response_model=CommandResponse)
async def instantiate_pattern(request: PatternRequest):
    """Instantiate an assurance case pattern"""
    # Format args properly
    args_str = ", ".join([f"'{arg}'" if isinstance(arg, str) else str(arg) for arg in request.args])
    cmd = f"instantiate_pattern('{request.pattern_name}', [{args_str}], '{request.case_id}')."
    
    return run_etb_command(cmd, request.timeout)

@app.post("/export_case", response_model=CommandResponse)
async def export_case(case_id: str = Body(..., embed=True), format: str = Body(..., embed=True)):
    """Export an assurance case in the specified format (txt or html)"""
    cmd = f"export_case({case_id}, {format})."
    
    return run_etb_command(cmd)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        result = subprocess.run(
            ["./etb", "-c", "quit."],
            capture_output=True,
            text=True,
            cwd="/Assurance/BUILD",
            timeout=5
        )
        if result.returncode == 0:
            return {"status": "healthy", "version": result.stdout.strip()}
        return {"status": "unhealthy", "error": result.stderr}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080) 