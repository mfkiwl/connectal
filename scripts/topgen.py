#!/usr/bin/python
## Copyright (c) 2013-2014 Quanta Research Cambridge, Inc.

## Permission is hereby granted, free of charge, to any person
## obtaining a copy of this software and associated documentation
## files (the "Software"), to deal in the Software without
## restriction, including without limitation the rights to use, copy,
## modify, merge, publish, distribute, sublicense, and/or sell copies
## of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:

## The above copyright notice and this permission notice shall be
## included in all copies or substantial portions of the Software.

## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
## MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
## NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
## BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
## ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
## CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.

import os, sys, shutil, string
import argparse
import util

argparser = argparse.ArgumentParser("Generate Top.bsv for an project.")
argparser.add_argument('--project-dir', help='project directory')
argparser.add_argument('-v', '--verbose', help='Display verbose information messages', action='store_true')
argparser.add_argument('-l', '--leds', help='module that exports led interface')
argparser.add_argument('-w', '--wrapper', help='exported wrapper interfaces', action='append')
argparser.add_argument('-p', '--proxy', help='exported proxy interfaces', action='append')
argparser.add_argument('-m', '--mem', help='exported memory interfaces', action='append')

noisyFlag=True

topTemplate='''
import Vector::*;
import Portal::*;
import CtrlMux::*;
import HostInterface::*;
%(generatedImport)s

typedef enum {%(enumList)s} IfcNames deriving (Eq,Bits);

module mkConnectalTop
`ifdef IMPORT_HOSTIF
       #(HostType host)
`endif
       (%(moduleParam)s);
%(portalInstantiate)s

   Vector#(%(portalCount)s,StdPortal) portals;
%(portalList)s
   let ctrl_mux <- mkSlaveMux(portals);
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = %(portalMaster)s;
   interface Empty pins;
   endinterface
%(portalLeds)s
endmodule : mkConnectalTop
'''

def addPortal(name):
    global portalCount
    portalList.append('   portals[%(count)s] = %(name)s.portalIfc;' % {'count': portalCount, 'name': name})
    portalCount = portalCount + 1

def instMod(args, modname, modext, constructor):
    pmap['modname'] = modname + modext
    tstr = 'S2H'
    if modext:
        if modext == 'Proxy':
            tstr = 'H2S'
        args = modname + tstr
        if modext != 'Proxy':
            args += ', l%(userIf)s'
        enumList.append(modname + tstr)
        addPortal('l%(modname)s' % pmap)
    if not constructor:
        constructor = 'mk' + pmap['modname']
    pmap['constructor'] = constructor
    portalInstantiate.append(('   %(modname)s%(tparam)s l%(modname)s <- %(constructor)s(' + args + ');') % pmap)
    instantiatedModules.append(pmap['modname'])
    importfiles.append(modname)

if __name__=='__main__':
    options = argparser.parse_args()

    if options.verbose:
        noisyFlag = True
    if not options.project_dir:
        print "topgen: --project-dir option missing"
        sys.exit(1)
    project_dir = os.path.abspath(os.path.expanduser(options.project_dir))
    topFilename = project_dir + '/Top.bsv'
    if noisyFlag:
        print 'Writing Top:', topFilename
    userFiles = []
    portalInstantiate = []
    portalList = []
    portalCount = 0
    instantiatedModules = []
    importfiles = []
    portalLeds = ''
    enumList = []

    if options.leds:
        portalLeds = '   interface leds = l%s;' % options.leds
    if options.mem:
        options.proxy.append('MMUIndication:MMU.request:0,True:PhysAddrWidth')
        options.wrapper.append('MMURequest:MMU.request:0,True:PhysAddrWidth')
    for pitem in options.proxy:
        param = ''
        p = pitem.split(':')
        pr = p[1].split('.')
        print 'PROXY', p, pr, len(p)
        pmap = {'name': p[0], 'usermod': pr[0], 'userIf': p[1], 'tparam': ''}
        if len(p) > 2 and p[2]:
            param = p[2] + ', '
        instMod('', pmap['name'], 'Proxy', '')
        if len(p) > 3 and p[3]:
            pmap['tparam'] = '#(' + p[3] + ')'
        instMod(param + 'l%(name)sProxy.ifc', pmap['usermod'], '', '')
    for pitem in options.wrapper:
        param = ''
        p = pitem.split(':')
        pr = p[1].split('.')
        print 'WRAPPER', p, pr, len(p)
        pmap = {'name': p[0], 'usermod': pr[0], 'userIf': p[1], 'tparam': ''}
        if len(p) > 2 and p[2]:
            param = p[2] + ', '
        if len(p) > 3 and p[3]:
            pmap['tparam'] = '#(' + p[3] + ')'
        if pmap['usermod'] not in instantiatedModules:
            instMod(param, pmap['usermod'], '', '')
        pmap['tparam'] = ''
        instMod('', pmap['name'], 'Wrapper', '')
    if options.mem:
        print 'MEM', options.mem
        importfiles.extend(['SpecialFIFOs', 'StmtFSM', 'FIFO', 'MemTypes', 'ConnectalMemory', 'Leds'])
        for pitem in options.mem:
            pmap = {'name': 'MemServerIndication', 'usermod': '', 'userIf': '', 'tparam': ''}
            instMod('', pmap['name'], 'Proxy', '')
            pmap = {'name': 'MemServerIndication', 'usermod': 'MemServer', 'userIf': '', 'tparam': '#(PhysAddrWidth,DataBusWidth,`NumberOfMasters)'}
            p = pitem.split(':')
            ctemp = ['l' + pname for pname in p[1:]]
            instMod('l%(name)sProxy.ifc' + ', %(clientList)s, cons(lMMU,nil)' % {'clientList': ','.join(ctemp)} \
                , pmap['usermod'], '', p[0])
            pmap = {'name': 'MemServerRequest', 'usermod': 'MemServer', 'userIf': 'MemServer.request', 'tparam': ''}
            instMod('', pmap['name'], 'Wrapper', '')

    topsubsts = {'enumList': ','.join(enumList),
                 'generatedImport': '\n'.join(['import %s::*;' % p for p in importfiles]),
                 'portalInstantiate' : '\n'.join(portalInstantiate),
                 'portalList': '\n'.join(portalList),
                 'portalCount': portalCount,
                 'portalLeds' : portalLeds,
                 'portalMaster' : 'dma.masters' if options.mem else 'nil',
                 'moduleParam' : 'ConnectalTop#(PhysAddrWidth,DataBusWidth,Empty,`NumberOfMasters)' if options.mem else \
                                 'StdConnectalTop#(PhysAddrWidth)'
                 }
    print 'TOPFN', topFilename
    top = util.createDirAndOpen(topFilename, 'w')
    top.write(topTemplate % topsubsts)
    top.close()
