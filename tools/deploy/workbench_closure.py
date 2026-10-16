"""Read-only producer inspection for the embedded resident workbench surface."""
import re
import zipfile

REQUIRED_CLASSES = (
    'veri7vn/cli/ResidentWorkbench.class',
    'veri7vn/workbench/Browser.class',
    'veri7vn/workbench/Authoring.class',
    'veri7vn/workbench/ResidentExecution.class',
)


def inspect(archive, receipt):
    """Only advertise this surface when its actual producer closure is present.

    Class presence establishes packaging, not successful execution or admission.
    The present Browser renders embedded HTML/CSS and uses no external assets.
    Refuse future remote/subresource references until explicitly inventoried.
    """
    snapshot = archive/'source-snapshot'
    paths = ('src/cli/ResidentWorkbench.scala', 'src/workbench/Browser.scala',
             'src/workbench/Authoring.scala', 'src/workbench/ResidentExecution.scala',
             'src/runtime/service/RuntimeMain.scala')
    present = [(snapshot/path).is_file() for path in paths]
    with zipfile.ZipFile(archive/'veri7vn-runtime.jar') as jar:
        classes = set(jar.namelist())
    if not any(present[:-1]) and not any(c in classes for c in REQUIRED_CLASSES):
        return None  # Historical public-only producer remains usable as such.
    if not all(present) or not all(c in classes for c in REQUIRED_CLASSES):
        raise ValueError('incomplete resident workbench producer closure')
    if any(path not in receipt['sources_sha256'] for path in paths):
        raise ValueError('workbench source missing from producer receipt')
    main = (snapshot/paths[-1]).read_text()
    if '"--workbench"' not in main or 'ResidentWorkbench.run' not in main:
        raise ValueError('producer main lacks shared resident workbench route')
    browser = (snapshot/'src/workbench/Browser.scala').read_text()
    # This conservative check deliberately covers literal and escaped HTML quotes.
    if re.search(r'<(?:script|link|img|iframe)\b[^>]*\b(?:src|href)\s*=|@import\b|url\s*\(', browser, re.I):
        raise ValueError('workbench subresources require an explicit offline asset inventory')
    return dict(arguments=['--workbench'], implementation='embedded-host-jar',
                assets='embedded HTML/CSS; no required remote subresources',
                qualification='producer closure inspected; installed UI/CLI trial separate')


def inspect_source(archive, receipt, jar_name="veri7vn-runtime.jar"):
    """Inspect the explicit native-free main in the same producer JAR."""
    snapshot=archive/'source-snapshot'
    source='src/cli/Workbench.scala'
    with zipfile.ZipFile(archive/jar_name) as jar:
        classes=set(jar.namelist())
    if 'veri7vn/cli/Workbench.class' not in classes:
        return None
    required=('veri7vn/workbench/Browser.class','veri7vn/workbench/Authoring.class',
              'veri7vn/runtime/host/WorkspaceStore.class','veri7vn/runtime/host/ManagedSources.class')
    if not all(name in classes for name in required):
        raise ValueError('incomplete source authoring class closure')
    if source not in receipt['sources_sha256'] or not (snapshot/source).is_file():
        raise ValueError('source main missing from producer receipt')
    return dict(launch=['{package}/runtime/bin/isabelle','java','veri7vn.cli.Workbench','{state}/workspace'],
                implementation='same-host-jar-native-free-source-authoring',
                qualification='producer closure inspected; installed import/edit/reopen trial separate')
