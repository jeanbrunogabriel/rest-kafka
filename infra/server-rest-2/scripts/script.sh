#!/bin/bash

yum update -y
cd /home/ec2-user
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCYP1pKWWTdPoS9V6bzRDmYZ2DkwjltneDQ6z9ZkkhcJ/4tqqRPqDKDI5RFPev7aW1HoxOzEjrC9uQou6TIUZ7JzFxxk7CRpkz+lHCfnDmjIJ1hyb3h1xhW11y4BBpYraCS0Cqs/1QS0wIaEkmicj+EO1T5nB0dCdCeLosnbNFniedxRRn9oi/Rjvr5kh+DVtCKrM6oOJCf85UWmlRj5N8iwEAxQx2TquaJhSKAkZUZP4EiY8/wWzLYRMwBO6UkX4AEDmjD+t50v3mWxR3UQQqJ2ofB30QUQqhV1h3c/BKT+f3/DcAkGtFAJGX3vQEzYexlkmj6XYQG+dHaNLjAM9nY0bKlByvf1mIFNyfH3rMVj938dZjdbteBGrBnMAUmXsWTyWgosOYxay2NCpHGD5ac5BnejapU0v5TQfy42KI17rsKh5eJjgjYBAXlTl0rBw0gJTxEX4UbiitRLJFotNscFND91xBGDx6Es6mRPrDm+mHsP2tR+B2lSNZ8dZnLHEk= jeanbraga@jean >> /home/ec2-user/.ssh/authorized_keys

yum install -y docker pip python3
service docker start
usermod -a -G docker ec2-user

docker run -d --name broker apache/kafka:latest
pip install flask kafka-python


mkdir database
chmod 777 database

cat <<EOF > create_db.py
import sqlite3

# Conectar ao banco de dados (ou criar um se não existir)
conn = sqlite3.connect('database/db-loja.db')

# Criar um cursor
cursor = conn.cursor()

# Criar a tabela
cursor.execute('''
CREATE TABLE produtos (
    idproduto INTEGER PRIMARY KEY AUTOINCREMENT,
    descricao TEXT NOT NULL,
    ganhopercentual REAL NOT NULL,
    datacriacao DATE NOT NULL,
    datamodificacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
''')

# Salvar (commit) as mudanças e fechar a conexão
conn.commit()
conn.close()
EOF

python3 create_db.py
chmod 777 database/db-loja.db

cat <<EOF > app.py
import sqlite3
from sqlite3 import Error
from flask import Flask, request, jsonify
from datetime import date

app = Flask(__name__)

# Helper function for database connection
def get_db_connection():
    conn = sqlite3.connect('database/db-loja.db')
    return conn

@app.route('/api-loja/produtos/', methods=['GET'])
@app.route('/api-loja/produtos/<int:idproduto>', methods=['GET'])
def pesquisar(idproduto=None):
    if request.method == 'GET':
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            if idproduto is not None:
                sql = '''SELECT * FROM produtos WHERE idproduto = ?'''
                cur.execute(sql, (idproduto,))
            else:
                sql = '''SELECT * FROM produtos'''
                cur.execute(sql)
            registros = cur.fetchall()
            if registros:
                nomes_colunas = [x[0] for x in cur.description]
                json_dados = [dict(zip(nomes_colunas, reg)) for reg in registros]
                return jsonify(json_dados)
            else:
                return jsonify({'mensagem': 'registro nao encontrado'})
        except Error as e:
            return jsonify({'mensagem': str(e)})
        finally:
            conn.close()

@app.route('/api-loja/produtos', methods=['POST'])
def inserir():
    if request.method == 'POST':
        dados = request.get_json()
        descricao = dados.get('descricao')
        ganhopercentual = dados.get('ganhopercentual')
        datacriacao = date.today()

        if descricao and ganhopercentual:
            try:
                conn = get_db_connection()
                cur = conn.cursor()
                sql = '''INSERT INTO produtos(descricao, ganhopercentual, datacriacao) VALUES(?, ?, ?)'''
                cur.execute(sql, (descricao, ganhopercentual, datacriacao))
                conn.commit()
                return jsonify({'mensagem': 'registro inserido com sucesso'})
            except Error as e:
                return jsonify({'mensagem': str(e)})
            finally:
                conn.close()
        else:
            return jsonify({'mensagem': 'campos <descricao> e <ganhopercentual> sao obrigatorios'})

@app.route('/api-loja/produtos/<int:idproduto>', methods=['DELETE'])
def excluir(idproduto):
    if request.method == 'DELETE':
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            sql = '''DELETE FROM produtos WHERE idproduto = ?'''
            cur.execute(sql, (idproduto,))
            conn.commit()
            return jsonify({'mensagem': 'registro excluido'})
        except Error as e:
            return jsonify({'mensagem': str(e)})
        finally:
            conn.close()

@app.route('/api-loja/produtos/', methods=['PUT'])
def alterar():
    if request.method == 'PUT':
        dados = request.get_json()
        descricao = dados.get('descricao')
        ganhopercentual = dados.get('ganhopercentual')
        idproduto = dados.get('idproduto')

        if descricao and ganhopercentual and idproduto:
            try:
                conn = get_db_connection()
                cur = conn.cursor()
                sql = '''UPDATE produtos SET descricao=?, ganhopercentual=? WHERE idproduto = ?'''
                cur.execute(sql, (descricao, ganhopercentual, idproduto))
                conn.commit()
                return jsonify({'mensagem': 'registro alterado com sucesso'})
            except Error as e:
                return jsonify({'mensagem': str(e)})
            finally:
                conn.close()
        else:
            return jsonify({'mensagem': 'campos <descricao>, <ganhopercentual> e <idproduto> sao obrigatorios'})

@app.errorhandler(404)
@app.errorhandler(405)
def endpoint_nao_encontrado(e):
    return jsonify({'mensagem': 'erro - endpoint nao encontrado'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

python3 app.py&


cat <<EOF > sync_kafka.py
import sqlite3
from kafka import KafkaProducer
import json
import time
from datetime import datetime, timedelta

# Configure the Kafka producer
def get_kafka_producer(kafka_server):
    return KafkaProducer(
        bootstrap_servers=kafka_server,
        key_serializer=lambda v: str(v).encode('utf-8'),
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )

# Sync script: Fetch data from SQLite and push to Kafka
def sync_data_to_kafka(db_path, kafka_server, topic_name, last_sync_time=None):
    # Open a database connection
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # If this is the first sync, sync all data; otherwise, fetch data modified since the last sync
    if last_sync_time:
        query = '''SELECT * FROM produtos WHERE datamodificacao > ?'''
        cursor.execute(query, (last_sync_time,))
    else:
        query = '''SELECT * FROM produtos'''
        cursor.execute(query)

    rows = cursor.fetchall()
    column_names = [description[0] for description in cursor.description]

    # Create a list of product data to send to Kafka
    produtos_data = [dict(zip(column_names, row)) for row in rows]

    if produtos_data:
        producer = get_kafka_producer(kafka_server)

        for record in produtos_data:
            key = str(record['idproduto'])
            producer.send(topic_name, key=key.encode('utf-8'), value=record)
            print(f"Sent to Kafka with key: {key} and value: {record}")

        producer.flush()
        producer.close()

    # Update the last sync time (use the latest modified time from the data)
    if rows:
        latest_sync_time = max(row['datamodificacao'] for row in produtos_data)
        return latest_sync_time
    return last_sync_time

# Main loop to run the sync process periodically
def run_sync(db_path, kafka_server, topic_name, sync_interval_minutes=5):
    last_sync_time = None
    while True:
        last_sync_time = sync_data_to_kafka(db_path, kafka_server, topic_name, last_sync_time)
        print(f"Sync completed at {datetime.now()}")
        time.sleep(sync_interval_minutes * 60)  # Sleep for the sync interval

if __name__ == "__main__":
    db_path = 'database/db-loja.db'
    kafka_server = '${kafka_public_ip}:9092'
    topic_name = 'produtos'
    run_sync(db_path, kafka_server, topic_name)

EOF

python3 sync_kafka.py&

cat <<EOF > sync_from_kafka.py
import sqlite3
from kafka import KafkaConsumer
import json

# Configure Kafka consumer
def get_kafka_consumer(kafka_server, topic_name):
    return KafkaConsumer(
        topic_name,
        bootstrap_servers=kafka_server,
        key_deserializer=lambda k: k.decode('utf-8'),
        value_deserializer=lambda v: json.loads(v.decode('utf-8')),
        auto_offset_reset='earliest',  # Start from the earliest message if no offset is stored
        enable_auto_commit=True
    )

# Upsert product into the database
def upsert_product(conn, product):
    cursor = conn.cursor()
    
    # Check if product exists
    cursor.execute("SELECT 1 FROM produtos WHERE idproduto = ?", (product['idproduto'],))
    exists = cursor.fetchone()
    
    if exists:
        # Update the existing product
        cursor.execute('''
            UPDATE produtos
            SET descricao = ?, ganhopercentual = ?, datamodificacao = CURRENT_TIMESTAMP
            WHERE idproduto = ?
        ''', (product['descricao'], product['ganhopercentual'], product['idproduto']))
    else:
        # Insert the new product
        cursor.execute('''
            INSERT INTO produtos (idproduto, descricao, ganhopercentual, datacriacao)
            VALUES (?, ?, ?, ?)
        ''', (product['idproduto'], product['descricao'], product['ganhopercentual'], product['datacriacao']))

    conn.commit()

def consume_and_update(kafka_server, topic_name, db_path):
    consumer = get_kafka_consumer(kafka_server, topic_name)
    conn = sqlite3.connect(db_path)

    try:
        for message in consumer:
            product = message.value  # Product data as a dictionary
            print(f"Received message: {product}")
            upsert_product(conn, product)
            print(f"Product with ID {product['idproduto']} synced to database.")
    except Exception as e:
        print(f"Error while processing Kafka messages: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    kafka_server = '${kafka_public_ip}:9092'
    topic_name = 'produtos'
    db_path = 'database/db-loja.db'
    
    consume_and_update(kafka_server, topic_name, db_path)
EOF

python3 sync_from_kafka.py&
