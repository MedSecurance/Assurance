#!/bin/bash

#First build the project - now done in the Dockerfile
#cd /Assurance/src
#make

# Start the FastAPI server 
#cd /Assurance/api
#uvicorn main:app --host 0.0.0.0 --port 8080 --reload

# Start ETB
cd /Assurance/BUILD
./etb
