FROM ubuntu

WORKDIR /app

# Copy files from the frontend directory
COPY frontend.py /app/
COPY templates /app/templates
COPY static /app/static

RUN apt update && apt install python3 python3-pip -y
RUN pip install --no-cache-dir flask azure-identity azure-keyvault-secrets --break-system-packages

EXPOSE 5055

ENV NAME World

CMD ["python", "frontend.py"]