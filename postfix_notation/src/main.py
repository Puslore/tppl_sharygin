"""A small, friendly postfix-notation stack machine."""

from __future__ import annotations

import argparse
import math
import sys
from typing import TextIO


Number = int | float
OPERATORS = {"+", "-", "*", "/", "~"}


def _parse_number(token: str) -> Number:
    try:
        return int(token)
    except ValueError:
        try:
            value = float(token)
        except ValueError as error:
            raise ValueError(f"Не удалось распознать операнд {token!r}.") from error
        if not math.isfinite(value):
            raise ValueError(f"Операнд {token!r} должен быть конечным числом.")
        return value


def evaluate(expression: str, *, trace: TextIO | None = None) -> Number:
    """Evaluate a whitespace-separated postfix expression."""
    tokens = expression.split()
    if not tokens:
        raise ValueError("Выражение пустое. Укажите числа и операции через пробел.")

    stack: list[Number] = []
    for step, token in enumerate(tokens, start=1):
        if token not in OPERATORS:
            stack.append(_parse_number(token))
        else:
            if len(stack) < 2:
                raise ValueError(
                    f"Для операции {token!r} нужны два операнда; "
                    f"в стеке сейчас {len(stack)}."
                )

            if token == "~":
                right = stack[-1]
                left = stack[-2]
                if left == 0 or right == 0:
                    total = sum(stack)
                    stack[:] = [total**2]
                else:
                    stack.pop()
                    stack.pop()
                    stack.append(abs(left - right))
            else:
                right = stack.pop()
                left = stack.pop()
                if token == "+":
                    result = left + right
                elif token == "-":
                    result = left - right
                elif token == "*":
                    result = left * right
                else:
                    if right == 0:
                        raise ValueError("На ноль делить нельзя :3")
                    result = left / right
                stack.append(result)

        if trace is not None:
            print(f"Шаг {step} ({token}): стек = {stack}", file=trace)

    if len(stack) != 1:
        raise ValueError(
            f"Вычисление завершилось с {len(stack)} значениями в стеке; "
            "проверьте выражение."
        )
    return stack[0]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Вычислить арифметическое выражение в постфиксной нотации."
    )
    parser.add_argument(
        "expression",
        nargs="+",
        help="операнды и операции, разделённые пробелами (например: '2 3 +')",
    )
    args = parser.parse_args(argv)
    expression = " ".join(args.expression)

    try:
        result = evaluate(expression, trace=sys.stdout)
    except ValueError as error:
        parser.error(str(error))

    print(f"{expression} = {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())