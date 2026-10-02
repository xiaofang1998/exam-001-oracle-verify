FROM ubuntu:22.04

# Dependency audit (no redundant packages):
#   - coreutils / grep / sed are Essential/required in the ubuntu:22.04 base
#     image, so installing them explicitly would be redundant and was removed.
#   - solve.sh and test.sh both degrade to pure Bash / POSIX grep when an
#     interpreter is unavailable, so no text-processing package is required.
#   - python3 is the single extra dependency: solution/oracle_convert.py, the
#     reference implementation called by solution/solve.sh, is a Python script.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create the data and output directories used by the task.
RUN mkdir -p /data /output

# Generate the Web server access log the task operates on.
RUN printf '%s\n' \
    '192.168.1.100 - - [01/Jan/2024:10:00:00 +0000] "GET /api/users HTTP/1.1" 200 1234' \
    '192.168.1.101 - - [01/Jan/2024:10:00:01 +0000] "POST /api/login HTTP/1.1" 401 56' \
    '192.168.1.100 - - [01/Jan/2024:10:00:02 +0000] "GET /api/products HTTP/1.1" 200 5678' \
    '192.168.1.102 - - [01/Jan/2024:10:00:03 +0000] "GET /api/users HTTP/1.1" 200 1234' \
    '192.168.1.100 - - [01/Jan/2024:10:00:04 +0000] "DELETE /api/users/1 HTTP/1.1" 404 100' \
    '192.168.1.101 - - [01/Jan/2024:10:00:05 +0000] "POST /api/login HTTP/1.1" 200 789' \
    '192.168.1.100 - - [01/Jan/2024:10:00:06 +0000] "GET /api/health HTTP/1.1" 200 50' \
    '192.168.1.103 - - [01/Jan/2024:10:00:07 +0000] "POST /api/crash HTTP/1.1" 500 0' \
    '192.168.1.100 - - [01/Jan/2024:10:00:08 +0000] "GET /api/users HTTP/1.1" 200 1234' \
    '192.168.1.102 - - [01/Jan/2024:10:00:09 +0000] "GET /missing HTTP/1.1" 404 0' \
    > /data/access.log

CMD ["/bin/bash"]
