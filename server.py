from socket import *
from time import ctime
from os import *

def clientHandler(conn, cliAddress):
	while True:
		print("HERE")

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