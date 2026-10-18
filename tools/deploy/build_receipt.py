"""Untrusted receipt consistency checks; hashes and markers never override cancellation."""


def managed_receipt_issues(receipt, session=None, require_completion=False):
    issues = []
    if not isinstance(receipt, dict):
        return ['managed receipt is not an object']
    if receipt.get('status') != 'passed':
        issues.append('managed status is not passed')
    if receipt.get('exit_code') != 0:
        issues.append('managed exit code is not zero')
    if session is not None and receipt.get('session') != session:
        issues.append('managed session does not match')
    remote = receipt.get('remote')
    if not isinstance(remote, dict):
        return issues + ['remote result is absent']
    if remote.get('cancelled', False) is not False:
        issues.append('remote build was cancelled or cancellation state is unknown')
    if remote.get('exit_code') != 0:
        issues.append('remote exit code is not zero')
    if 'build_completed' in remote or require_completion:
        if remote.get('build_completed') is not True or remote.get('build_exit') != 0:
            issues.append('in-service completion sentinel is absent or unsuccessful')
    if remote.get('source_digest') != receipt.get('source_digest'):
        issues.append('local and remote source digests differ')
    return issues


def deployment_receipt_issues(receipt):
    issues = []
    if receipt.get('session_build_ok') is not True:
        issues.append('deployment did not record a successful session build')
    nested = receipt.get('session_receipt', {}).get('record')
    if nested is not None:
        issues.extend(managed_receipt_issues(nested, receipt.get('session')))
    # Older receipts predate managed workers: retain them only as historical evidence,
    # without manufacturing a completion sentinel or current-source claim.
    return issues
