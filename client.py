from socket import *
from time import ctime

def client():
	#127.0.0.1 port 9092
	csocket = socket()
	csocket.connect(("127.0.0.1", 9090))

client()