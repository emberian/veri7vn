#!/usr/bin/env python3
"""Finite actual installed source-browser transport check; steward JVM slot only."""
import argparse
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from workbench_check import run

class Form(HTMLParser):
    def __init__(self):
        super().__init__();self.token=None;self.textareas=[];self.active=None;self.forms=[];self.current=None
    def handle_starttag(self,tag,attrs):
        fields=dict(attrs)
        if tag=='form':self.current={}
        if tag=='input' and self.current is not None and fields.get('name'):self.current[fields['name']]=fields.get('value','')
        if tag=='input' and fields.get('name')=='token':self.token=fields.get('value')
        if tag=='textarea' and fields.get('name')=='replacement':self.active=[]
    def handle_data(self,data):
        if self.active is not None:self.active.append(data)
    def handle_endtag(self,tag):
        if tag=='textarea' and self.active is not None:
            text=''.join(self.active);self.textareas.append(text);self.active=None
            if self.current is not None:self.current['replacement']=text
        if tag=='form' and self.current is not None:self.forms.append(self.current);self.current=None


def address(process):
    selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
    data=b'';deadline=time.monotonic()+45
    try:
        while b'\n' not in data:
            remaining=deadline-time.monotonic()
            if remaining<=0 or not selector.select(remaining):raise TimeoutError('browser readiness deadline')
            part=os.read(process.stdout.fileno(),4096)
            if not part:raise RuntimeError('browser exited before URL')
            data+=part
            if len(data)>65536:raise RuntimeError('browser readiness bound')
        url=data.split(b'\n',1)[0].decode().strip()
        if not re.fullmatch(r'http://127\.0\.0\.1:[0-9]+/',url):raise RuntimeError('expected actual loopback URL')
        return url,data
    finally:selector.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--state',type=Path,required=True)
    parser.add_argument('--expected-file',type=Path,required=True)
    parser.add_argument('--standalone',action='store_true',help='invoke shipped bin/veri7vn instead of developer staging driver')
    parser.add_argument('--save-twice',action='store_true',help='append two Isabelle comments via actual browser saves and CLI reopen')
    parser.add_argument('--draft',default='packaged-source')
    parser.add_argument('--file',default='specialist.py')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    generation=(args.installation/'current').resolve(strict=True)
    output=args.output.resolve();output.mkdir(mode=0o700,parents=True,exist_ok=False)
    facade=output/'installation';facade.mkdir();(facade/'current').symlink_to(generation)
    launcher=Path(__file__).with_name('stage.py').resolve()
    prefix=[str(generation/'bin/veri7vn'),'launch'] if args.standalone else [sys.executable,str(launcher),'launch']
    options=['--state',str(args.state.resolve(strict=True)),'--surface','source']+([] if args.standalone else [str(facade)])
    command=prefix+options+['--','serve']
    result=dict(generation=generation.name,standalone=args.standalone,checks=[],passed=False,
        assurance='actual installed source-only browser startup, HTTP source view, clean close; no native execution or visual/recipient qualification')
    process=None;initial=b''
    try:
        with (output/'browser.stderr').open('wb') as errors:
            process=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=errors,start_new_session=True)
            url,initial=address(process)
            opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open(url,timeout=5) as response:home=response.read(2*1024*1024).decode('utf-8')
            (output/'home.html').write_text(home)
            parsed=Form();parsed.feed(home)
            if not parsed.token or 'Source-only workspace.' not in home:raise RuntimeError('missing actual source browser/token')
            result['checks'].append(dict(label='source-browser-home',passed=True))
            data=urllib.parse.urlencode(dict(token=parsed.token,action='Open',draft=args.draft,file=args.file)).encode()
            request=urllib.request.Request(url,data=data,headers={'Content-Type':'application/x-www-form-urlencoded'})
            with opener.open(request,timeout=5) as response:opened=response.read(2*1024*1024).decode('utf-8')
            (output/'opened.html').write_text(opened)
            form=Form();form.feed(opened)
            if not form.textareas or form.textareas[0].encode()!=args.expected_file.read_bytes():
                raise RuntimeError('browser source differs from committed exact bytes')
            result['checks'].append(dict(label='csrf-open-exact-source',passed=True))
            final_bytes=args.expected_file.read_bytes()
            if args.save_twice:
                for index in (1,2):
                    fields=next((dict(fields) for fields in form.forms if fields.get('action')=='Save'),None)
                    if fields is None:raise RuntimeError('missing actual source Save form')
                    previous_revision=fields.get('revision')
                    final_bytes+=('\n(* Installed workshop revision '+str(index)+'. *)\n').encode()
                    fields['replacement']=final_bytes.decode('utf-8')
                    request=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode(),
                        headers={'Content-Type':'application/x-www-form-urlencoded'})
                    with opener.open(request,timeout=5) as response:saved=response.read(2*1024*1024).decode('utf-8')
                    (output/('save-'+str(index)+'.html')).write_text(saved)
                    form=Form();form.feed(saved)
                    next_form=next((fields for fields in form.forms if fields.get('action')=='Save'),None)
                    if not next_form or next_form.get('revision')==previous_revision or not form.textareas or form.textareas[0].encode()!=final_bytes or '>Saved.</p>' not in saved:
                        raise RuntimeError('browser save did not commit exact next revision')
                    result['checks'].append(dict(label='save-'+str(index)+'-new-revision',passed=True))
            tail,_=process.communicate(input=b'\n',timeout=10)
            (output/'browser.stdout').write_bytes(initial+tail)
            if process.returncode!=0:raise RuntimeError('browser did not close cleanly')
            result['checks'].append(dict(label='normal-enter-close',returncode=process.returncode,passed=True))
            if args.save_twice:
                inspect=prefix+options+['--','source',args.draft,args.file]
                code,reopened,errors=run(inspect,output,45)
                (output/'reopened.stdout').write_bytes(reopened);(output/'reopened.stderr').write_bytes(errors)
                if code!=0 or reopened!=final_bytes:raise RuntimeError('fresh CLI reopen differs from browser second save')
                result['checks'].append(dict(label='fresh-cli-reopen-two-saves',returncode=code,passed=True))
            result['passed']=True
    except BaseException as error:
        result['error']=str(error);raise
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            try:process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL);process.communicate(timeout=5)
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('INSTALLED_SOURCE_BROWSER_OPEN_CLOSE_PASS '+str(output))

if __name__=='__main__':main()
