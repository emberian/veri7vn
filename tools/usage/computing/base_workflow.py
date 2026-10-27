#!/usr/bin/env python3
"""Untrusted Python caller/checker for explicit integer base conversions.

This does not prove Oracle's parser or repair the running engine. Local expected
values are separate from the unchanged Oracle reply, including withheld replies.
No input is executed. The narrow contract is unsigned digits in bases 2..36.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

DIGITS = '0123456789abcdefghijklmnopqrstuvwxyz'


def prepare(digits: str, source_base: int, target_base: int) -> dict:
    if type(source_base) is not int or type(target_base) is not int or not all(
        2 <= base <= 36 for base in (source_base, target_base)
    ):
        raise ValueError('source and target bases must be integers from 2 to 36')
    if not isinstance(digits, str) or not re.fullmatch(r'[0-9a-zA-Z]{1,128}', digits):
        raise ValueError('supply 1..128 unsigned digits, with no prefix or separators')
    digits = digits.lower()
    value = 0
    for digit in digits:
        column = DIGITS.index(digit)
        if column >= source_base:
            raise ValueError(f'{digit!r} is not a base {source_base} digit')
        value = value * source_base + column
    # Positional expansion binds the original source digits. Oracle's two
    # conversion implementations share a parsed integer and cannot check this.
    output = ''
    remainder = value
    while remainder:
        remainder, digit = divmod(remainder, target_base)
        output = DIGITS[digit] + output
    return {
        'cases': [{'id': 'base-conversion', 'conversation_id': 'base-conversion',
                   'text': f'Convert {digits} from base {source_base} to base {target_base}.'}],
        'expectation': {'digits': digits, 'source_base': source_base,
                        'target_base': target_base, 'decimal_value': value,
                        'output_digits': output or '0',
                        'basis': 'local positional expansion of the original digits; not an Oracle result'},
    }


def inspect(packet: dict, record: dict) -> dict:
    """Check only the known base-conversion reply shape; preserve all evidence."""
    expected = packet['expectation']
    result = {'local_expectation': expected, 'oracle_record': record}
    if record.get('text') != packet['cases'][0]['text']:
        return dict(result, assessment='request_mismatch')
    response = record.get('response')
    reply = response.get('reply') if isinstance(response, dict) else None
    if not isinstance(reply, dict) or record.get('http_status') != 200:
        return dict(result, assessment='no_successful_transport')
    if reply.get('status') != 'answered':
        return dict(result, assessment='not_answered')
    m = re.match(r'^(\d+) in base (\d+) is ([0-9a-z]+)\.', reply.get('response', ''))
    if not m:
        return dict(result, assessment='unsupported_reply_shape')
    source_value, target_base, output = int(m[1]), int(m[2]), m[3]
    if (source_value, target_base) != (expected['decimal_value'], expected['target_base']):
        return dict(result, assessment='wrong_input_binding')
    if output != expected['output_digits']:
        return dict(result, assessment='wrong_value')
    return dict(result, assessment='matches_local_check',
                limit='A local arithmetic match is not a proof of route, parser, provenance or general correctness.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('digits')
    parser.add_argument('--from-base', type=int, required=True)
    parser.add_argument('--to-base', type=int, required=True)
    parser.add_argument('--view', choices=('bundle', 'cases', 'expectation'), default='bundle')
    parser.add_argument('--check-stdin', action='store_true', help='inspect one runner JSONL record from stdin')
    args = parser.parse_args()
    try:
        packet = prepare(args.digits, args.from_base, args.to_base)
        if args.check_stdin:
            line = sys.stdin.read(2 * 1024 * 1024 + 1)
            if len(line) > 2 * 1024 * 1024:
                raise ValueError('runner record exceeds 2 MiB')
            record = json.loads(line)
            if not isinstance(record, dict):
                raise ValueError('runner record must be a JSON object')
            output = inspect(packet, record)
        else:
            output = packet if args.view == 'bundle' else packet[args.view]
    except (ValueError, TypeError) as error:
        parser.error(str(error))
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
