// Copyright (c) 2014-2015 Quanta Research Cambridge, Inc.

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

import Vector            :: *;
import Clocks            :: *;
import GetPut            :: *;
import FIFO              :: *;
import Connectable       :: *;
import ClientServer      :: *;
import BRAM              :: *;
import DefaultValue      :: *;
import PcieSplitter      :: *;
import PcieTracer        :: *;
import Xilinx            :: *;
import Bscan             :: *;
import Portal            :: *;
import MemToPcie    :: *;
import PcieToMem   :: *;
import PcieCsr           :: *;
import MemTypes          :: *;
`ifndef BSIM
`ifdef XILINX
`ifdef PCIE1
import PCIEWRAPPER       :: *;
import PcieEndpointX7    :: *;
`endif // pcie1
`ifdef PCIE2
import PCIEWRAPPER2       :: *;
import PcieEndpointX7Gen2 :: *;
`endif // pcie2
`ifdef PCIE3
import PCIEWRAPPER3      :: *;
import Pcie3EndpointX7   :: *;
`endif // pcie3
`elsif ALTERA
import PcieEndpointS5    :: *;
`elsif VSIM
import PcieEndpointS5    :: *;
`endif
`endif
import HostInterface     :: *;

// implemented in TlpReplay.cpp
import "BDPI" function Action put_tlp(TLPData#(16) d);
import "BDPI" function ActionValue#(TLPData#(16)) get_tlp();
import "BDPI" function Bool can_put_tlp();
import "BDPI" function Bool can_get_tlp();

(* synthesize *)
module mkMemToPcieSynth#(PciId my_id)(MemToPcie#(DataBusWidth));
   let memSlaveEngine <- mkMemToPcie(my_id);
   return memSlaveEngine;
endmodule

// ==================================================
// PCIE Gen3  PcieHost
//
`ifdef PCIE3
Integer tlpCompleterRequest = 0;
Integer tlpRequesterRequest = 1;
typedef 2   NumberOfTlpIntfs;

(* synthesize *)
module mkPcieHost#(PciId my_pciId)(PcieHost#(DataBusWidth, NumberOfMasters));
   Vector#(NumberOfTlpIntfs, TLPDispatcher) dispatcher <- replicateM(mkTLPDispatcher);
   Vector#(NumberOfTlpIntfs, TLPArbiter) arbiter <- replicateM(mkTLPArbiter);
   Vector#(NumberOfMasters, MemToPcie#(DataBusWidth)) sEngine <- replicateM(mkMemToPcieSynth(my_pciId));
   Vector#(NumberOfMasters,PhysMemSlave#(PciePhysAddrWidth,DataBusWidth)) slavearr;
   MemInterrupt intr <- mkMemInterrupt(my_pciId);
   Vector#(PortMax, PcieToMem) mvec;
   for (Integer i=0; i < valueOf(NumberOfMasters); i=i+1) begin
      let tlp;
      tlp = sEngine[i].tlp;
      slavearr[i]  = sEngine[i].slave;
      mkConnection((interface Server;
                       interface response = dispatcher[tlpRequesterRequest].out[i];
                       interface request = arbiter[tlpRequesterRequest].in[i];
                    endinterface), tlp);
   end
   for (Integer i=0; i < valueOf(PortMax) - 1; i=i+1) begin
      let tlp;
      if (i == portInterrupt)
         tlp = intr.tlp;
      else begin
         mvec[i] <- mkPcieToMem(my_pciId);
         tlp = mvec[i].tlp;
      end
      mkConnection((interface Server;
                       interface response = dispatcher[tlpCompleterRequest].out[i];
                       interface request = arbiter[tlpCompleterRequest].in[i];
                    endinterface), tlp);
   end

   Vector#(NumberOfTlpIntfs, PcieTracer) traceif <- replicateM(mkPcieTracer());
   mkConnection(traceif[tlpCompleterRequest].bus, (interface Client;
                                    interface request = arbiter[tlpCompleterRequest].outToBus;
                                    interface response = dispatcher[tlpCompleterRequest].inFromBus;
                                 endinterface));
   mkConnection(traceif[tlpRequesterRequest].bus, (interface Client;
                                    interface request = arbiter[tlpRequesterRequest].outToBus;
                                    interface response = dispatcher[tlpRequesterRequest].inFromBus;
                                 endinterface));

   PcieControlAndStatusRegs csr <- mkPcieControlAndStatusRegs();
   mkConnection(mvec[portConfig].master, csr.memSlave);

   interface msixEntry = csr.msixEntry;
   interface master = mvec[portPortal].master;
   interface slave = slavearr;
   interface interruptRequest = intr.interruptRequest;
   interface pcic = traceif[tlpCompleterRequest].pci;
   interface pcir = traceif[tlpRequesterRequest].pci;
endmodule: mkPcieHost
`else //NOT PCIE3
// ======================================================
// PCIE GEN1 and GEN2 PcieHost
//(* synthesize *) commented out so that the guards in MemServer aren't destroyed (mdk)
module  mkPcieHost#(PciId my_pciId)(PcieHost#(DataBusWidth, NumberOfMasters));
   let dispatcher <- mkTLPDispatcher;
   let arbiter    <- mkTLPArbiter;
   Vector#(NumberOfMasters,MemToPcie#(DataBusWidth)) sEngine <- replicateM(mkMemToPcieSynth(my_pciId));
   Vector#(NumberOfMasters,PhysMemSlave#(PciePhysAddrWidth,DataBusWidth)) slavearr;
   MemInterrupt intr <- mkMemInterrupt(my_pciId);
`ifdef PCIE_BSCAN
   BscanTop bscan <- mkBscanTop(3); // Use USER3  (JTAG IDCODE address 0x22)
   BscanLocal lbscan <- mkBscanLocal(bscan, clocked_by bscan.tck, reset_by bscan.rst);
`endif

   Vector#(PortMax, PcieToMem) mvec;
   for (Integer i = 0; i < valueOf(PortMax) - 1 + valueOf(NumberOfMasters); i=i+1) begin
       let tlp;
       if (i == portInterrupt)
           tlp = intr.tlp;
       else if (i >= portAxi) begin
           tlp = sEngine[i - portAxi].tlp;
           slavearr[i - portAxi] = sEngine[i - portAxi].slave;
       end
       else begin
           mvec[i] <- mkPcieToMem(my_pciId);
           tlp = mvec[i].tlp;
       end
       mkConnection((interface Server;
                        interface response = dispatcher.out[i];
                        interface request = arbiter.in[i];
                     endinterface), tlp);
   end

   PcieTracer  traceif <- mkPcieTracer();
   mkConnection(traceif.bus, (interface Client;
                                 interface request = arbiter.outToBus;
                                 interface response = dispatcher.inFromBus;
                              endinterface));

`ifndef BSIM
`ifdef PCIE_BSCAN
   Reg#(Bit#(TAdd#(TlpTraceAddrSize,1))) bscanPcieTraceBramWrAddrReg <- mkReg(0);
   BscanBram#(Bit#(TAdd#(TlpTraceAddrSize,1)), TimestampedTlpData) pcieBscanBram <- mkBscanBram(127, bscanPcieTraceBramWrAddrReg, lbscan.loc[1]);
   mkConnection(pcieBscanBram.bramClient, traceif.tlpdata.bscanBramServer);
   rule tdorule;
      lbscan.loc[1].tdo(pcieBscanBram.data_out());
   endrule
`endif
`endif

   PcieControlAndStatusRegs csr <- mkPcieControlAndStatusRegs;
   mkConnection(mvec[portConfig].master, csr.memSlave);
   mkConnection(csr.traceClient, traceif.traceServer);

   interface msixEntry = csr.msixEntry;
   interface master = mvec[portPortal].master;
   interface slave = slavearr;
   interface interruptRequest = intr.interruptRequest;
   interface pci = traceif.pci;
`ifdef PCIE_BSCAN
   interface BscanTop bscanif = lbscan.loc[0];
`else
`ifdef PCIE_TRACE_PORT
   interface BRAMServer traceBramServer = traceif.tlpdata.bscanBramServer;
`endif
`endif
endmodule: mkPcieHost
`endif //PCIE3

interface PcieTop#(type ipins);
`ifndef BSIM
   (* prefix="PCIE" *)
   interface PciewrapPci_exp#(PcieLanes) pcie;
   (* always_ready *)
   (* prefix="" *)
   interface ipins       pins;
`endif
endinterface

`ifdef BSIM
module mkBsimPcieHostTop #(Clock pci_sys_clk_p, Clock pci_sys_clk_n, Clock sys_clk_p, Clock sys_clk_n, Reset pci_sys_reset_n)(PcieHostTop);
   let dc <- exposeCurrentClock;
   let dr <- exposeCurrentReset;
   PcieHost#(DataBusWidth, NumberOfMasters) pciehost <- mkPcieHost(PciId{ bus:0, dev:0, func:0});
   // connect pciehost.pci to bdip functions here
   rule from_bdpi if (can_get_tlp);
      TLPData#(16) foo <- get_tlp;
      pciehost.pci.response.put(foo);
      //$display("from_bdpi: %h %d", foo, valueOf(SizeOf#(TLPData#(16))));
   endrule
   rule to_bdpi if (can_put_tlp);
      TLPData#(16) foo <- pciehost.pci.request.get;
      put_tlp(foo);
      //$display("to_bdpi");
   endrule
   interface Clock pcieClock = dc;
   interface Reset pcieReset = dr;
   interface PcieHost tpciehost = pciehost;
endmodule
`endif

`ifdef XILINX
(* no_default_clock, no_default_reset *)
module mkXilinxPcieHostTop #(Clock pci_sys_clk_p, Clock pci_sys_clk_n, Clock sys_clk_p, Clock sys_clk_n, Reset pci_sys_reset_n)(PcieHostTop);

// Clock and PcieEndpoint for Xilinx
   Clock sys_clk_200mhz <- mkClockIBUFDS(
`ifdef ClockDefaultParam
       defaultValue,
`endif
       sys_clk_p, sys_clk_n);
   Clock sys_clk_200mhz_buf <- mkClockBUFG(clocked_by sys_clk_200mhz);
   Clock pci_clk_100mhz_buf <- mkClockIBUFDS_GTE2(
`ifdef ClockDefaultParam
       defaultValue,
`endif
       True, pci_sys_clk_p, pci_sys_clk_n);
   // Instantiate the PCIE endpoint
   PcieEndpointX7#(PcieLanes) ep7 <- mkPcieEndpointX7( clocked_by pci_clk_100mhz_buf, reset_by pci_sys_reset_n);

   Clock pcieClock_ = ep7.epPcieClock;
   Reset pcieReset_ = ep7.epPcieReset;
   PcieHost#(DataBusWidth, NumberOfMasters) pciehost <- mkPcieHost(
`ifdef PCIE3
         PciId{bus: 0, dev: 0, func:0},
`else
         PciId{ bus:  ep7.cfg.bus_number(), dev: ep7.cfg.device_number(), func: ep7.cfg.function_number()},
`endif
         clocked_by pcieClock_, reset_by pcieReset_);
`ifdef PCIE3
   mkConnection(ep7.tlpr, pciehost.pcir, clocked_by pcieClock_, reset_by pcieReset_);
   mkConnection(ep7.tlpc, pciehost.pcic, clocked_by pcieClock_, reset_by pcieReset_);
`else
   mkConnection(ep7.tlp, pciehost.pci, clocked_by pcieClock_, reset_by pcieReset_);
`endif

   interface Clock tsys_clk_200mhz = sys_clk_200mhz;
   interface Clock tsys_clk_200mhz_buf = sys_clk_200mhz_buf;
   interface Clock tpci_clk_100mhz_buf = pci_clk_100mhz_buf;

   interface PcieEndpointX7 tep7 = ep7;
   interface PcieHost tpciehost = pciehost;

   interface pcieClock = ep7.epPcieClock;
   interface pcieReset = ep7.epPcieReset;
   interface portalClock = ep7.epPortalClock;
   interface portalReset = ep7.epPortalReset;
   interface derivedClock = ep7.epDerivedClock;
   interface derivedReset = ep7.epDerivedReset;
endmodule
`endif

`ifdef ALTERA
`define ALTERA_TOP
`elsif VSIM
`define ALTERA_TOP
`endif

`ifdef ALTERA_TOP
(* no_default_clock, no_default_reset *)
module mkAlteraPcieHostTop #(Clock clk_100MHz, Clock clk_50MHz, Reset perst_n)(PcieHostTop);

   PcieEndpointS5#(PcieLanes) ep7 <- mkPcieEndpointS5(clk_100MHz, clk_50MHz, perst_n, clocked_by clk_100MHz, reset_by perst_n);

   Clock epPcieClock = ep7.epPcieClock;
   Reset epPcieReset = ep7.epPcieReset;

   Clock portalClock_ = epPcieClock;
   Reset portalReset_ = epPcieReset;

   PcieHost#(DataBusWidth, NumberOfMasters) pciehost <- mkPcieHost(ep7.device, clocked_by portalClock_, reset_by portalReset_);
   mkConnection(ep7.tlp, pciehost.pci, clocked_by portalClock_, reset_by portalReset_);

   interface PcieEndpointS5 tep7 = ep7;
   interface PcieHost tpciehost = pciehost;

   interface Clock pcieClock = epPcieClock;
   interface Reset pcieReset = epPcieReset;
   interface portalClock = portalClock_;
   interface portalReset = portalReset_;
   interface derivedClock = ep7.epDerivedClock;
   interface derivedReset = ep7.epDerivedReset;

endmodule
`endif

`ifdef BSIM
   module mkPcieHostTop #(Clock pci_sys_clk_p, Clock pci_sys_clk_n, Clock sys_clk_p, Clock sys_clk_n, Reset pci_sys_reset_n)(PcieHostTop);
   PcieHostTop _a <- mkBsimPcieHostTop(pci_sys_clk_p, pci_sys_clk_n, sys_clk_p, sys_clk_n, pci_sys_reset_n); return _a;
   endmodule
`elsif XILINX // XILINX
   //(* synthesize, no_default_clock, no_default_reset *)
   (* no_default_clock, no_default_reset *)
   module mkPcieHostTop #(Clock pci_sys_clk_p, Clock pci_sys_clk_n, Clock sys_clk_p, Clock sys_clk_n, Reset pci_sys_reset_n)(PcieHostTop);
      PcieHostTop _a <- mkXilinxPcieHostTop(pci_sys_clk_p, pci_sys_clk_n, sys_clk_p, sys_clk_n, pci_sys_reset_n); return _a;
   endmodule
`elsif ALTERA_TOP
   //(* synthesize, no_default_clock, no_default_reset *)
   (* no_default_clock, no_default_reset *)
   module mkPcieHostTop #(Clock clk_100MHz, Clock clk_50MHz, Reset perst_n)(PcieHostTop);
      PcieHostTop _a <- mkAlteraPcieHostTop(clk_100MHz, clk_50MHz, perst_n); return _a;
   endmodule
`endif // NOT ALTERA
