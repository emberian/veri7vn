"""Original fixed source metadata fixtures in existing LocalSnapshot wire v2.

No credentials, service calls or new schema. Native tests decode these exact bytes
with the actual Source_Metadata_Codec before acquisition/cell/domain execution.
"""
from pathlib import Path
import struct


def manifest(name, unit):
    out = bytearray()
    def text(value):
        raw = value.encode('utf-8')
        out.extend(struct.pack('!I', len(raw)))
        out.extend(raw)
    def optional(value):
        out.append(value is not None)
        if value is not None:
            text(value)
    def strings(values):
        out.extend(struct.pack('!I', len(values)))
        for value in values:
            text(value)
    def clock(basis, origin, ticks):
        for value in (basis, origin, str(ticks)):
            text(value)
    text('veri7vn-local-source/2')
    optional(None)  # Exact raw input is retained by the actual native association.
    text('source-quantity-' + name)
    optional('1')
    text('source-row/1')
    text('UTF-8')
    text('ordered rows')
    text('source-row-codec/1')
    optional(None)  # No project/source license grant is inferred by this fixture.
    optional('original integration fixture')
    strings(['quoted instrument report', 'not world-truth adoption'])
    optional(None)
    optional(unit)
    strings(['fixture:source-quantity'])
    strings([])
    out.append(1)
    clock('source-event', 'instrument', 50)
    clock('wall', 'UTC', 100)
    out.append(0)
    text('1')
    text('quantity-fixture/1:' + name)
    optional(None)
    text('retain-source-status')
    text('Measured')
    text('Private')
    return bytes(out)


if __name__ == '__main__':
    folder = Path(__file__).with_name('fixtures')
    for name, unit in [('centimetres', 'cm'), ('stiffness', 'N/m'), ('metres', 'm'), ('unit-missing', None), ('null', 'm')]:
        (folder / (name + '.bin')).write_bytes(manifest(name, unit))
