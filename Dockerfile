# Dockerfile for O-ETB (Open Evidential Tool Bus)
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    git \
    curl \
    python3 \
    python3-pip \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install SWI-Prolog using apt
RUN apt-add-repository ppa:swi-prolog/stable
RUN apt-get update && apt-get install -y vim swi-prolog graphviz iproute2 && rm -rf /var/lib/apt/lists/*

# Install Python dependencies for FastAPI
RUN pip3 install fastapi uvicorn pydantic python-multipart

WORKDIR /
#COPY Assurance /Assurance
COPY BUILD /Assurance/BUILD/
COPY CAP /Assurance/CAP/
COPY KB /Assurance/KB/
COPY REPOSITORY /Assurance/REPOSITORY/
COPY src /Assurance/src/
COPY files/api /Assurance/api/
COPY files/KB /Assurance/KB/
COPY entrypoint.sh /Assurance/entrypoint.sh
RUN chmod +x /Assurance/entrypoint.sh

# Install API dependencies
WORKDIR /Assurance/api
RUN pip3 install -r requirements.txt

WORKDIR /Assurance/src
RUN make

# Set the working directory back to the initial path
WORKDIR /Assurance/BUILD

# Expose port for FastAPI
EXPOSE 8080

# Set the entrypoint to a shell script that starts both the API and etb
ENTRYPOINT ["/Assurance/entrypoint.sh"]

CMD []
 
