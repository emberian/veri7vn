#!/usr/bin/env python3
"""Untrusted host client for supplied passive heat-storage trajectories.

Checks returned storage and externally integrated source energy independently.
No physical truth, rigorous global error or certified event absence is inferred.
"""
import argparse
import copy
import hashlib
import struct
import json
import math
from pathlib import Path
from hosted_reasoning import Client as Transport, ContractError, invoke_envelope

OPERATION='science.thermal_transient'


def request_identity(arguments):
    """Match thermal-canonical-binary64-v1 after Rust's typed defaults."""
    value=copy.deepcopy(arguments)
    value.setdefault('sample_times_s',[]);value.setdefault('events',[])
    network=value['network'];network.setdefault('power_tolerance_w',1e-8)
    tolerances=network.setdefault('tolerances',{})
    tolerances.setdefault('rank_relative',1e-12);tolerances.setdefault('consistency_relative',1e-10)
    for node in network['nodes']:node.setdefault('fixed_temperature_k',None)
    digest=hashlib.sha256()
    def length(size):digest.update(struct.pack('>Q',size))
    def encode(item):
        if item is None:digest.update(b'N')
        elif type(item) is bool:digest.update(b'T' if item else b'F')
        elif type(item) in (int,float):
            number=float(item)
            if not math.isfinite(number):raise ContractError('nonfinite identity number')
            digest.update(b'F64');digest.update(struct.pack('>d',number))
        elif isinstance(item,str):
            encoded=item.encode('utf-8');digest.update(b'S');length(len(encoded));digest.update(encoded)
        elif isinstance(item,list):
            digest.update(b'A');length(len(item))
            for child in item:encode(child)
        elif isinstance(item,dict):
            digest.update(b'O');length(len(item))
            for key in sorted(item):encode(key);encode(item[key])
        else:raise ContractError('unsupported identity value')
    encode(value)
    return 'sha256:'+digest.hexdigest()


def validate_reply(arguments,envelope):
    def require(condition,reason):
        if not condition: raise ContractError(reason)
    require(isinstance(envelope,dict) and envelope.get('operation_id')==OPERATION and envelope.get('outcome')=='completed','host operation failed')
    reply=envelope.get('reply',{})
    require(reply.get('operation_id')==OPERATION and reply.get('authority')=='computation_only','wrong operation authority')
    if reply.get('status')!='answered': return {'status':'withheld','reason':reply.get('reason','native_refusal')}
    result=reply.get('result',{})
    require(result.get('schema')=='oracle-science-experimental-v1' and result.get('operation')==OPERATION
        and result.get('outcome')=='completed_with_local_error_control','wrong trajectory outcome')
    order=[n['id'] for n in arguments['network']['nodes']]
    require(result.get('node_order')==order,'node order changed')
    require(result.get('identity_encoding')=='thermal-canonical-binary64-v1' and result.get('model_identity')==request_identity(arguments),'trajectory does not belong to supplied model and schedule')
    requested=sorted(set([0,arguments['duration_s']]+arguments.get('sample_times_s',[])))
    samples=result.get('samples')
    require(isinstance(samples,list) and [s.get('time_s') for s in samples]==requested,'sample coverage changed')
    for sample in samples:
        temperatures=sample.get('temperature_k')
        require(isinstance(temperatures,list) and len(temperatures)==len(order)
            and all(type(t) in (int,float) and math.isfinite(t) and t>=0 for t in temperatures),'invalid temperature')
        for node,t in zip(arguments['network']['nodes'],temperatures):
            require(node.get('fixed_temperature_k') is None or t==node['fixed_temperature_k'],'prescribed reservoir temperature changed')
    require(samples[0]['temperature_k']==arguments['initial_temperature_k'],'initial condition changed')
    segment_energy=[[] for _ in order]
    for k,load in enumerate(arguments['loads']):
        end=arguments['loads'][k+1]['start_time_s'] if k+1<len(arguments['loads']) else arguments['duration_s']
        for i,q in enumerate(load['applied_heat_w']): segment_energy[i].append(q*(end-load['start_time_s']))
    expected_applied=[math.fsum(segments) for segments in segment_energy]
    absolute_applied=[math.fsum(abs(value) for value in segments) for segments in segment_energy]
    energy=result.get('energy',{});nodes=energy.get('nodes')
    require(isinstance(nodes,list) and [n.get('id') for n in nodes]==order,'missing node energy evidence')
    total_storage=[];total_applied=[];total_boundary=[];total_outgoing=[]
    for i,node in enumerate(nodes):
        capacity=arguments['capacities_j_per_k'][i]
        storage=capacity*(samples[-1]['temperature_k'][i]-samples[0]['temperature_k'][i])
        boundary=node.get('reservoir_heat_j')
        fixed=arguments['network']['nodes'][i].get('fixed_temperature_k') is not None
        require((boundary is None)==(not fixed),'reservoir heat admission changed')
        boundary=0 if boundary is None else boundary
        values=[storage,node.get('storage_change_j'),node.get('applied_heat_j'),boundary,node.get('outgoing_link_heat_j')]
        require(all(type(x) in (int,float) and math.isfinite(x) for x in values),'nonfinite energy evidence')
        scale=max(1,abs(storage),abs(expected_applied[i]),abs(boundary),abs(node['outgoing_link_heat_j']))
        tolerance=1e-7*scale
        storage_tolerance=1e-10*max(1,abs(storage))+32*math.ulp(1.0)*capacity*max(abs(samples[-1]['temperature_k'][i]),abs(samples[0]['temperature_k'][i]))
        source_tolerance=1e-10*max(1,absolute_applied[i])
        require(abs(storage-node['storage_change_j'])<=storage_tolerance,'storage not from original temperatures')
        require(abs(expected_applied[i]-node['applied_heat_j'])<=source_tolerance,'piecewise load integral mismatch')
        require(abs(storage-node['applied_heat_j']-boundary+node['outgoing_link_heat_j'])<=tolerance,'integrated original-node balance failed')
        total_storage.append(storage);total_applied.append(node['applied_heat_j']);total_boundary.append(boundary);total_outgoing.append(node['outgoing_link_heat_j'])
    scale=max(1,sum(abs(x) for x in total_storage+total_applied+total_boundary))
    require(abs(math.fsum(total_storage)-math.fsum(total_applied)-math.fsum(total_boundary))<=1e-7*scale,'global energy mismatch')
    require(abs(math.fsum(total_outgoing))<=1e-7*scale,'internal link heat does not cancel')
    aggregates={'storage_change_j':math.fsum(total_storage),'applied_heat_j':math.fsum(total_applied),
        'reservoir_heat_j':math.fsum(total_boundary),
        'global_balance_residual_j':math.fsum(total_storage)-math.fsum(total_applied)-math.fsum(total_boundary),
        'internal_link_cancellation_j':math.fsum(total_outgoing)}
    for name,want in aggregates.items():
        got=energy.get(name)
        own_scale={'storage_change_j':math.fsum(abs(value) for value in total_storage),
            'applied_heat_j':math.fsum(abs(value) for value in total_applied),
            'reservoir_heat_j':math.fsum(abs(value) for value in total_boundary)}.get(name,scale)
        require(type(got) in (int,float) and math.isfinite(got) and abs(got-want)<=1e-7*max(1,own_scale),
            'aggregate energy does not match original node totals: '+name)
    diagnostics=result.get('diagnostics',{})
    require(type(diagnostics.get('attempted_steps')) is int and diagnostics['attempted_steps']<=arguments['integration']['max_steps'],'step budget changed')
    require(type(diagnostics.get('maximum_accepted_local_error_ratio')) in (int,float)
        and 0<=diagnostics['maximum_accepted_local_error_ratio']<=1,'unaccepted local error estimate')
    events=result.get('events')
    require(isinstance(events,list) and len(events)<=256,'invalid event hits')
    event_map={e['id']:e for e in arguments.get('events',[])}
    for hit in events:
        event=event_map.get(hit.get('id'))
        require(event is not None and event['node_id']==hit.get('node_id'),'unexpected event')
        bracket=hit.get('bracket_s');estimate=hit.get('linear_estimate_s');endpoints=hit.get('endpoint_temperature_k')
        require(isinstance(bracket,list) and len(bracket)==2 and all(type(x) in (int,float) and math.isfinite(x) for x in bracket)
            and type(estimate) in (int,float) and math.isfinite(estimate) and 0<=bracket[0]<=estimate<=bracket[1]<=arguments['duration_s'],'invalid numerical event bracket')
        require(isinstance(endpoints,list) and len(endpoints)==2 and all(type(x) in (int,float) and math.isfinite(x) for x in endpoints),'invalid event endpoints')
        rising=endpoints[0]<event['temperature_k']<=endpoints[1]
        falling=endpoints[0]>event['temperature_k']>=endpoints[1]
        require((rising and hit.get('direction')=='rising' and event['direction'] in ('rising','either'))
            or (falling and hit.get('direction')=='falling' and event['direction'] in ('falling','either')),'event endpoint crossing mismatch')
        interpolant=bracket[0]+(bracket[1]-bracket[0])*(event['temperature_k']-endpoints[0])/(endpoints[1]-endpoints[0])
        require(abs(estimate-interpolant)<=1e-12*max(1,abs(interpolant)), 'event estimate is not its endpoint linear interpolant')
    return {'status':'answered','model_identity':result['model_identity'],'node_order':order,'samples':samples,
        'events':events,'energy':energy,'diagnostics':diagnostics,
        'scope':'supplied passive storage; estimated local integration error; sampled crossings only'}


class Client(Transport):
    def discover(self):
        descriptor=self.transport('/operations/'+OPERATION)
        if descriptor.get('id')!=OPERATION or descriptor.get('availability')!='live_direct':raise ContractError('transient operation unavailable')
    def invoke(self,arguments):
        envelope=self.transport('/invoke',invoke_envelope(OPERATION,arguments,'thermal-transient'))
        return validate_reply(arguments,envelope)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',required=True);parser.add_argument('--tenant',default='thermal-transient-demo')
    parser.add_argument('--input',type=Path,default=Path(__file__).resolve().parents[2]/'native/oracle-science/examples/thermal-transient-heater.json')
    args=parser.parse_args();data=json.loads(args.input.read_text());arguments=data.get('arguments',data)
    client=Client(args.url,args.tenant);client.discover();print(json.dumps(client.invoke(arguments),indent=2,allow_nan=False))
if __name__=='__main__':main()
