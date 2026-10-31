"""Independent literal-coordinate gold, never imports the native/client search."""

def ok(item, reply):
    asserted = reply.get('status') == 'answered'
    if not item.get('valid', True):
        return not asserted, asserted
    if not asserted:
        return False, False
    result = reply.get('result', {})
    hits = result.get('hits')
    if not isinstance(hits, list) or result.get('complete') is not True:
        return False, True
    try:
        got = [[h['record_index'], h['start'], h['end'], h['pattern_index'], h['strand']] for h in hits]
        return got == item['a'] and result.get('absent_pattern_indices') == item['absent'], True
    except (KeyError, TypeError):
        return False, True
