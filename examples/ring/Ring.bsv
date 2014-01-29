// Copyright (c) 2013 Quanta Research Cambridge, Inc.
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import GetPut::*;
import StmtFSM::*;
import ClientServer::*;

import PortalMemory::*;
import PortalRMemory::*;
import GetPutF::*;

import RingTypes::*;
import RingBuffer::*;
import CopyEngine::*;
import EchoEngine::*;
import NopEngine::*;

interface RingRequest;
   method Action set(Bit#(1) cmd, Bit#(3) regist, Bit#(32) addr);
   method Action get(Bit#(1) cmd, Bit#(3) regist);
   method Action hwenable(Bit#(1) en);
   method Action doCommandIndirect(Bit#(32) addr);
   method Action doCommandImmediate(Bit#(64) data);
endinterface

interface RingIndication;
   method Action setResult(Bit#(1) cmd, Bit#(3) regist, Bit#(32) addr);
   method Action getResult(Bit#(1) cmd, Bit#(3) regist, Bit#(32) addr);
   method Action completion(Bit#(32) command, Bit#(32) tag);
endinterface

module mkRingRequest#(RingIndication indication,
		      DMAReadServer#(64) dma_read_chan,
		      DMAWriteServer#(64) dma_write_chan,
		      DMAReadServer#(64) cmd_read_chan,
		      DMAWriteServer#(64) status_write_chan )(RingRequest);
   DMAReadBuffer#(64,8) copy_read_chan <- mkDMAReadBuffer();
   DMAWriteBuffer#(64,8) copy_write_chan <- mkDMAWriteBuffer();

   ServerF#(Bit#(64), Bit#(64)) copyEngine <- mkCopyEngine(dma_read_chan, dma_write_chan);   
   ServerF#(Bit#(64), Bit#(64)) nopEngine <- mkNopEngine();
   ServerF#(Bit#(64), Bit#(64)) echoEngine <- mkEchoEngine();
   
   RingBuffer cmdRing <- mkRingBuffer;
   RingBuffer statusRing <- mkRingBuffer;
   Reg#(Bool) hwenabled <- mkReg(False);
   Reg#(Bool) cmdBusy <- mkReg(False);
   Reg#(Bit#(64)) cmd <- mkReg(0);
   Reg#(Bit#(4)) ii <- mkReg(0);
   Reg#(Bit#(4)) respCtr <- mkReg(0);
   Reg#(Bit#(4)) dispCtr <- mkReg(0);
   Reg#(Bit#(6)) cmdFetchTag <- mkReg(0);
   Reg#(Bool) cmdFetchEn <- mkReg(False);

   let engineselect = pack(cmd)[63:56];
   function ServerF#(Bit#(64), Bit#(64)) cmdifc();
      if (engineselect == zeroExtend(pack(CmdNOP))) 
	 return nopEngine;
      else if (engineselect == zeroExtend(pack(CmdCOPY))) 
	 return copyEngine;
      else if (engineselect == zeroExtend(pack(CmdECHO))) 
	 return echoEngine;
      else 
	 return nopEngine;
   endfunction

   Stmt cmdFetch =   
   seq
      $display("cmdFetch FSM TOP");
      while (True) 
	 seq
	    if (hwenabled) 
	       seq
	       if (cmdRing.bufferfirst != cmdRing.bufferlast) 
		  seq
		     $display ("cmdFetch handle=%h address=%d burst=%h tag=%h", cmdRing.memhandle, cmdRing.bufferlast, 8, cmdFetchTag);
		     cmd_read_chan.readReq.put(
			DMAAddressRequest{handle: cmdRing.memhandle,
			   address: cmdRing.bufferlast, burstLen: 8, tag: cmdFetchTag});
		     cmdRing.pop(64);
		     cmdFetchTag <= cmdFetchTag + 1;
		  endseq
	       endseq
	 endseq
   endseq;
   
   Stmt cmdDispatch = 
   seq
      while (True) seq
	 $display("cmdDispatch FSM TOP");
	 action
	    let rv <- cmd_read_chan.readData.get();
	    cmd <= rv.data;
	    $display("cmdDispatch %h", cmd);
	    //cmdifc.request.put(rv.data);
	 endaction
	 for (dispCtr <= 1; dispCtr < 8; dispCtr <= dispCtr + 1)
	    action
	       let rv <- cmd_read_chan.readData.get();
	       //cmdifc.request.put(rv.data);
	    endaction
      endseq
   endseq;
   
   
   Stmt cmdCompletion =
   seq
      while(True) seq
	 while(!(hwenabled && statusRing.notFull())) noAction;
      endseq
   endseq;

   Stmt responseArbiter =
   seq
      while(True) seq
	 if (statusRing.notFull() && copyEngine.response.notEmpty())
	    seq
	       $display("responseArbiter copyEngine completion");
	       status_write_chan.writeReq.put(
		  DMAAddressRequest{handle: statusRing.memhandle, 
		     address: statusRing.bufferfirst, burstLen: 8, tag: 0});
	       for (respCtr <= 0; respCtr < 8; respCtr <= respCtr + 1)
		  action
		     let rv <- copyEngine.response.get();
		     status_write_chan.writeData.put(DMAData{data: rv, tag: 0});
		  endaction
	       statusRing.push(64);
	    endseq

	 if (statusRing.notFull() && echoEngine.response.notEmpty())
	    seq
	       $display("responseArbiter echoEngine completion");
	       status_write_chan.writeReq.put(
		  DMAAddressRequest{handle: statusRing.memhandle, 
		     address: statusRing.bufferfirst, burstLen: 8, tag: 0});
	       for (respCtr <= 0; respCtr < 8; respCtr <= respCtr + 1)
		  action
		     let rv <- echoEngine.response.get();
		     status_write_chan.writeData.put(DMAData{data: rv, tag: 0});
		  endaction
	       statusRing.push(64);
	    endseq

      endseq
   endseq;
   
   mkAutoFSM (cmdFetch);
   mkAutoFSM (cmdDispatch);
   mkAutoFSM (cmdCompletion);
   mkAutoFSM (responseArbiter);


      // to start a command, doCommand fires off a memory read to the
      // specified address. when it comes back, the doCommandRule will
      // handle it
      method Action doCommandIndirect(Bit#(32) addr);
	 //cmd_read_chan.readReq.put(addr);
      endmethod
   
      method Action doCommandImmediate(Bit#(64) data);
      	 $display("doCommandImmediate %h", data);
      endmethod
   

      method Action set(Bit#(1) _cmd, Bit#(3) regist, Bit#(32) addr);
	 if (_cmd == 0)
	    cmdRing.configifc.set(regist, addr);
	 else
	    statusRing.configifc.set(regist, addr);
	 indication.setResult(_cmd, regist, addr);
      endmethod
   
      method Action get(Bit#(1) _cmd, Bit#(3) regist);
	 if (_cmd == 0)
	    indication.getResult(0, regist, 
	       cmdRing.configifc.get(regist));
	 else
	    indication.getResult(0, regist, 
	       statusRing.configifc.get(regist));
      endmethod

      method Action hwenable(Bit#(1) en);
	 $display ("hwenable set to %h", en);
	 hwenabled <= en == 1;
      endmethod
   
endmodule