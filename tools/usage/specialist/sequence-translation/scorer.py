"""Independent literal protein/codon-coordinate gold; imports no translator."""
def ok(item,reply):
    asserted=reply.get('status')=='answered'
    if not item.get('valid',True):
        return not asserted and reply.get('reason')=='invalid_input',asserted
    if not asserted:
        return False,False
    result=reply.get('result',{})
    if result.get('complete') is not True:
        return False,True
    try:
        summaries=[]
        for feature in result['translations']:
            stop=feature['termination_stop']
            for codon in feature['codons']+([stop] if stop is not None else []):
                if any(type(codon['source'][k]) is not int for k in ('start','end')):
                    return False,True
            summaries.append({'protein':feature['protein'],
                              'codons':[[c['codon'],c['source']['start'],c['source']['end'],c['source']['strand']] for c in feature['codons']],
                              'termination':None if stop is None else [stop['codon'],stop['source']['start'],stop['source']['end'],stop['source']['strand']]})
        return summaries==item['a'],True
    except (KeyError,TypeError):
        return False,True
