#!/usr/bin/env python3
"""Untrusted finance-request compiler, not financial advice or a verified kernel.

Turns explicit quantity roles into an arithmetic prompt for Oracle7. Local rational
results are labeled expectations and never substituted for an Oracle response.
No natural-language interpretation, default tax treatment or interest model.
"""
import argparse
import json
import re
from fractions import Fraction
from pathlib import Path

NUMBER = re.compile(r"(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\Z")
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")


class Quantity:
    def __init__(self, expression, value):
        self.expression, self.value = expression, value

    def combine(self, op, other):
        a, b = self.value, other.value
        value = {'+': lambda: a+b, '-': lambda: a-b, '*': lambda: a*b,
                 '/': lambda: a/b, '^': lambda: a**int(b)}[op]()
        return Quantity(f'({self.expression}{op}{other.expression})', value)

    def __add__(self, other): return self.combine('+', other)
    def __sub__(self, other): return self.combine('-', other)
    def __mul__(self, other): return self.combine('*', other)
    def __truediv__(self, other): return self.combine('/', other)
    def __pow__(self, other): return self.combine('^', other)


def number(value):
    if not isinstance(value, str) or len(value) > 32 or not NUMBER.fullmatch(value):
        raise ValueError('quantities must be nonnegative decimal strings, at most 32 characters')
    return Quantity(value, Fraction(value))


ONE, HUNDRED, TWELVE = number('1'), number('100'), number('12')
FIELDS = {
    'budget': {'net_income', 'expenses'},
    'invoice': {'lines'},
    'discount': {'pretax_price', 'discount_percent', 'tax_percent'},
    'tax': {'amount', 'tax_percent', 'amount_role'},
    'simple_interest': {'principal', 'annual_rate_percent', 'duration', 'time_unit', 'target'},
    'compound_annual': {'principal', 'annual_rate_percent', 'whole_years', 'target'},
    'margin': {'sale_price', 'cost'},
    'markup': {'sale_price', 'cost'},
    'breakeven': {'fixed_cost', 'sale_price_per_unit', 'variable_cost_per_unit'},
}


def compile_task(task):
    kind = task.get('kind')
    if kind not in FIELDS or set(task) != FIELDS[kind] | {'id', 'kind'}:
        raise ValueError('unknown operation, missing quantity role, or unexpected field')
    if not isinstance(task['id'], str) or not IDENTIFIER.fullmatch(task['id']):
        raise ValueError('invalid id')
    n = lambda key: number(task[key])
    unit = 'currency units (no rounding applied)'
    if kind == 'budget':
        if not isinstance(task['expenses'], list) or not 1 <= len(task['expenses']) <= 50:
            raise ValueError('expenses must contain 1..50 amounts')
        result = n('net_income')
        for item in task['expenses']:
            result = result - number(item)
    elif kind == 'invoice':
        if not isinstance(task['lines'], list) or not 1 <= len(task['lines']) <= 50:
            raise ValueError('invoice must contain 1..50 lines')
        result = None
        for line in task['lines']:
            if not isinstance(line, dict) or set(line) != {'quantity', 'unit_price'}:
                raise ValueError('invoice line needs quantity and unit_price')
            subtotal = number(line['quantity']) * number(line['unit_price'])
            result = subtotal if result is None else result + subtotal
    elif kind == 'discount':
        discount = n('discount_percent')
        if discount.value > 100:
            raise ValueError('discount exceeds 100 percent')
        result = n('pretax_price')*(ONE-discount/HUNDRED)*(ONE+n('tax_percent')/HUNDRED)
    elif kind == 'tax':
        if task['amount_role'] not in ('pretax', 'tax_inclusive'):
            raise ValueError('amount_role must be pretax or tax_inclusive')
        factor = ONE+n('tax_percent')/HUNDRED
        result = n('amount')*factor if task['amount_role'] == 'pretax' else n('amount')/factor
    elif kind in ('simple_interest', 'compound_annual'):
        if task['target'] not in ('interest', 'balance'):
            raise ValueError('target must be interest or balance')
        principal, rate = n('principal'), n('annual_rate_percent')/HUNDRED
        if kind == 'simple_interest':
            if task['time_unit'] not in ('years', 'months'):
                raise ValueError('time_unit must be years or months')
            years = n('duration')
            if task['time_unit'] == 'months':
                years = years/TWELVE
            interest = principal*rate*years
            result = interest if task['target'] == 'interest' else principal+interest
        else:
            years = n('whole_years')
            if years.value.denominator != 1 or years.value > 100:
                raise ValueError('annual compounding supports 0..100 whole years')
            balance = principal*((ONE+rate)**years)
            result = balance if task['target'] == 'balance' else balance-principal
    elif kind in ('margin', 'markup'):
        price, cost = n('sale_price'), n('cost')
        base = price if kind == 'margin' else cost
        if base.value == 0:
            raise ValueError('percentage denominator is zero')
        result = (price-cost)/base*HUNDRED
        unit = 'percent of sale price' if kind == 'margin' else 'percent of cost'
    else:
        fixed = n('fixed_cost')
        contribution = n('sale_price_per_unit')-n('variable_cost_per_unit')
        if fixed.value == 0 or contribution.value <= 0:
            raise ValueError('break-even workflow requires positive fixed cost and positive contribution; examine zero/negative cases explicitly')
        result = fixed/contribution
        unit = 'units at exact break-even (not rounded to a whole-unit sales target)'
    return {
        'case': {'id': task['id'], 'conversation_id': task['id'],
                 'text': 'Calculate '+result.expression+'.'},
        'contract': {'id': task['id'], 'input_roles': task, 'expression': result.expression,
                     'local_expected_rational': str(result.value), 'output_unit': unit,
                     'authority': 'untrusted caller-side model; not an Oracle answer',
                     'assumptions': 'Hypothetical arithmetic only. One currency throughout; no fees, deposits, withdrawals, extra costs or tax rules beyond supplied roles. No intermediate rounding. Annual compounding only when expressly selected.'},
    }


def prepare(tasks, out):
    if not isinstance(tasks, list) or not 1 <= len(tasks) <= 30:
        raise ValueError('supply 1..30 tasks')
    compiled = [compile_task(task) for task in tasks]
    ids = [row['case']['id'] for row in compiled]
    if len(set(ids)) != len(ids):
        raise ValueError('task ids must be unique')
    out.mkdir(parents=True, exist_ok=False)
    for name, key in [('cases.json', 'case'), ('contracts.json', 'contract')]:
        (out/name).write_text(json.dumps([row[key] for row in compiled], indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tasks', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    prepare(json.loads(args.tasks.read_text()), args.out)


if __name__ == '__main__':
    main()
