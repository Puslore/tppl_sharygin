PYTHON = python
EXPRESSION = 3 0 4 ~ 2 ~

.PHONY: all help run test

all: help

help:
	@echo "Доступные команды:"
	@echo "  make                 Показать эту справку"
	@echo "  make run             Запустить пример по умолчанию"
	@echo "  make run EXPRESSION=\"2 3 +\"  Вычислить выражение"
	@echo "  make test            Запустить тесты"

run:
	$(PYTHON) src/main.py "$(EXPRESSION)"

test:
	$(PYTHON) -m pytest tests
