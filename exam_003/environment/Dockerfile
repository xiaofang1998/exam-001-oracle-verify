FROM python:3.11-slim

RUN mkdir -p /app /logs/verifier

COPY stats.py    /app/stats.py
COPY orders.json /app/orders.json

WORKDIR /app

CMD ["/bin/bash"]
