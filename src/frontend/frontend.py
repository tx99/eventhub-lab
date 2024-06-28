from flask import Flask, render_template, request, redirect, url_for
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient
from azure.eventhub import EventHubProducerClient, EventHubConsumerClient, EventData
import os
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Azure Key Vault configuration
key_vault_url = os.environ.get('KEY_VAULT_URL')
credential = DefaultAzureCredential()
secret_client = SecretClient(vault_url=key_vault_url, credential=credential)

def testkv():
    try:
        # Retrieve EventHub connection string from Key Vault using workload identity
        eventhub_connection_string = secret_client.get_secret("eventhub-connection-string").value
        logger.info("Successfully retrieved EventHub connection string from Key Vault using workload identity")

        # Create an EventHub producer client using the connection string
        producer = EventHubProducerClient.from_connection_string(eventhub_connection_string)
        
        # Send a test message
        with producer:
            event_data_batch = producer.create_batch()
            event_data_batch.add(EventData('Test message from Flask app using workload identity for Key Vault access'))
            producer.send_batch(event_data_batch)
        logger.info("Successfully sent a test message to EventHub")

        # Create an EventHub consumer client using the connection string
        consumer = EventHubConsumerClient.from_connection_string(
            eventhub_connection_string,
            consumer_group="$Default",
            partition_id="0"  
        )

        # Read the message back
        with consumer:
            for event in consumer.receive(max_batch_size=1, max_wait_time=5):
                logger.info(f"Received message from EventHub: {event.body_as_str()}")
                break 

        logger.info("EventHub connection test completed successfully")
    except Exception as e:
        logger.error(f"Error in testkv function: {str(e)}")

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/books', methods=['GET'])
def get_books():
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
    return redirect(url_for('get_books'))

@app.route('/books/update/<id>', methods=['POST'])
def update_book(id):
    title = request.form['title']
    author = request.form['author']
    return redirect(url_for('get_books'))

@app.route('/books/delete/<id>', methods=['POST'])
def delete_book(id):
    return redirect(url_for('get_books'))

if __name__ == '__main__':
    # Run the testkv function before starting the Flask app
    testkv()
    app.run(debug=True, host='0.0.0.0', port=5055)