from flask import Flask, render_template, request, redirect, url_for
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

app = Flask(__name__)

# Azure Key Vault configuration
key_vault_url = 'PLACEHOLDER'
credential = DefaultAzureCredential()
secret_client = SecretClient(vault_url=key_vault_url, credential=credential)

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
    app.run(debug=True,host='0.0.0.0', port=5055)
