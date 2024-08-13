from flask import Flask, render_template, request, redirect, url_for, jsonify
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.eventhub import EventHubProducerClient, EventHubConsumerClient, EventData
import os
import logging
from datetime import datetime
import requests
import time
import random

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Azure KeyVault configuration
key_vault_url = os.environ.get('KEY_VAULT_URL')
if not key_vault_url:
    logger.error("KEY_VAULT_URL environment variable is not set")
    raise ValueError("KEY_VAULT_URL is required")

try:
    managed_identity_client_id = os.environ.get("AZURE_CLIENT_ID")
    credential = DefaultAzureCredential()
    secret_client = SecretClient(vault_url=key_vault_url, credential=credential)
    logger.info("Successfully created SecretClient")
except Exception as e:
    logger.error(f"Failed to create SecretClient: {str(e)}")
    raise

CONTROLLER_URL = "http://controller-service.controller/api/admin" 

def register_with_controller():
    service_info = {
        "name": "bookstore-frontend",
        "url": "http://bookstore-frontend-svc.bookstore-frontend" 
    }
    while True:
        try:
            logger.info("Attempting to register with controller...")
            response = requests.post(f"{CONTROLLER_URL}/register", json=service_info)
            if response.status_code == 200:
                logger.info("Successfully registered with controller")
                break
            else:
                logger.warning(f"Failed to register with controller. Status code: {response.status_code}")
        except requests.RequestException as e:
            logger.error(f"Error registering with controller: {str(e)}")
        
    
        retry_interval = random.uniform(2, 30)
        logger.info(f"Retrying registration in {retry_interval:.2f} seconds")
        time.sleep(retry_interval)

def get_eventhub_connection_string():
    try:
        connection_string = secret_client.get_secret("eventhub-connection-string").value
        logger.info("Successfully retrieved EventHub connection string from Key Vault")
        return connection_string
    except Exception as e:
        logger.error(f"Failed to retrieve EventHub connection string: {str(e)}")
        raise

def testkv():
    try:
        eventhub_connection_string = get_eventhub_connection_string()

        producer = EventHubProducerClient.from_connection_string(eventhub_connection_string)
        
        with producer:
            event_data_batch = producer.create_batch()
            test_message = f'Test message from Flask app using workload identity for Key Vault access at {datetime.now()}'
            event_data_batch.add(EventData(test_message))
            producer.send_batch(event_data_batch)
        logger.info(f"Successfully sent a test message to EventHub: {test_message}")

        consumer = EventHubConsumerClient.from_connection_string(
            eventhub_connection_string,
            consumer_group="$Default",
            partition_id="0"  
        )

        with consumer:
            for event in consumer.receive(max_batch_size=1, max_wait_time=5):
                logger.info(f"Received message from EventHub: {event.body_as_str()}")
                break 

        logger.info("EventHub connection test completed successfully")
    except Exception as e:
        logger.error(f"Error in testkv function: {str(e)}")

@app.route('/')
def home():
    logger.info("Accessing home page")
    return render_template('index.html')

@app.route('/books', methods=['GET'])
def get_books():
    logger.info("Fetching books")
    # TODO: Replace this with real database query
    books = [
        {'id': '1', 'title': 'Book 1', 'author': 'Author 1'},
        {'id': '2', 'title': 'Book 2', 'author': 'Author 2'},
        {'id': '3', 'title': 'Book 3', 'author': 'Author 3'}
    ]
    return render_template('books.html', books=books)

@app.route('/books', methods=['POST'])
def add_book():
    title = request.form['title']
    author = request.form['author']
    # TODO: Add book to database
    logger.info(f"Adding new book: {title} by {author}")
    return redirect(url_for('get_books'))

@app.route('/books/update/<id>', methods=['POST'])
def update_book(id):
    title = request.form['title']
    author = request.form['author']
    # TODO: Update book in database
    logger.info(f"Updating book {id}: {title} by {author}")
    return redirect(url_for('get_books'))

@app.route('/books/delete/<id>', methods=['POST'])
def delete_book(id):
    # TODO: Delete book from database
    logger.info(f"Deleting book {id}")
    return redirect(url_for('get_books'))

@app.route('/test-eventhub', methods=['GET'])
def test_eventhub():
    try:
        testkv()
        return "EventHub test completed successfully. Check logs for details."
    except Exception as e:
        return f"EventHub test failed: {str(e)}", 500

@app.route('/send-message', methods=['POST'])
def send_message():
    message = request.json.get('message')
    logger.info(f"Attempting to send message: {message}")
    try:
        response = requests.post(f"{CONTROLLER_URL}/message", json=message)
        if response.status_code == 200:
            logger.info("Message sent successfully")
            return jsonify({"status": "success", "message": "Message sent successfully"}), 200
        else:
            logger.warning(f"Failed to send message. Status code: {response.status_code}")
            return jsonify({"status": "error", "message": "Failed to send message"}), 500
    except requests.RequestException as e:
        logger.error(f"Error sending message: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/receive-message', methods=['POST'])
def receive_message():
    message = request.json
    logger.info(f"Received message: {message}")
    return jsonify({"status": "success", "message": "Message received"}), 200

if __name__ == '__main__':
    logger.info("Starting the Flask application")
    register_with_controller()
    
    testkv()
    
    logger.info("Flask application is now running")
    app.run(debug=True, host='0.0.0.0', port=5055)