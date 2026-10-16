#!/usr/bin/env python3
"""Derive exact finite authority metadata codecs from the canonical HOL declarations.

This generator handles only this explicitly finite record/datatype signature. It is
not a native HOL term/value serializer. Generated roundtrip theorems must compile;
source hashes or Python success never establish native codec laws.
"""
from pathlib import Path
import re
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'Veri7vn_Authority.thy'
TARGET = HERE / 'Authority_Codec.thy'


PRIMITIVE_LAYOUT = {'nat':'WireNat', 'bool':[0,1], 'option':[0,1], 'list':2, 'seal':3,
                    'int':[4,'sign:0-positive-or-zero;1-negative-no-zero','magnitude:nat'],
                    'pair':5,'char':'WireNat<256','string':'list(char)'}
PRIMITIVES = r'''
definition encode_int :: "int \<Rightarrow> authority_wire" where
  "encode_int z = WireNode 4 [WireNat (if z < 0 then 1 else 0), WireNat (nat (abs z))]"
definition decode_int :: "authority_wire \<Rightarrow> int option" where
  "decode_int w = (case w of WireNode tag [WireNat sign, WireNat magnitude] \<Rightarrow>
    if tag = 4 then (if sign = 0 then Some (int magnitude) else if sign = 1 \<and> magnitude > 0
    then Some (- int magnitude) else None) else None | _ \<Rightarrow> None)"
lemma decode_encode_int [simp]: "decode_int (encode_int z) = Some z"
  by (cases "z < 0"; simp add: encode_int_def decode_int_def)

definition encode_char :: "char \<Rightarrow> authority_wire" where
  "encode_char c = WireNat (of_char c)"
definition decode_char :: "authority_wire \<Rightarrow> char option" where
  "decode_char w = (case w of WireNat n \<Rightarrow> if n < 256 then Some (char_of n) else None | _ \<Rightarrow> None)"
lemma decode_encode_char [simp]: "decode_char (encode_char c) = Some c"
  by (simp add: encode_char_def decode_char_def)
definition encode_string :: "string \<Rightarrow> authority_wire" where
  "encode_string s = encode_list encode_char s"
definition decode_string :: "authority_wire \<Rightarrow> string option" where
  "decode_string w = decode_list decode_char w"
lemma decode_encode_string [simp]: "decode_string (encode_string s) = Some s"
  by (simp add: encode_string_def decode_string_def)

definition encode_pair :: "('a \<Rightarrow> authority_wire) \<Rightarrow> ('b \<Rightarrow> authority_wire) \<Rightarrow> 'a \<times> 'b \<Rightarrow> authority_wire" where
  "encode_pair f g p = WireNode 5 [f (fst p), g (snd p)]"
definition decode_pair :: "(authority_wire \<Rightarrow> 'a option) \<Rightarrow> (authority_wire \<Rightarrow> 'b option) \<Rightarrow> authority_wire \<Rightarrow> ('a \<times> 'b) option" where
  "decode_pair f g w = (case w of WireNode tag [a,b] \<Rightarrow>
    if tag = 5 then (case (f a,g b) of (Some x,Some y) \<Rightarrow> Some (x,y) | _ \<Rightarrow> None)
    else None | _ \<Rightarrow> None)"
lemma decode_encode_pair [simp]:
  "(\<And>x. f (f' x) = Some x) \<Longrightarrow> (\<And>y. g (g' y) = Some y) \<Longrightarrow>
    decode_pair f g (encode_pair f' g' p) = Some p"
  by (cases p; simp add: encode_pair_def decode_pair_def)

'''

GENERIC_TYPES = set()
DECLARATION_ORIGINS = {}

def clean_type(typ):
    typ = typ.strip()
    while typ.startswith('(') and typ.endswith(')'):
        depth = 0
        encloses = True
        for i, char in enumerate(typ):
            depth += (char == '(') - (char == ')')
            if depth == 0 and i != len(typ)-1:
                encloses = False
                break
        if not encloses:
            break
        typ = typ[1:-1].strip()
    return typ

def split_product(typ):
    depth = 0
    token = r"\<times>"
    for i, char in enumerate(typ):
        depth += (char == '(') - (char == ')')
        if depth == 0 and typ.startswith(token, i):
            return typ[:i].strip(), typ[i+len(token):].strip()
    return None

def codec(typ, operation):
    typ = clean_type(typ)
    if typ.endswith(' list'):
        return f'({operation}_list {codec(typ[:-5], operation)})'
    if typ.endswith(' option'):
        return f'({operation}_option {codec(typ[:-7], operation)})'
    product = split_product(typ)
    if product:
        return f'({operation}_pair {codec(product[0], operation)} {codec(product[1], operation)})'
    if typ == "'a":
        return operation + '_item'
    for generic in GENERIC_TYPES:
        if typ.endswith(' ' + generic):
            return f'({operation}_{generic} {codec(typ[:-len(generic)-1], operation)})'
    return f'{operation}_{typ}'

def type_atoms(typ):
    typ = clean_type(typ)
    if typ.endswith(' list'):
        return type_atoms(typ[:-5])
    if typ.endswith(' option'):
        return type_atoms(typ[:-7])
    product = split_product(typ)
    if product:
        return type_atoms(product[0]) | type_atoms(product[1])
    for generic in GENERIC_TYPES:
        if typ.endswith(' ' + generic):
            return {generic} | type_atoms(typ[:-len(generic)-1])
    return {typ}


def checked_fields(wires, types, result):
    text = f'Some ({result})'
    for i, (wire, typ) in reversed(list(enumerate(zip(wires, types)))):
        text = (f'(case {codec(typ, "decode")} {wire} of None \\<Rightarrow> None | '
                f'Some v{i} \\<Rightarrow> {text})')
    return text


def decode_branch(types, result):
    wires = [f'w{i}' for i in range(len(types))]
    fields = '[' + ', '.join(wires) + ']'
    return (f'(case fs of {fields} \\<Rightarrow> '
            f'{checked_fields(wires, types, result)} | _ \\<Rightarrow> None)') if types else (
            f'(if fs = [] then Some ({result}) else None)')


def main():
    sources = [(HERE.parent.parent / 'sources/semantics/Source_Semantics.thy', {'clock_basis', 'clock_reading'}),
               (HERE.parent.parent / 'effects/Veri7vn_Effects.thy', None),
               (HERE.parent / 'metadata/Authority_Metadata.thy', None),
               (HERE.parent / 'events/Authority_Events.thy', None), (SOURCE, None)]
    decls = []
    for path, selected in sources:
        source = path.read_text()
        starts = list(re.finditer(r"^(record|datatype)\s+(?:\(plugins[^\n]*\)\s+)?(?:(\'\w+)\s+)?(\"?\w+\"?)\s*=\s*", source, re.M))
        for m in starts:
            kind, parameter, raw_name = m.groups()
            name = raw_name.strip('"')
            if selected is not None and name not in selected:
                continue
            rest = source[m.end():]
            end = re.search(r'\n(?=\S)', rest)
            body = rest[:end.start()] if end else rest
            if kind == 'record':
                members = [(x[1].strip('"'), x[2] or x[3]) for x in re.finditer(
                    r'^\s*(\"?\w+\"?)\s*::\s*(?:"([^"]+)"|(\w+))', body, re.M)]
                if not members:
                    raise ValueError(f'No fields parsed for {name}')
            else:
                if parameter:
                    raise ValueError('Only finite parameterized metadata records supported')
                members = []
                for raw in body.strip().split('|'):
                    tokens = re.findall(r'"[^"]*"|\w+', raw)
                    if not tokens:
                        raise ValueError((name, raw))
                    members.append((tokens[0], [x.strip('"') for x in tokens[1:]]))
            decls.append((kind, name, parameter, members))
            DECLARATION_ORIGINS[name] = path.stem
            if parameter:
                GENERIC_TYPES.add(name)
    out = [r'''theory Authority_Codec
  imports Veri7vn_Authority.Veri7vn_Authority
begin

text \<open>Generated by generate.py from the finite authority metadata declarations.
Schema veri7vn.authority-metadata/1. This tree carries metadata only, never arbitrary
native HOL values, cterms, thms or execution closures. Decoding does not authorize
privileged event origins. Byte/depth/node/numeral limits precede allocation in the
native/host framing layer and are distinct from these exact HOL roundtrip laws.\<close>

datatype authority_wire = WireNat nat | WireNode nat "authority_wire list"

definition encode_nat :: "nat \<Rightarrow> authority_wire" where
  "encode_nat n = WireNat n"
fun decode_nat :: "authority_wire \<Rightarrow> nat option" where
  "decode_nat (WireNat n) = Some n" |
  "decode_nat (WireNode t fs) = None"
definition encode_bool :: "bool \<Rightarrow> authority_wire" where
  "encode_bool b = WireNat (if b then 1 else 0)"
fun decode_bool :: "authority_wire \<Rightarrow> bool option" where
  "decode_bool (WireNat n) = (if n = 0 then Some False else if n = 1 then Some True else None)" |
  "decode_bool (WireNode t fs) = None"
fun decode_sequence :: "('a \<Rightarrow> 'b option) \<Rightarrow> 'a list \<Rightarrow> 'b list option" where
  "decode_sequence f [] = Some []" |
  "decode_sequence f (x # xs) = (case (f x, decode_sequence f xs) of
    (Some y, Some ys) \<Rightarrow> Some (y # ys) | _ \<Rightarrow> None)"
definition encode_list :: "('a \<Rightarrow> authority_wire) \<Rightarrow> 'a list \<Rightarrow> authority_wire" where
  "encode_list f xs = WireNode 2 (map f xs)"
fun decode_list :: "(authority_wire \<Rightarrow> 'a option) \<Rightarrow> authority_wire \<Rightarrow> 'a list option" where
  "decode_list f (WireNat n) = None" |
  "decode_list f (WireNode t fs) = (if t = 2 then decode_sequence f fs else None)"
fun encode_option :: "('a \<Rightarrow> authority_wire) \<Rightarrow> 'a option \<Rightarrow> authority_wire" where
  "encode_option f None = WireNode 0 []" |
  "encode_option f (Some x) = WireNode 1 [f x]"
fun decode_option :: "(authority_wire \<Rightarrow> 'a option) \<Rightarrow> authority_wire \<Rightarrow> 'a option option" where
  "decode_option f (WireNat n) = None" |
  "decode_option f (WireNode t fs) = (if t = 0 then
    (if fs = [] then Some None else None) else if t = 1 then
    (case fs of [x] \<Rightarrow> map_option Some (f x) | _ \<Rightarrow> None) else None)"

lemma decode_encode_nat [simp]: "decode_nat (encode_nat x) = Some x"
  by (simp add: encode_nat_def)
lemma decode_encode_bool [simp]: "decode_bool (encode_bool x) = Some x"
  by (cases x; simp add: encode_bool_def)
lemma decode_sequence_map:
  "(\<And>x. f (g x) = Some x) \<Longrightarrow> decode_sequence f (map g xs) = Some xs"
  by (induction xs) simp_all
lemma decode_encode_list [simp]:
  "(\<And>x. f (g x) = Some x) \<Longrightarrow> decode_list f (encode_list g xs) = Some xs"
  by (simp add: encode_list_def decode_sequence_map)
lemma decode_encode_option [simp]:
  "(\<And>x. f (g x) = Some x) \<Longrightarrow> decode_option f (encode_option g x) = Some x"
  by (cases x; simp)

''']
    out.append(PRIMITIVES)
    record_tag, constructor_tag = 1000, 100
    manifest = ['# Finite authority metadata schema 1', '',
                'WireNat encodes natural fields; Boolean fields require 0 or 1.',
                'WireNode 0 [] = None; WireNode 1 [x] = Some x; WireNode 2 xs = list.',
                'WireNode 4 [WireNat sign, WireNat magnitude] = exact integer; sign 1 requires positive magnitude.',
                'WireNode 5 [a,b] = pair. Characters require WireNat below 256; strings are byte-character lists.',
                'Generic metadata containers instantiate the actual binding type; no native carrier polymorphism.',
                'All record/constructor nodes require the exact ordered field arity.', '',
                '| Type | Tag | Constructor / ordered fields |', '|---|---:|---|']
    known_types = {'nat', 'bool', 'int', 'char', 'string', "'a"}
    for kind, name, parameter, members in decls:
        poly = bool(parameter)
        full_type = "'a " + name if poly else name
        enc_arg = ' encode_item' if poly else ''
        dec_arg = ' decode_item' if poly else ''
        enc_type = "('a \\<Rightarrow> authority_wire) \\<Rightarrow> " if poly else ''
        dec_type = "(authority_wire \\<Rightarrow> 'a option) \\<Rightarrow> " if poly else ''
        premise = "(\\<And>v. decode_item (encode_item v) = Some v) \\<Longrightarrow> " if poly else ''
        if kind == 'record':
            tag = record_tag
            record_tag += 1
            names = [x[0] for x in members]
            types = [x[1] for x in members]
            encoded = ', '.join(f'{codec(t,"encode")} ({f} x)' for f,t in members)
            result = '\\<lparr>' + ', '.join(f'{f} = v{i}' for i,f in enumerate(names)) + '\\<rparr>'
            out.append(f'definition encode_{name} :: "{enc_type}{full_type} \\<Rightarrow> authority_wire" where\n'
                       f'  "encode_{name}{enc_arg} x = WireNode {tag} [{encoded}]"\n')
            body = f'(if t = {tag} then {decode_branch(types,result)} else None)'
            proof = f'by (cases x; simp add: encode_{name}_def decode_{name}_def)' if not poly else f'by (cases x; simp add: encode_{name}_def decode_{name}_def)'
            manifest.append(f'| {name} | {tag} | ' + ', '.join(f'{f}: {t}' for f,t in members) + ' |')
        else:
            equations, branches = [], []
            for constructor, types in members:
                tag = constructor_tag
                constructor_tag += 1
                args = [f'a{i}' for i in range(len(types))]
                pattern = constructor + (' ' + ' '.join(args) if args else '')
                encoded = ', '.join(f'{codec(t,"encode")} {a}' for t,a in zip(types,args))
                equations.append(f'  "encode_{name} ({pattern}) = WireNode {tag} [{encoded}]"')
                result = constructor + (' ' + ' '.join(f'v{i}' for i in range(len(types))) if types else '')
                branches.append((tag,decode_branch(types,result)))
                manifest.append(f'| {name} | {tag} | {constructor}' + (' ('+', '.join(types)+')' if types else '') + ' |')
            out.append(f'primrec encode_{name} :: "{name} \\<Rightarrow> authority_wire" where\n'+' |\n'.join(equations)+'\n')
            body = 'None'
            for tag,branch in reversed(branches):
                body = f'(if t = {tag} then {branch} else {body})'
            proof = f'by (cases x; simp add: decode_{name}_def)'
        for typ in (t for _,ts in members for t in (ts if kind=='datatype' else [ts])):
            if type_atoms(typ) - known_types:
                raise ValueError(f'{name} uses unknown/not-yet-defined type {typ}')
        out.append(f'definition decode_{name} :: "{dec_type}authority_wire \\<Rightarrow> {full_type} option" where\n'
                   f'  "decode_{name}{dec_arg} w = (case w of WireNat n \\<Rightarrow> None | WireNode t fs \\<Rightarrow> {body})"\n'
                   f'lemma decode_encode_{name} [simp]: "{premise}decode_{name}{dec_arg} (encode_{name}{enc_arg} x) = Some x"\n'
                   f'  {proof}\n')
        if kind == 'record':
            out.append(f'lemma malformed_{name}_atom [simp]: "decode_{name}{dec_arg} (WireNat n) = None"\n'
                       f'  by (simp add: decode_{name}_def)\n'
                       f'lemma malformed_{name}_empty [simp]: "decode_{name}{dec_arg} (WireNode t []) = None"\n'
                       f'  by (simp add: decode_{name}_def)\n')
        known_types.add(name)
    fingerprint = int(hashlib.sha256(json.dumps({'format': 'veri7vn.authority-metadata/1', 'primitives': PRIMITIVE_LAYOUT, 'declarations': decls, 'declaration_origins': DECLARATION_ORIGINS}, separators=(",", ":")).encode()).hexdigest(), 16)
    out.append(f'definition metadata_schema_identity :: "nat" where\n  "metadata_schema_identity = {fingerprint}"\n')
    out.append(r'''definition seal_metadata :: "authority_wire \<Rightarrow> authority_wire" where
  "seal_metadata w = WireNode 3 [WireNat metadata_schema_identity, w]"
definition open_metadata :: "authority_wire \<Rightarrow> authority_wire option" where
  "open_metadata w = (case w of WireNode t [WireNat ident, body] \<Rightarrow>
    if t = 3 \<and> ident = metadata_schema_identity then Some body else None | _ \<Rightarrow> None)"
lemma open_seal_metadata [simp]: "open_metadata (seal_metadata w) = Some w"
  by (simp add: seal_metadata_def open_metadata_def)
definition encode_checkpoint :: "authority_state \<Rightarrow> authority_wire" where
  "encode_checkpoint s = seal_metadata (encode_authority_state s)"
definition decode_checkpoint :: "authority_wire \<Rightarrow> authority_state option" where
  "decode_checkpoint w = (case open_metadata w of None \<Rightarrow> None | Some body \<Rightarrow> decode_authority_state body)"
definition encode_event_frame :: "event \<Rightarrow> authority_wire" where
  "encode_event_frame e = seal_metadata (encode_event e)"
definition decode_event_frame :: "authority_wire \<Rightarrow> event option" where
  "decode_event_frame w = (case open_metadata w of None \<Rightarrow> None | Some body \<Rightarrow> decode_event body)"
lemma checkpoint_roundtrip [simp]: "decode_checkpoint (encode_checkpoint s) = Some s"
  by (simp add: encode_checkpoint_def decode_checkpoint_def)
lemma event_frame_roundtrip [simp]: "decode_event_frame (encode_event_frame e) = Some e"
  by (simp add: encode_event_frame_def decode_event_frame_def)
''')
    manifest.insert(2, f'Exact parsed-signature fingerprint (SHA-256): {fingerprint:064x}. WireNode 3 [WireNat fingerprint, body] seals transport frames/checkpoints. This locates a schema, never native evidence.')
    out.append('export_code metadata_schema_identity encode_checkpoint decode_checkpoint encode_event_frame decode_event_frame\n'
               '  encode_authority_state decode_authority_state encode_event decode_event\n'
               '  encode_command decode_command in SML module_name Veri7vn_Authority_Codec\n'
               '  file_prefix "authority_codec"\n\nend\n')
    generated = '\n'.join(out)
    schema = '\n'.join(manifest)+'\n'
    if '--check' in sys.argv:
        if TARGET.read_text() != generated or (HERE/'SCHEMA.md').read_text() != schema:
            raise SystemExit('Generated authority metadata codecs/schema are stale')
    else:
        TARGET.write_text(generated)
        (HERE/'SCHEMA.md').write_text(schema)
    print(f'Generated {TARGET.name}: {len(decls)} finite metadata types')

if __name__ == '__main__':
    main()
