from pymongo import MongoClient
import os
from dotenv import load_dotenv

load_dotenv()

cliente = MongoClient(os.getenv("MONGO_URL"))  # Definida en el archivo .env

db = cliente['promptcontent']

coleccion = db['usuarios']


usuario = {'nombre': 'Juan', 'email': 'juan@ejemplo.com', 'edad': 25}

resultado = coleccion.insert_one(usuario)