.PHONY: up down restart status logs urls credentials samples psql

up:
	./kingo up

down:
	./kingo down

restart:
	./kingo restart

status:
	./kingo status

logs:
	./kingo logs

urls:
	./kingo urls

credentials:
	./kingo credentials

samples:
	./kingo samples

psql:
	./kingo psql

