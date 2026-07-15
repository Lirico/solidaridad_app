.PHONY: install run

install:
	uv sync

run:
	uv run uvicorn main:app --host 127.0.0.1 --port 8000 --reload
