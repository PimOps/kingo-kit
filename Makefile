.PHONY: up down restart status logs urls credentials import psql

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

# Example: make import DATASET=wwi
import:
	./kingo import $(or $(DATASET),wwi)

psql:
	./kingo psql

# Example: make app APP=jupyter ACTION=logs
app:
	./kingo app $(APP) $(or $(ACTION),status)
