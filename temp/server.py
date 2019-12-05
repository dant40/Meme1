from socket import *
from time import ctime
from os import *

class clientHandler(Thread):
	def __init__(self, socket, address):
		Thread.__init__(self)
		self.sock = socket
		self.addr = address
		self.start()

    	def run(self):
        	while 1:
            		print('Got Request')
            		self.sock.send('response')

def server():
	HOST = '' '''ip address'''
	PORT = 9090
	BUFSIZE = 1024

	server_socket = socket(AF_INET, SOCK_STREAM)
	server_socket.bind(("", 9090))
	server_socket.listen(5)
	while True:
		conn, cliAddress = server_socket.accept()
		pid = fork()
		if pid == 0:			
			clientHandler(conn, cliAddress)
			break

server()