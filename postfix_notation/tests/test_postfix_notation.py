from io import StringIO

import pytest

from postfix_notation.src.main import evaluate, main


@pytest.mark.parametrize(
    "expression, result",
    [
        ("3 0 4 ~ 2 ~", 47),
        ("2 2 + 4 - 4 ~ 2 3 * +", 22),
        ("7 2 -", 5),
        ("8 2 /", 4),
        ("5", 5),
        ("4 9 ~", 5),
    ],
)
def test_evaluate(expression, result):
    assert evaluate(expression) == result


def test_evaluate_traces_stack_after_each_token():
    trace = StringIO()

    assert evaluate("2 3 +", trace=trace) == 5
    assert trace.getvalue().splitlines() == [
        "Шаг 1 (2): стек = [2]",
        "Шаг 2 (3): стек = [2, 3]",
        "Шаг 3 (+): стек = [5]",
    ]


@pytest.mark.parametrize(
    "expression, message",
    [
        ("", "пустое"),
        ("1 +", "нужны два операнда"),
        ("2 nope +", "Не удалось распознать операнд"),
        ("1 0 /", "На ноль делить нельзя"),
        ("1 2", "2 значениями в стеке"),
    ],
)
def test_evaluate_rejects_invalid_expressions(expression, message):
    with pytest.raises(ValueError, match=message):
        evaluate(expression)


def test_main_prints_trace_and_result(capsys):
    assert main(["2", "3", "+"]) == 0

    assert capsys.readouterr().out.splitlines() == [
        "Шаг 1 (2): стек = [2]",
        "Шаг 2 (3): стек = [2, 3]",
        "Шаг 3 (+): стек = [5]",
        "2 3 + = 5",
    ]
